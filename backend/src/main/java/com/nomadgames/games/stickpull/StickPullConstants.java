package com.nomadgames.games.stickpull;

/**
 * Yolo numeric locks for Stick Pull (D-88…D-91 / RESEARCH).
 */
public final class StickPullConstants {

    public static final double SOFT_FORCE = 0.06;
    public static final double WIN_THRESHOLD = 0.85;
    public static final double BURST_FORCE_MULT = 0.4;
    public static final double EXHAUST_FORCE_MULT = 0.15;
    public static final double EXHAUST_EXIT_STAMINA = 0.25;

    public static final long RECOVERY_MS = 320L;
    public static final double REGEN_PER_SECOND = 0.35;

    public static final long BURST_WINDOW_MS = 1_500L;
    public static final int SOFT_BAND_MAX_TPS = 6;
    public static final int BURST_BAND_MIN_TPS = 8;
    public static final int HARD_CLAMP_TPS = 10;

    public static final long BUCKET_MS = 200L;
    public static final int MAX_TAPS_PER_BUCKET = 2;

    public static final double SOFT_DRAIN_PER_TAP = 0.04;
    public static final double BURST_DRAIN_PER_TAP = 0.12;

    public static final int DEFAULT_CLOCK_SECONDS = 60;
    public static final int MIN_CLOCK_SECONDS = 15;
    public static final int MAX_CLOCK_SECONDS = 90;

    public static final long COUNTDOWN_STEP_MS = 1_000L;
    public static final int SIM_TICK_HZ = 20;
    public static final int STATE_BROADCAST_HZ = 10;

    public static final int SUSPECT_INTERVAL_COUNT = 20;
    public static final double SUSPECT_VARIANCE_MS2 = 0.5;

    public static final double BOT_EASY_MEAN_TPS = 3.5;
    public static final double BOT_EASY_SIGMA = 0.45;
    public static final double BOT_NORMAL_MEAN_TPS = 5.0;
    public static final double BOT_NORMAL_SIGMA = 0.35;
    public static final double BOT_HARD_MEAN_TPS = 7.0;
    public static final double BOT_HARD_SIGMA = 0.25;

    private StickPullConstants() {}
}
