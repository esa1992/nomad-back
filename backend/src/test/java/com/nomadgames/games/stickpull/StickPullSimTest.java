package com.nomadgames.games.stickpull;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Instant;

import org.junit.jupiter.api.Test;

/**
 * STICK-01…04 stamina / clamp / clock (D-88 / D-89 / D-91).
 */
class StickPullSimTest {

    @Test
    void softBandFullForce() {
        Instant t0 = Instant.parse("2026-01-01T00:00:00Z");
        StickPullSim sim = new StickPullSim(t0);
        sim.enterLive(t0);
        // 5 taps/s → soft band
        Instant t = t0;
        for (int i = 0; i < 5; i++) {
            t = t.plusMillis(200);
            StickPullSim.TapResult r = sim.applyAcceptedTap(StickPullSim.Side.NEAR, t);
            assertTrue(r.accepted());
        }
        assertEquals(-5 * StickPullConstants.SOFT_FORCE, sim.marker(), 1e-9);
    }

    @Test
    void hardClampDropsExtras() {
        Instant t0 = Instant.parse("2026-01-01T00:00:00Z");
        StickPullSim sim = new StickPullSim(t0);
        sim.enterLive(t0);
        Instant bucket = t0.plusMillis(10);
        assertTrue(sim.applyAcceptedTap(StickPullSim.Side.NEAR, bucket).accepted());
        assertTrue(sim.applyAcceptedTap(StickPullSim.Side.NEAR, bucket.plusMillis(20)).accepted());
        StickPullSim.TapResult third = sim.applyAcceptedTap(StickPullSim.Side.NEAR, bucket.plusMillis(40));
        assertFalse(third.accepted());
        assertEquals(-2 * StickPullConstants.SOFT_FORCE, sim.marker(), 1e-9);
    }

    @Test
    void burstWindowReducesForce() {
        Instant t0 = Instant.parse("2026-01-01T00:00:00Z");
        StickPullSim sim = new StickPullSim(t0);
        sim.enterLive(t0);
        Instant t = t0;
        // Fill to 8 taps inside 1s (100ms spacing) → burst band
        double before = 0;
        for (int i = 0; i < 8; i++) {
            t = t.plusMillis(100);
            StickPullSim.TapResult r = sim.applyAcceptedTap(StickPullSim.Side.NEAR, t);
            assertTrue(r.accepted(), "tap " + i);
            if (i == 7) {
                // Last tap should be burst-priced (rate ≥8)
                double delta = Math.abs(sim.marker() - before);
                assertEquals(
                        StickPullConstants.SOFT_FORCE * StickPullConstants.BURST_FORCE_MULT,
                        delta,
                        1e-9);
            }
            before = sim.marker();
        }
    }

    @Test
    void exhaustWeakForceUntilRecovery() {
        Instant t0 = Instant.parse("2026-01-01T00:00:00Z");
        StickPullSim sim = new StickPullSim(t0);
        sim.enterLive(t0);
        Instant t = t0;
        // Drain stamina via soft taps (0.04 each → 25 taps to 0)
        for (int i = 0; i < 30; i++) {
            t = t.plusMillis(200);
            sim.applyAcceptedTap(StickPullSim.Side.NEAR, t);
        }
        assertTrue(sim.staminaNear() <= 0.0 + 1e-9);
        double markerBefore = sim.marker();
        t = t.plusMillis(200);
        StickPullSim.TapResult weak = sim.applyAcceptedTap(StickPullSim.Side.NEAR, t);
        assertTrue(weak.accepted());
        double delta = Math.abs(sim.marker() - markerBefore);
        assertEquals(
                StickPullConstants.SOFT_FORCE * StickPullConstants.EXHAUST_FORCE_MULT,
                delta,
                1e-9);
    }

    @Test
    void recoveryAfterIdleGap() {
        Instant t0 = Instant.parse("2026-01-01T00:00:00Z");
        StickPullSim sim = new StickPullSim(t0);
        sim.enterLive(t0);
        Instant t = t0.plusMillis(200);
        sim.applyAcceptedTap(StickPullSim.Side.NEAR, t);
        double afterTap = sim.staminaNear();
        assertTrue(afterTap < 1.0);
        // Just under recovery — no regen
        sim.tick(t.plusMillis(StickPullConstants.RECOVERY_MS - 10));
        assertEquals(afterTap, sim.staminaNear(), 1e-9);
        // After recovery gate — regen climbs
        Instant recovered = t.plusMillis(StickPullConstants.RECOVERY_MS + 500);
        sim.tick(recovered);
        assertTrue(sim.staminaNear() > afterTap);
    }

