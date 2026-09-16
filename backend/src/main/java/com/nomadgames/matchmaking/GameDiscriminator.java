package com.nomadgames.matchmaking;

import java.util.Locale;

/** Server allowlist for rooms.game and casual enqueue (T-06-03). */
public final class GameDiscriminator {

    public static final String ALCHIKI = "ALCHIKI";
    public static final String STICK_PULL = "STICK_PULL";

    private GameDiscriminator() {}

    public static String normalize(String game) {
        if (game == null || game.isBlank()) {
            return ALCHIKI;
        }
        String upper = game.trim().toUpperCase(Locale.ROOT);
        if (!ALCHIKI.equals(upper) && !STICK_PULL.equals(upper)) {
            throw new IllegalArgumentException("game");
        }
        return upper;
    }
}
