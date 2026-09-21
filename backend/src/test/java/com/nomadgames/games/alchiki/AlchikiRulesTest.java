package com.nomadgames.games.alchiki;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Duration;
import java.time.Instant;
import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

import com.nomadgames.session.MatchStatus;

class AlchikiRulesTest {

    private static final Instant T0 = Instant.parse("2026-01-01T00:00:00Z");
    private static final Instant MATCH_DEADLINE = T0.plus(Duration.ofMinutes(4));
    private static final Instant HARD_CAP = T0.plus(Duration.ofMinutes(5));
    private static final Instant TURN_DEADLINE = T0.plus(Duration.ofSeconds(20));

    @Test
    void sessionMatchStatusDeclaresHostAndJoinerWin() {
        Set<String> names =
                Arrays.stream(MatchStatus.values()).map(Enum::name).collect(Collectors.toSet());
        assertTrue(names.containsAll(Set.of(
                "IN_PLAY", "PLAYER_WIN", "BOT_WIN", "DRAW", "HOST_WIN", "JOINER_WIN")));
    }

    @Test
    void constantsLockFirstToFiveAndClocks() {
        assertEquals(5, AlchikiRules.FIRST_TO);
        assertEquals(8, AlchikiRules.TURNS_EACH);
        assertEquals(Duration.ofMinutes(4), AlchikiRules.MATCH_LIMIT);
        assertEquals(Duration.ofMinutes(5), AlchikiRules.HARD_CAP);
        assertEquals(Duration.ofSeconds(20), AlchikiRules.TURN_CLOCK);
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource("resolveCases")
    void resolveTable(
            String name, AlchikiRules.MatchClockState snapshot, Instant now, MatchStatus expected) {
        assertEquals(expected, AlchikiRules.resolve(snapshot, now));
    }

    static Stream<Arguments> resolveCases() {
        return Stream.of(
                Arguments.of(
                        "firstToFive player 5 wins while clocks remain",
                        snap(5, 0, 2, 2),
                        T0.plusSeconds(30),
                        MatchStatus.PLAYER_WIN),
                Arguments.of(
                        "firstToFive bot 5 wins while clocks remain",
                        snap(1, 5, 2, 2),
                        T0.plusSeconds(30),
                        MatchStatus.BOT_WIN),
                Arguments.of(
                        "8 turns each 3 vs 2 is PLAYER_WIN",
                        snap(3, 2, 8, 8),
                        T0.plusSeconds(30),
                        MatchStatus.PLAYER_WIN),
                Arguments.of(
                        "8 turns each 2 vs 2 is DRAW",
                        snap(2, 2, 8, 8),
                        T0.plusSeconds(30),
                        MatchStatus.DRAW),
                Arguments.of(
                        "8 turns each 2 vs 3 is BOT_WIN",
                        snap(2, 3, 8, 8),
                        T0.plusSeconds(30),
                        MatchStatus.BOT_WIN),
                Arguments.of(
                        "4:00 match limit 3 vs 2 is PLAYER_WIN",
                        snap(3, 2, 4, 4),
                        MATCH_DEADLINE,
                        MatchStatus.PLAYER_WIN),
                Arguments.of(
                        "4:00 match limit 2 vs 2 is DRAW",
                        snap(2, 2, 4, 4),
                        MATCH_DEADLINE,
                        MatchStatus.DRAW),
                Arguments.of(
                        "hardCap 5:00 1 vs 0 is PLAYER_WIN",
                        snap(1, 0, 1, 1),
                        HARD_CAP,
                        MatchStatus.PLAYER_WIN),
                Arguments.of(
                        "hardCap 5:00 1 vs 1 is DRAW",
                        snap(1, 1, 1, 1),
                        HARD_CAP,
                        MatchStatus.DRAW),
                Arguments.of(
                        "in play when scores and clocks remain",
                        snap(4, 4, 3, 3),
                        T0.plusSeconds(30),
                        MatchStatus.IN_PLAY),
                Arguments.of(
                        "empty board 3 vs 1 is PLAYER_WIN",
                        snap(3, 1, 2, 2, 0),
                        T0.plusSeconds(30),
                        MatchStatus.PLAYER_WIN),
                Arguments.of(
                        "empty board 1 vs 2 is BOT_WIN",
                        snap(1, 2, 2, 2, 0),
                        T0.plusSeconds(30),
                        MatchStatus.BOT_WIN),
                Arguments.of(
                        "empty board 2 vs 2 is DRAW",
                        snap(2, 2, 2, 2, 0),
                        T0.plusSeconds(30),
                        MatchStatus.DRAW),
                Arguments.of(
                        "bones remain keeps IN_PLAY under first-to",
                        snap(2, 1, 2, 2, 3),
                        T0.plusSeconds(30),
                        MatchStatus.IN_PLAY));
    }

    @Test
    void forfeitThrowIfExpiredWhenNowAtOrAfterTurnDeadline() {
        assertTrue(AlchikiRules.forfeitThrowIfExpired(TURN_DEADLINE, TURN_DEADLINE));
        assertTrue(AlchikiRules.forfeitThrowIfExpired(TURN_DEADLINE.plusSeconds(1), TURN_DEADLINE));
        assertFalse(AlchikiRules.forfeitThrowIfExpired(TURN_DEADLINE.minusSeconds(1), TURN_DEADLINE));
    }

    private static AlchikiRules.MatchClockState snap(
            int playerScore, int botScore, int playerTurns, int botTurns) {
        return snap(playerScore, botScore, playerTurns, botTurns, 6);
    }

    private static AlchikiRules.MatchClockState snap(
            int playerScore, int botScore, int playerTurns, int botTurns, int bonesRemaining) {
        return new AlchikiRules.MatchClockState(
                playerScore,
                botScore,
                playerTurns,
                botTurns,
                MATCH_DEADLINE.toEpochMilli(),
                HARD_CAP.toEpochMilli(),
                bonesRemaining);
    }
}
