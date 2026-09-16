package com.nomadgames.games.stickpull;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;
import java.util.Objects;

/**
 * Authoritative 1D stamina tug. Ignores client timestamps/force (D-91).
 * Local/near (host/player) pulls toward −1; far (joiner/bot) toward +1.
 */
public final class StickPullSim {

    public enum Side {
        NEAR,
        FAR
    }

    public record TapResult(
            boolean accepted,
            double marker,
            double staminaNear,
            double staminaFar,
            StickPullPhase phase,
            int clockSecondsLeft,
            boolean suspect,
            String settleStatus) {}

    private final Instant createdAt;
    private final int clockSeconds;
    /** Ranked false-start enforcement (D-100); Casual keeps D-90 ignore. */
    private final boolean ranked;

    private StickPullPhase phase = StickPullPhase.COUNTDOWN;
    private Instant goAt;
    private Instant liveDeadline;
    /** Remaining tug time while reconnect-frozen; null when clock is running. */
    private Duration pausedRemaining;
    private Instant lastTickAt;

    private double marker;
    private double staminaNear = 1.0;
    private double staminaFar = 1.0;
    private boolean exhaustNear;
    private boolean exhaustFar;
    private boolean suspect;
    private String settleStatus;

    private Instant lastAcceptedNear;
    private Instant lastAcceptedFar;
    private double staminaNearBaseline = 1.0;
    private double staminaFarBaseline = 1.0;
    private Instant burstStartedNear;
    private Instant burstStartedFar;

    private final Deque<Instant> acceptedNear = new ArrayDeque<>();
    private final Deque<Instant> acceptedFar = new ArrayDeque<>();
    private final Deque<Long> bucketNear = new ArrayDeque<>();
    private final Deque<Long> bucketFar = new ArrayDeque<>();
    private final List<Double> intervalsNearMs = new ArrayList<>();
    private final List<Double> intervalsFarMs = new ArrayList<>();
    private int falseStartsNear;
    private int falseStartsFar;

    public StickPullSim(Instant now, int clockSeconds) {
        this(now, clockSeconds, false);
    }

    public StickPullSim(Instant now, int clockSeconds, boolean ranked) {
        Objects.requireNonNull(now, "now");
        if (clockSeconds < StickPullConstants.MIN_CLOCK_SECONDS
                || clockSeconds > StickPullConstants.MAX_CLOCK_SECONDS) {
            throw new IllegalArgumentException("clockSeconds");
        }
        this.createdAt = now;
        this.clockSeconds = clockSeconds;
        this.ranked = ranked;
        this.lastTickAt = now;
    }

    public StickPullSim(Instant now) {
        this(now, StickPullConstants.DEFAULT_CLOCK_SECONDS, false);
    }

    public boolean ranked() {
        return ranked;
    }

    public StickPullPhase phase() {
        return phase;
    }

    public double marker() {
        return marker;
    }

    public double staminaNear() {
        return staminaNear;
    }

    public double staminaFar() {
        return staminaFar;
    }

    public boolean suspect() {
        return suspect;
    }

    public String settleStatus() {
        return settleStatus;
    }

    public int clockSeconds() {
        return clockSeconds;
    }

    public Instant createdAt() {
        return createdAt;
    }

    public Instant liveDeadline() {
        return liveDeadline;
    }

    public void enterLive(Instant now) {
        if (phase != StickPullPhase.COUNTDOWN) {
            return;
        }
        phase = StickPullPhase.LIVE;
        goAt = now;
        liveDeadline = now.plusSeconds(clockSeconds);
        pausedRemaining = null;
        lastTickAt = now;
    }

    /**
     * Freeze absolute tug deadline across reconnect grace (UI-SPEC / Phase 3 mirror).
     * Idempotent while already paused.
     */
    public void pauseClock(Instant now) {
        Objects.requireNonNull(now, "now");
        if (phase != StickPullPhase.LIVE || liveDeadline == null || pausedRemaining != null) {
            return;
        }
        Duration left = Duration.between(now, liveDeadline);
        pausedRemaining = left.isNegative() ? Duration.ZERO : left;
    }

    /** Restore tug deadline from remaining time after last seat clears. */
    public void resumeClock(Instant now) {
        Objects.requireNonNull(now, "now");
        if (pausedRemaining == null) {
            return;
        }
        liveDeadline = now.plus(pausedRemaining);
        pausedRemaining = null;
        lastTickAt = now;
    }

    public int clockSecondsLeft(Instant now) {
        if (phase == StickPullPhase.COUNTDOWN) {
            return clockSeconds;
        }
        if (phase == StickPullPhase.SETTLED || liveDeadline == null) {
            return 0;
        }
        long ms = pausedRemaining != null
                ? pausedRemaining.toMillis()
                : Duration.between(now, liveDeadline).toMillis();
        if (ms <= 0) {
            return 0;
        }
        return (int) Math.ceil(ms / 1000.0);
    }

