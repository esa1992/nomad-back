package com.nomadgames.games.alchiki;

import java.time.Duration;
import java.time.Instant;

import com.nomadgames.session.MatchStatus;

public final class AlchikiRules {

    /** Legacy constant — no longer ends the match (score is cumulative only). */
    public static final int FIRST_TO = 5;
    /** Legacy constant — turn count no longer ends the match. */
    public static final int TURNS_EACH = 8;
    public static final Duration MATCH_LIMIT = Duration.ofMinutes(4);
    public static final Duration HARD_CAP = Duration.ofMinutes(5);
    public static final Duration TURN_CLOCK = Duration.ofSeconds(20);

    private AlchikiRules() {}

    public static MatchStatus resolve(
            int playerScore,
            int botScore,
            int playerTurns,
            int botTurns,
            Instant now,
            Instant matchDeadline,
            Instant hardCap) {
        return resolve(
                playerScore, botScore, playerTurns, botTurns, now, matchDeadline, hardCap, -1);
    }

    /**
     * Match ends only when the circle is empty or a clock expires.
     * Score alone (first-to-N) and turn caps do not end play while bones remain.
     */
    public static MatchStatus resolve(
            int playerScore,
            int botScore,
            int playerTurns,
            int botTurns,
            Instant now,
            Instant matchDeadline,
            Instant hardCap,
            int bonesRemaining) {
        // No sohi left — settle by score.
        if (bonesRemaining == 0) {
            return byScore(playerScore, botScore);
        }
        if (hardCap != null && !now.isBefore(hardCap)) {
            return byScore(playerScore, botScore);
        }
        if (matchDeadline != null && !now.isBefore(matchDeadline)) {
            return byScore(playerScore, botScore);
        }
        return MatchStatus.IN_PLAY;
    }

    public static MatchStatus resolve(MatchClockState snapshot, Instant now) {
        return resolve(
                snapshot.playerScore(),
                snapshot.botScore(),
                snapshot.playerTurns(),
                snapshot.botTurns(),
                now,
                Instant.ofEpochMilli(snapshot.matchDeadlineEpochMs()),
                Instant.ofEpochMilli(snapshot.hardCapEpochMs()),
                snapshot.bonesRemaining());
    }

    public static boolean forfeitThrowIfExpired(Instant now, Instant turnDeadline) {
        return turnDeadline != null && !now.isBefore(turnDeadline);
    }

    private static MatchStatus byScore(int playerScore, int botScore) {
        if (playerScore > botScore) {
            return MatchStatus.PLAYER_WIN;
        }
        if (botScore > playerScore) {
            return MatchStatus.BOT_WIN;
        }
        return MatchStatus.DRAW;
    }

    public record MatchClockState(
            int playerScore,
            int botScore,
            int playerTurns,
            int botTurns,
            long matchDeadlineEpochMs,
            long hardCapEpochMs,
            int bonesRemaining) {}
}
