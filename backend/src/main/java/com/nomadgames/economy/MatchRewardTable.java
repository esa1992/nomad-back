package com.nomadgames.economy;

/**
 * Server-side match reward table (ECON-01). Win &gt; loss &gt; 0; GEMS scarce and win-only.
 * humanMatch=true covers PRIVATE and CASUAL PvP seats (same COINS/GEMS column).
 */
public final class MatchRewardTable {

    public static final String MATCH_REWARD = "MATCH_REWARD";

    private MatchRewardTable() {}

    public static int coins(String outcome, String difficulty, boolean humanMatch) {
        String o = outcome == null ? "LOSS" : outcome.toUpperCase();
        if (humanMatch) {
            return switch (o) {
                case "WIN" -> 36;
                case "DRAW" -> 20;
                default -> 10;
            };
        }
        String d = difficulty == null ? "NORMAL" : difficulty.toUpperCase();
        return switch (o) {
            case "WIN" -> switch (d) {
                case "EASY" -> 24;
                case "HARD" -> 40;
                default -> 32;
            };
            case "DRAW" -> switch (d) {
                case "EASY" -> 14;
                case "HARD" -> 22;
                default -> 18;
            };
            default -> switch (d) {
                case "EASY" -> 8;
                case "HARD" -> 12;
                default -> 10;
            };
        };
    }

    /** Win-only; +1 GEMS when hash(matchId, playerId) % 100 &lt; p. */
    public static int gems(
            String outcome, String difficulty, boolean humanMatch, java.util.UUID matchId, java.util.UUID playerId) {
        if (outcome == null || !"WIN".equalsIgnoreCase(outcome)) {
            return 0;
        }
        int p;
        if (humanMatch) {
            p = 6;
        } else {
            String d = difficulty == null ? "NORMAL" : difficulty.toUpperCase();
            p = switch (d) {
                case "EASY" -> 3;
                case "HARD" -> 8;
                default -> 5;
            };
        }
        int bucket = Math.floorMod(java.util.Objects.hash(matchId, playerId), 100);
        return bucket < p ? 1 : 0;
    }

    public static String idempotencyKey(java.util.UUID matchId, java.util.UUID playerId) {
        return matchId + ":" + playerId + ":" + MATCH_REWARD;
    }

    public static String gemsIdempotencyKey(java.util.UUID matchId, java.util.UUID playerId) {
        return matchId + ":" + playerId + ":" + MATCH_REWARD + ":GEMS";
    }
}