    /**
     * Attempt to accept a tap at server {@code now}. Pre-GO: Casual ignores (D-90);
     * Ranked 1st false start → stamina 0.70, 2nd → rated forfeit (D-100).
     */
    public TapResult applyAcceptedTap(Side side, Instant now) {
        Objects.requireNonNull(side, "side");
        Objects.requireNonNull(now, "now");
        if (phase == StickPullPhase.SETTLED) {
            return snapshot(false, now);
        }
        if (phase == StickPullPhase.COUNTDOWN) {
            return applyPreGoTap(side, now);
        }
        if (phase != StickPullPhase.LIVE) {
            return snapshot(false, now);
        }
        tickRegen(now);
        if (!acceptClamp(side, now)) {
            return snapshot(false, now);
        }
        recordAccepted(side, now);
        double tps = rateTps(side == Side.NEAR ? acceptedNear : acceptedFar, now);
        double force = forceFor(side, now, tps);
        if (side == Side.NEAR) {
            marker -= force;
            drain(Side.NEAR, tps);
        } else {
            marker += force;
            drain(Side.FAR, tps);
        }
        marker = clampMarker(marker);
        updateSuspect(side);
        if (Math.abs(marker) >= StickPullConstants.WIN_THRESHOLD) {
            settleThreshold(side);
        }
        return snapshot(true, now);
    }

    /** Idle regen + clock settle. Call at sim tick while LIVE. */
    public TapResult tick(Instant now) {
        Objects.requireNonNull(now, "now");
        if (phase != StickPullPhase.LIVE) {
            return snapshot(false, now);
        }
        if (pausedRemaining != null) {
            return snapshot(false, now);
        }
        tickRegen(now);
        if (liveDeadline != null && !now.isBefore(liveDeadline)) {
            settleClock();
        }
        return snapshot(false, now);
    }

    public void forceSettle(String status) {
        phase = StickPullPhase.SETTLED;
        settleStatus = status;
    }

    private TapResult applyPreGoTap(Side side, Instant now) {
        if (!ranked) {
            return snapshot(false, now);
        }
        if (side == Side.NEAR) {
            falseStartsNear++;
            if (falseStartsNear == 1) {
                staminaNear = 0.70;
                staminaNearBaseline = 0.70;
                return snapshot(false, now);
            }
            // Offender near → far wins (BOT_WIN mapped to JOINER_WIN for human PvP).
            forceSettle("BOT_WIN");
            return snapshot(false, now);
        }
        falseStartsFar++;
        if (falseStartsFar == 1) {
            staminaFar = 0.70;
            staminaFarBaseline = 0.70;
            return snapshot(false, now);
        }
        forceSettle("PLAYER_WIN");
        return snapshot(false, now);
    }

    private void settleThreshold(Side winner) {
        phase = StickPullPhase.SETTLED;
        settleStatus = winner == Side.NEAR ? "PLAYER_WIN" : "BOT_WIN";
    }

    private void settleClock() {
        phase = StickPullPhase.SETTLED;
        if (marker < -1e-9) {
            settleStatus = "PLAYER_WIN";
        } else if (marker > 1e-9) {
            settleStatus = "BOT_WIN";
        } else {
            settleStatus = "DRAW";
        }
    }

    private boolean acceptClamp(Side side, Instant now) {
        Deque<Long> buckets = side == Side.NEAR ? bucketNear : bucketFar;
        long bucket = now.toEpochMilli() / StickPullConstants.BUCKET_MS;
        while (!buckets.isEmpty() && buckets.peekFirst() < bucket - 4) {
            buckets.removeFirst();
        }
        long inBucket = 0;
        for (Long b : buckets) {
            if (b == bucket) {
                inBucket++;
            }
        }
        if (inBucket >= StickPullConstants.MAX_TAPS_PER_BUCKET) {
            return false;
        }
        Deque<Instant> accepted = side == Side.NEAR ? acceptedNear : acceptedFar;
        pruneWindow(accepted, now);
        if (accepted.size() >= StickPullConstants.HARD_CLAMP_TPS) {
            return false;
        }
        buckets.addLast(bucket);
        return true;
    }

    private void recordAccepted(Side side, Instant now) {
        Deque<Instant> accepted = side == Side.NEAR ? acceptedNear : acceptedFar;
        Instant last = side == Side.NEAR ? lastAcceptedNear : lastAcceptedFar;
        if (last != null) {
            double interval = Duration.between(last, now).toNanos() / 1_000_000.0;
            List<Double> intervals = side == Side.NEAR ? intervalsNearMs : intervalsFarMs;
            intervals.add(interval);
            if (intervals.size() > StickPullConstants.SUSPECT_INTERVAL_COUNT + 5) {
                intervals.remove(0);
            }
        }
        accepted.addLast(now);
        if (side == Side.NEAR) {
            lastAcceptedNear = now;
        } else {
            lastAcceptedFar = now;
        }
    }

