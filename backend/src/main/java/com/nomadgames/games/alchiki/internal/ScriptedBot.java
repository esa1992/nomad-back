package com.nomadgames.games.alchiki.internal;

import java.util.Objects;
import java.util.Random;
import java.util.Set;

import com.nomadgames.alchiki.proto.ThrowInput;

/**
 * Deterministic noisy ThrowInput per difficulty (RESEARCH A3, D-21, D-22).
 * leftover ids are mixed into the RNG so the bot cannot "see" pocketed bones.
 */
public final class ScriptedBot {

    public static final double SAKA_SPAWN_X = 0.0;
    public static final double SAKA_SPAWN_Y = -1.15;
    public static final double PERFECT_CENTER_AIM = Math.atan2(-SAKA_SPAWN_Y, -SAKA_SPAWN_X);

    private ScriptedBot() {}

    public static ThrowInput nextThrow(
            String difficulty, int seed, String tableId, Set<String> remainingBoneIds) {
        String diff = difficulty == null ? "EASY" : difficulty.toUpperCase();
        int mixed = Objects.hash(seed, remainingBoneIds == null ? Set.of() : remainingBoneIds);
        Random rng = new Random(mixed);

        double aimNoiseRad;
        int holdMin;
        int holdMax;
        switch (diff) {
            case "HARD" -> {
                aimNoiseRad = 0.10;
                holdMin = 700;
                holdMax = 1050;
            }
            case "NORMAL" -> {
                aimNoiseRad = 0.25;
                holdMin = 400;
                holdMax = 800;
            }
            default -> {
                aimNoiseRad = 0.60;
                holdMin = 200;
                holdMax = 450;
            }
        }

        double unit = rng.nextDouble();
        double offset = (unit * 2.0 - 1.0) * aimNoiseRad;
        if ("EASY".equals(diff) && Math.abs(offset) <= 0.2) {
            offset = Math.copySign(0.21 + rng.nextDouble() * (aimNoiseRad - 0.21), offset == 0 ? 1.0 : offset);
        }
        if ("HARD".equals(diff) && rng.nextDouble() < 0.15) {
            offset += rng.nextBoolean() ? 0.85 : -0.85;
        }

        int holdMs = holdMin + rng.nextInt(holdMax - holdMin + 1);
        String table = tableId == null || tableId.isBlank() ? "alchiki-match-v1" : tableId;
        return new ThrowInput(1, true, PERFECT_CENTER_AIM + offset, holdMs, seed, table);
    }
}
