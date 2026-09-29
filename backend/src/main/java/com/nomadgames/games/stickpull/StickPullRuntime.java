package com.nomadgames.games.stickpull;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ThreadLocalRandom;
import java.util.function.BiConsumer;
import java.util.function.Consumer;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import com.nomadgames.session.internal.MatchSessionRegistry;

/**
 * Heap-only Stick Pull live sessions: countdown, bot taps, 20 Hz tick, 10 Hz StickState.
 */
@Component
public class StickPullRuntime {

    private static final Logger log = LoggerFactory.getLogger(StickPullRuntime.class);
    private static final String[] COUNTDOWN_STEPS = {"3", "2", "1", "GO"};

    public record LiveSession(
            UUID matchId,
            StickPullSim sim,
            String difficulty,
            boolean botMode,
            Instant createdAt,
            int countdownIndex,
            Instant nextCountdownAt,
            Instant nextBotTapAt,
            int botTapsSincePause,
            Instant nextStateBroadcastAt,
            boolean clientPaused,
            BiConsumer<LiveSession, String> onCountdown,
            BiConsumer<LiveSession, StickPullSim.TapResult> onBotTap,
            Consumer<LiveSession> onState,
            Consumer<LiveSession> onSettled) {}

    private final ConcurrentHashMap<UUID, LiveSession> live = new ConcurrentHashMap<>();
    private final MatchSessionRegistry sessions;

    public StickPullRuntime(MatchSessionRegistry sessions) {
        this.sessions = sessions;
    }

    public void start(
            UUID matchId,
            StickPullSim sim,
            String difficulty,
            boolean botMode,
            BiConsumer<LiveSession, String> onCountdown,
            BiConsumer<LiveSession, StickPullSim.TapResult> onBotTap,
            Consumer<LiveSession> onState,
            Consumer<LiveSession> onSettled) {
        Instant now = Instant.now();
        // nextCountdownAt == null → armed, but wait for a WS seat before 3-2-1-GO
        // (otherwise cold clients miss the whole countdown while HTTP+ticket connect).
        live.put(
                matchId,
                new LiveSession(
                        matchId,
                        sim,
                        difficulty,
                        botMode,
                        now,
                        0,
                        null,
                        null,
                        0,
                        now,
                        false,
                        onCountdown,
                        onBotTap,
                        onState,
                        onSettled));
    }

    public StickPullSim sim(UUID matchId) {
        LiveSession session = live.get(matchId);
        return session == null ? null : session.sim();
    }

    public LiveSession session(UUID matchId) {
        return live.get(matchId);
    }

    public boolean isClientPaused(UUID matchId) {
        LiveSession session = live.get(matchId);
        return session != null && session.clientPaused();
    }

    /**
     * Bot-mode client Pause: freeze tug clock + bot taps until Resume (WR-01).
     * No-op for human PvP sessions.
     */
    public void setClientPaused(UUID matchId, boolean paused) {
        Instant now = Instant.now();
        live.computeIfPresent(matchId, (id, session) -> {
            if (!session.botMode() || session.clientPaused() == paused) {
                return session;
            }
            StickPullSim sim = session.sim();
            synchronized (sim) {
                if (paused) {
                    sim.pauseClock(now);
                } else {
                    sim.resumeClock(now);
                }
            }
            Instant botAt = session.nextBotTapAt();
            if (!paused && botAt != null && botAt.isBefore(now)) {
                botAt = now.plusMillis(nextBotDelay(session.difficulty(), session.botTapsSincePause()));
            }
            return copy(
                    session,
                    session.countdownIndex(),
                    session.nextCountdownAt(),
                    botAt,
                    session.botTapsSincePause(),
                    session.nextStateBroadcastAt(),
                    paused);
        });
    }

    public void remove(UUID matchId) {
        live.remove(matchId);
    }

    @Scheduled(fixedRate = 50)
    public void tickAll() {
        Instant now = Instant.now();
        for (UUID matchId : Map.copyOf(live).keySet()) {
            live.computeIfPresent(matchId, (id, session) -> advance(session, now));
        }
    }