    @Test
    void thresholdOrClockSettle() {
        Instant t0 = Instant.parse("2026-01-01T00:00:00Z");
        StickPullSim threshold = new StickPullSim(t0);
        threshold.enterLive(t0);
        Instant t = t0;
        // Need ≥0.85 / 0.012 ≈ 71 soft taps; idle regen keeps force full
        for (int i = 0; i < 100 && threshold.phase() != StickPullPhase.SETTLED; i++) {
            t = t.plusMillis(200);
            threshold.applyAcceptedTap(StickPullSim.Side.NEAR, t);
            if (i % 4 == 3) {
                t = t.plusMillis(StickPullConstants.RECOVERY_MS + 400);
                threshold.tick(t);
            }
        }
        assertEquals(StickPullPhase.SETTLED, threshold.phase());
        assertEquals("PLAYER_WIN", threshold.settleStatus());

        StickPullSim clock = new StickPullSim(t0, 15);
        clock.enterLive(t0);
        Instant end = t0.plusSeconds(15);
        clock.applyAcceptedTap(StickPullSim.Side.FAR, t0.plusMillis(200));
        clock.tick(end);
        assertEquals(StickPullPhase.SETTLED, clock.phase());
        assertEquals("BOT_WIN", clock.settleStatus());
    }

    @Test
    void suspectRegularityLogsOnly() {
        Instant t0 = Instant.parse("2026-01-01T00:00:00Z");
        StickPullSim sim = new StickPullSim(t0);
        sim.enterLive(t0);
        Instant t = t0;
        for (int i = 0; i < 25; i++) {
            t = t.plusMillis(200);
            sim.applyAcceptedTap(StickPullSim.Side.NEAR, t);
        }
        assertTrue(sim.suspect());
        // No ban API — only the flag; phase may still be LIVE
        assertTrue(sim.phase() == StickPullPhase.LIVE || sim.phase() == StickPullPhase.SETTLED);
    }

    @Test
    void pauseClockFreezesDeadlineAcrossWallGap() {
        Instant t0 = Instant.parse("2026-01-01T00:00:00Z");
        StickPullSim sim = new StickPullSim(t0, 15);
        sim.enterLive(t0);
        Instant pauseAt = t0.plusSeconds(5);
        sim.pauseClock(pauseAt);
        assertEquals(10, sim.clockSecondsLeft(pauseAt.plusSeconds(30)));
        sim.tick(pauseAt.plusSeconds(30));
        assertEquals(StickPullPhase.LIVE, sim.phase());
        Instant resumeAt = pauseAt.plusSeconds(8);
        sim.resumeClock(resumeAt);
        assertEquals(10, sim.clockSecondsLeft(resumeAt));
        sim.tick(resumeAt.plusSeconds(9));
        assertEquals(StickPullPhase.LIVE, sim.phase());
        sim.tick(resumeAt.plusSeconds(10));
        assertEquals(StickPullPhase.SETTLED, sim.phase());
    }

    @Test
    void rankedFalseStart() {
        // D-100: Ranked 1st pre-GO → stamina 0.70; 2nd → rated forfeit. Casual keeps D-90 ignore.
        Instant t0 = Instant.parse("2026-01-01T00:00:00Z");
        StickPullSim ranked = new StickPullSim(t0, 15, true);
        StickPullSim.TapResult first = ranked.applyAcceptedTap(StickPullSim.Side.NEAR, t0.plusMillis(50));
        assertFalse(first.accepted());
        assertEquals(StickPullPhase.COUNTDOWN, ranked.phase());
        assertEquals(0.70, ranked.staminaNear(), 1e-9);
        assertEquals(1.0, ranked.staminaFar(), 1e-9);

        StickPullSim.TapResult second = ranked.applyAcceptedTap(StickPullSim.Side.NEAR, t0.plusMillis(100));
        assertFalse(second.accepted());
        assertEquals(StickPullPhase.SETTLED, ranked.phase());
        assertEquals("BOT_WIN", ranked.settleStatus());

        StickPullSim casual = new StickPullSim(t0, 15, false);
        StickPullSim.TapResult ignored = casual.applyAcceptedTap(StickPullSim.Side.NEAR, t0.plusMillis(50));
        assertFalse(ignored.accepted());
        assertEquals(StickPullPhase.COUNTDOWN, casual.phase());
        assertEquals(1.0, casual.staminaNear(), 1e-9);
        assertEquals(null, casual.settleStatus());
    }
}
