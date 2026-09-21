package com.nomadgames.games.alchiki;

import java.time.Duration;
import java.time.Instant;

import com.nomadgames.session.MatchStatus;

public final class AlchikiRules {

    public static final int FIRST_TO = 5;
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

    public static MatchStatus resolve(
            int playerScore,
            int botScore,
            int playerTurns,
            int botTurns,
            Instant now,
            Instant matchDeadline,
            Instant hardCap,
            int bonesRemaining) {
        if (hardCap != null && !now.isBefore(hardCap)) {
            return byScore(playerScore, botScore);
        }
        if (playerScore >= FIRST_TO) {
            return MatchStatus.PLAYER_WIN;
        }
        if (botScore >= FIRST_TO) {
            return MatchStatus.BOT_WIN;
        }
        // No sohi left on the table — nothing left to throw at; settle by score.
        if (bonesRemaining == 0) {
            return byScore(playerScore, botScore);
        }
        if (playerTurns >= TURNS_EACH && botTurns >= TURNS_EACH) {
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