    private LiveSession advance(LiveSession session, Instant now) {
        if (session.sim().phase() == StickPullPhase.SETTLED) {
            live.remove(session.matchId());
            return null;
        }
        LiveSession next = session;
        // Hold countdown + LIVE while reconnect grace or bot-mode client Pause.
        if (sessions.anyDropped(next.matchId()) || next.clientPaused()) {
            return next;
        }
        if (next.sim().phase() == StickPullPhase.COUNTDOWN) {
            if (next.nextCountdownAt() == null) {
                if (!seatsReadyForCountdown(next)) {
                    return next;
                }
                next = copy(
                        next,
                        next.countdownIndex(),
                        now,
                        next.nextBotTapAt(),
                        next.botTapsSincePause(),
                        next.nextStateBroadcastAt(),
                        next.clientPaused());
            }
            next = advanceCountdown(next, now);
            if (next == null) {
                return null;
            }
        }
        if (next.sim().phase() != StickPullPhase.LIVE) {
            return next;
        }
        StickPullSim sim = next.sim();
        synchronized (sim) {
            sim.tick(now);
            if (sim.phase() == StickPullPhase.SETTLED) {
                next.onSettled().accept(next);
                live.remove(next.matchId());
                return null;
            }
            if (next.botMode() && next.nextBotTapAt() != null && !now.isBefore(next.nextBotTapAt())) {
                StickPullSim.TapResult botTap = sim.applyAcceptedTap(StickPullSim.Side.FAR, now);
                next.onBotTap().accept(next, botTap);
                if (sim.suspect()) {
                    log.info("suspect=true matchId={} side=FAR", next.matchId());
                }
                if (sim.phase() == StickPullPhase.SETTLED) {
                    next.onSettled().accept(next);
                    live.remove(next.matchId());
                    return null;
                }
                next = withNextBot(next, now);
            }
        }
        if (next.nextStateBroadcastAt() == null || !now.isBefore(next.nextStateBroadcastAt())) {
            next.onState().accept(next);
            long periodMs = 1000L / StickPullConstants.STATE_BROADCAST_HZ;
            next = copy(
                    next,
                    next.countdownIndex(),
                    next.nextCountdownAt(),
                    next.nextBotTapAt(),
                    next.botTapsSincePause(),
                    now.plusMillis(periodMs),
                    next.clientPaused());
        }
        return next;
    }

    /** Bot: any open seat. PvP: both seats (host+joiner) before 3-2-1. */
    private boolean seatsReadyForCountdown(LiveSession session) {
        var open = sessions.sessionsFor(session.matchId());
        if (session.botMode()) {
            return !open.isEmpty();
        }
        return open.size() >= 2;
    }

    private LiveSession advanceCountdown(LiveSession session, Instant now) {
        if (session.nextCountdownAt() != null && now.isBefore(session.nextCountdownAt())) {
            return session;
        }
        int index = session.countdownIndex();
        if (index >= COUNTDOWN_STEPS.length) {
            return session;
        }
        String label = COUNTDOWN_STEPS[index];
        session.onCountdown().accept(session, label);
        if ("GO".equals(label)) {
            session.sim().enterLive(now);
            Instant botAt = session.botMode() ? now.plusMillis(nextBotDelay(session.difficulty(), 0)) : null;
            return copy(session, index + 1, null, botAt, 0, now, session.clientPaused());
        }
        return copy(
                session,
                index + 1,
                now.plusMillis(StickPullConstants.COUNTDOWN_STEP_MS),
                session.nextBotTapAt(),
                session.botTapsSincePause(),
                session.nextStateBroadcastAt(),
                session.clientPaused());
    }

    private LiveSession withNextBot(LiveSession session, Instant now) {
        int since = session.botTapsSincePause() + 1;
        long delay = nextBotDelay(session.difficulty(), since);
        StickPullBot.Envelope env = StickPullBot.envelope(StickPullBot.parse(session.difficulty()));
        boolean paused = delay >= env.pauseMsMin();
        return copy(
                session,
                session.countdownIndex(),
                session.nextCountdownAt(),
                now.plusMillis(delay),
                paused ? 0 : since,
                session.nextStateBroadcastAt(),
                session.clientPaused());
    }

    private static LiveSession copy(
            LiveSession session,
            int countdownIndex,
            Instant nextCountdownAt,
            Instant nextBotTapAt,
            int botTapsSincePause,
            Instant nextStateBroadcastAt,
            boolean clientPaused) {
        return new LiveSession(
                session.matchId(),
                session.sim(),
                session.difficulty(),
                session.botMode(),
                session.createdAt(),
                countdownIndex,
                nextCountdownAt,
                nextBotTapAt,
                botTapsSincePause,
                nextStateBroadcastAt,
                clientPaused,
                session.onCountdown(),
                session.onBotTap(),
                session.onState(),
                session.onSettled());
    }

    private static long nextBotDelay(String difficulty, int tapsSincePause) {
        return StickPullBot.nextDelayMs(
                StickPullBot.parse(difficulty), ThreadLocalRandom.current(), tapsSincePause);
    }

    public Map<String, Object> stickStatePayload(LiveSession session, Instant now) {
        StickPullSim sim = session.sim();
        return Map.of(
                "type",
                "StickState",
                "marker",
                sim.marker(),
                "staminaHost",
                sim.staminaNear(),
                "staminaJoiner",
                sim.staminaFar(),
                "phase",
                sim.phase().name(),
                "clockSecondsLeft",
                sim.clockSecondsLeft(now),
                "suspect",
                sim.suspect());
    }

    public Map<String, Object> tapResolvedPayload(StickPullSim.TapResult result, int clientSeq) {
        return Map.of(
                "type",
                "TapResolved",
                "accepted",
                result.accepted(),
                "clientSeq",
                clientSeq,
                "marker",
                result.marker(),
                "staminaHost",
                result.staminaNear(),
                "staminaJoiner",
                result.staminaFar(),
                "phase",
                result.phase().name(),
                "clockSecondsLeft",
                result.clockSecondsLeft(),
                "suspect",
                result.suspect());
    }
}
