package com.nomadgames.games.stickpull;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Objects;
import java.util.Random;

/**
 * Scripted Stick Pull bot tap delays with human-like jitter (BOT-02).
 */
public final class StickPullBot {

    public enum Difficulty {
        EASY,
        NORMAL,
        HARD
    }

    public record Envelope(double meanTps, double sigma, int pauseEveryMin, int pauseEveryMax, int pauseMsMin, int pauseMsMax) {}

    private StickPullBot() {}

    public static Difficulty parse(String difficulty) {
        if (difficulty == null || difficulty.isBlank()) {
            return Difficulty.EASY;
        }
        try {
            return Difficulty.valueOf(difficulty.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException ex) {
            return Difficulty.EASY;
        }
    }

    public static Envelope envelope(Difficulty difficulty) {
        return switch (difficulty) {
            case HARD -> new Envelope(
                    StickPullConstants.BOT_HARD_MEAN_TPS,
                    StickPullConstants.BOT_HARD_SIGMA,
                    12,
                    20,
                    180,
                    420);
            case NORMAL -> new Envelope(
                    StickPullConstants.BOT_NORMAL_MEAN_TPS,
                    StickPullConstants.BOT_NORMAL_SIGMA,
                    8,
                    14,
                    220,
                    520);
            case EASY -> new Envelope(
                    StickPullConstants.BOT_EASY_MEAN_TPS,
                    StickPullConstants.BOT_EASY_SIGMA,
                    6,
                    10,
                    500,
                    1100);
        };
    }

    /**
     * Next delay until the following tap (ms). Includes occasional long pauses for EASY.
     */
    public static long nextDelayMs(Difficulty difficulty, Random rng, int tapsSincePause) {
        Objects.requireNonNull(difficulty, "difficulty");
        Objects.requireNonNull(rng, "rng");
        Envelope env = envelope(difficulty);
        double tps = env.meanTps() + rng.nextGaussian() * env.sigma();
        tps = Math.max(1.0, Math.min(StickPullConstants.HARD_CLAMP_TPS - 0.5, tps));
        long base = Math.round(1000.0 / tps);
        int pauseEvery = env.pauseEveryMin()
                + rng.nextInt(Math.max(1, env.pauseEveryMax() - env.pauseEveryMin() + 1));
        if (tapsSincePause + 1 >= pauseEvery) {
            long pause = env.pauseMsMin()
                    + rng.nextInt(Math.max(1, env.pauseMsMax() - env.pauseMsMin() + 1));
            return base + pause;
        }
        return Math.max(50L, base);
    }

    /**
     * Build a delay schedule of {@code tapCount} taps for unit tests / diagnostics.
     */
    public static List<Long> schedule(Difficulty difficulty, long seed, int tapCount) {
        Random rng = new Random(seed);
        List<Long> delays = new ArrayList<>(tapCount);
        int sincePause = 0;
        for (int i = 0; i < tapCount; i++) {
            long delay = nextDelayMs(difficulty, rng, sincePause);
            Envelope env = envelope(difficulty);
            int pauseEvery = env.pauseEveryMin();
            // Detect pause-shaped delays (base + pause)
            boolean paused = delay > Math.round(1000.0 / Math.max(1.0, env.meanTps() - env.sigma())) + 200;
            sincePause = paused ? 0 : sincePause + 1;
            delays.add(delay);
        }
        return delays;
    }

    public static double meanTpsFromDelays(List<Long> delays) {
        if (delays == null || delays.isEmpty()) {
            return 0;
        }
        double sum = 0;
        for (Long d : delays) {
            sum += d;
        }
        double meanDelay = sum / delays.size();
        return 1000.0 / meanDelay;
    }
}