    private double forceFor(Side side, Instant now, double tps) {
        boolean exhaust = side == Side.NEAR ? exhaustNear : exhaustFar;
        double stamina = side == Side.NEAR ? staminaNear : staminaFar;
        if (exhaust || stamina <= 0) {
            if (side == Side.NEAR) {
                exhaustNear = true;
            } else {
                exhaustFar = true;
            }
            return StickPullConstants.SOFT_FORCE * StickPullConstants.EXHAUST_FORCE_MULT;
        }
        if (tps >= StickPullConstants.BURST_BAND_MIN_TPS) {
            Instant burstStart = side == Side.NEAR ? burstStartedNear : burstStartedFar;
            if (burstStart == null) {
                burstStart = now;
                if (side == Side.NEAR) {
                    burstStartedNear = now;
                } else {
                    burstStartedFar = now;
                }
            }
            long burstMs = Duration.between(burstStart, now).toMillis();
            if (burstMs <= StickPullConstants.BURST_WINDOW_MS) {
                return StickPullConstants.SOFT_FORCE * StickPullConstants.BURST_FORCE_MULT;
            }
            if (side == Side.NEAR) {
                exhaustNear = true;
                staminaNear = 0;
            } else {
                exhaustFar = true;
                staminaFar = 0;
            }
            return StickPullConstants.SOFT_FORCE * StickPullConstants.EXHAUST_FORCE_MULT;
        }
        if (side == Side.NEAR) {
            burstStartedNear = null;
        } else {
            burstStartedFar = null;
        }
        return StickPullConstants.SOFT_FORCE;
    }

    private void drain(Side side, double tps) {
        double amount = tps >= StickPullConstants.BURST_BAND_MIN_TPS
                ? StickPullConstants.BURST_DRAIN_PER_TAP
                : StickPullConstants.SOFT_DRAIN_PER_TAP;
        if (side == Side.NEAR) {
            staminaNear = Math.max(0, staminaNear - amount);
            staminaNearBaseline = staminaNear;
            if (staminaNear <= 0) {
                exhaustNear = true;
            }
        } else {
            staminaFar = Math.max(0, staminaFar - amount);
            staminaFarBaseline = staminaFar;
            if (staminaFar <= 0) {
                exhaustFar = true;
            }
        }
    }

    private void tickRegen(Instant now) {
        lastTickAt = now;
        staminaNear = regenSide(staminaNearBaseline, lastAcceptedNear, now, true);
        staminaFar = regenSide(staminaFarBaseline, lastAcceptedFar, now, false);
    }

    private double regenSide(double baseline, Instant lastAccepted, Instant now, boolean near) {
        if (lastAccepted == null) {
            return near ? staminaNear : staminaFar;
        }
        long idleMs = Duration.between(lastAccepted, now).toMillis();
        if (idleMs < StickPullConstants.RECOVERY_MS) {
            return near ? staminaNear : staminaFar;
        }
        double recoverableSec = (idleMs - StickPullConstants.RECOVERY_MS) / 1000.0;
        double next = Math.min(1.0, baseline + recoverableSec * StickPullConstants.REGEN_PER_SECOND);
        if (near) {
            if (exhaustNear && next >= StickPullConstants.EXHAUST_EXIT_STAMINA) {
                exhaustNear = false;
            }
        } else if (exhaustFar && next >= StickPullConstants.EXHAUST_EXIT_STAMINA) {
            exhaustFar = false;
        }
        return next;
    }

    private void updateSuspect(Side side) {
        List<Double> intervals = side == Side.NEAR ? intervalsNearMs : intervalsFarMs;
        if (intervals.size() < StickPullConstants.SUSPECT_INTERVAL_COUNT) {
            return;
        }
        int from = intervals.size() - StickPullConstants.SUSPECT_INTERVAL_COUNT;
        double sum = 0;
        for (int i = from; i < intervals.size(); i++) {
            sum += intervals.get(i);
        }
        double mean = sum / StickPullConstants.SUSPECT_INTERVAL_COUNT;
        double var = 0;
        for (int i = from; i < intervals.size(); i++) {
            double d = intervals.get(i) - mean;
            var += d * d;
        }
        var /= StickPullConstants.SUSPECT_INTERVAL_COUNT;
        if (var < StickPullConstants.SUSPECT_VARIANCE_MS2) {
            suspect = true;
        }
    }

    private static void pruneWindow(Deque<Instant> accepted, Instant now) {
        while (!accepted.isEmpty() && Duration.between(accepted.peekFirst(), now).toMillis() >= 1000) {
            accepted.removeFirst();
        }
    }

    private static double rateTps(Deque<Instant> accepted, Instant now) {
        pruneWindow(accepted, now);
        return accepted.size();
    }

    private static double clampMarker(double value) {
        if (value < -1.0) {
            return -1.0;
        }
        if (value > 1.0) {
            return 1.0;
        }
        return value;
    }

    private TapResult snapshot(boolean accepted, Instant now) {
        return new TapResult(
                accepted,
                marker,
                staminaNear,
                staminaFar,
                phase,
                clockSecondsLeft(now),
                suspect,
                settleStatus);
    }
}
