package com.nomadgames.games.alchiki;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

import org.junit.jupiter.api.Test;

import com.nomadgames.session.BotThrowView;
import com.nomadgames.session.GameEngine;
import com.nomadgames.session.MatchStatus;
import com.nomadgames.session.PrivateTable;
import com.nomadgames.session.ScoreClock;

class AlchikiEngineSpiTest {

    private static final Instant T0 = Instant.parse("2026-01-01T00:00:00Z");
    private static final Instant MATCH_DEADLINE = T0.plus(Duration.ofMinutes(4));
    private static final Instant HARD_CAP = T0.plus(Duration.ofMinutes(5));
    private static final Instant NOW = T0.plusSeconds(30);

    private final GameEngine engine = new AlchikiEngine();

    @Test
    void startPrivateUsesNormalBonesAndSakaHostJoinerIds() {
        PrivateTable table = engine.startPrivate();
        assertEquals(engine.start("NORMAL"), table.boneIds());
        assertEquals(6, table.boneIds().size());
        assertEquals("saka-host", table.hostSakaId());
        assertEquals("saka-joiner", table.joinerSakaId());
    }

    @Test
    void resolveMapsPrivateFirstToFiveOntoHostAndJoinerWin() {
        ScoreClock hostLead = new ScoreClock(5, 0, 2, 2, MATCH_DEADLINE, HARD_CAP, true, 6);
        assertEquals(MatchStatus.HOST_WIN, engine.resolve(hostLead, NOW));
        ScoreClock joinerLead = new ScoreClock(0, 5, 2, 2, MATCH_DEADLINE, HARD_CAP, true, 6);
        assertEquals(MatchStatus.JOINER_WIN, engine.resolve(joinerLead, NOW));
        ScoreClock draw = new ScoreClock(2, 2, 8, 8, MATCH_DEADLINE, HARD_CAP, true, 6);
        assertEquals(MatchStatus.DRAW, engine.resolve(draw, NOW));
        ScoreClock botPath = new ScoreClock(5, 0, 2, 2, MATCH_DEADLINE, HARD_CAP, false, 6);
        assertEquals(MatchStatus.PLAYER_WIN, engine.resolve(botPath, NOW));
        ScoreClock emptyBoard = new ScoreClock(3, 1, 2, 2, MATCH_DEADLINE, HARD_CAP, true, 0);
        assertEquals(MatchStatus.HOST_WIN, engine.resolve(emptyBoard, NOW));
    }

    @Test
    void clocksAndForfeitDelegateToAlchikiRules() {
        assertEquals(AlchikiRules.TURN_CLOCK, engine.turnClock());
        assertEquals(AlchikiRules.MATCH_LIMIT, engine.matchLimit());
        assertEquals(AlchikiRules.HARD_CAP, engine.hardCap());
        assertFalse(engine.forfeitThrowIfExpired(NOW, NOW.plus(Duration.ofSeconds(20))));
    }

    @Test
    void nextBotThrowReturnsBotThrowViewForEasyLeftovers() {
        Set<String> remaining = new LinkedHashSet<>(List.of("b1", "b2", "b3", "b4", "b5"));
        BotThrowView bot = engine.nextBotThrow("EASY", 1, "alchiki-match-v1", remaining);
        assertNotNull(bot);
        assertNotNull(bot.input());
        assertEquals("alchiki-match-v1", bot.input().tableId());
        assertEquals(1, bot.input().seed());
    }
}
