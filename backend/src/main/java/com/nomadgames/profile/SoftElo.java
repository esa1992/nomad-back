package com.nomadgames.profile;

/**
 * Classic Elo for soft casual MMR (D-75). K=24, floor 100; Ranked/Glicko stays Phase 7.
 */
public final class SoftElo {

    public static final int K = 24;
    public static final int START = 1000;
    public static final int FLOOR = 100;

    private SoftElo() {}

    /**
     * @param score 1.0 win, 0.5 draw, 0.0 loss
     */
    public static int nextRating(int rating, int opponent, double score) {
        double expected = 1.0 / (1.0 + Math.pow(10.0, (opponent - rating) / 400.0));
        int next = (int) Math.round(rating + K * (score - expected));
        return Math.max(FLOOR, next);
    }
}
