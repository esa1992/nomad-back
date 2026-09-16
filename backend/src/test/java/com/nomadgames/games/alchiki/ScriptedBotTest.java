package com.nomadgames.games.alchiki;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.LinkedHashSet;
import java.util.Set;

import org.junit.jupiter.api.Test;

import com.nomadgames.alchiki.proto.ThrowInput;
import com.nomadgames.games.alchiki.internal.ScriptedBot;

class ScriptedBotTest {

    private static final Set<String> EASY_BONES = new LinkedHashSet<>(Set.of("b1", "b2", "b3", "b4", "b5"));
    private static final String TABLE = "alchiki-match-v1";
    private static final double PERFECT_CENTER_AIM = Math.PI / 2;

    @Test
    void easyHoldIsNoisyAndMissesCenterOnFixedSeed() {
        ThrowInput easy = ScriptedBot.nextThrow("EASY", 1, TABLE, EASY_BONES);
        assertInstanceOf(ThrowInput.class, easy);
        assertEquals(1, easy.schemaVersion);
        assertTrue(easy.yUp);
        assertTrue(easy.holdMs >= 200 && easy.holdMs <= 450, "EASY holdMs must be 200-450, was " + easy.holdMs);
        assertTrue(
                Math.abs(easy.aimAngleRad - PERFECT_CENTER_AIM) > 0.2,
                "EASY aim must miss perfect-center by more than 0.2 rad, was " + easy.aimAngleRad);
    }

    @Test
    void normalAndHardAreValidThrowInputAndHardHoldIsHigherThanEasy() {
        ThrowInput easy = ScriptedBot.nextThrow("EASY", 1, TABLE, EASY_BONES);
        ThrowInput normal = ScriptedBot.nextThrow("NORMAL", 1, TABLE, EASY_BONES);
        ThrowInput hard = ScriptedBot.nextThrow("HARD", 1, TABLE, EASY_BONES);
        assertInstanceOf(ThrowInput.class, normal);
        assertInstanceOf(ThrowInput.class, hard);
        assertTrue(Double.isFinite(normal.aimAngleRad));
        assertTrue(Double.isFinite(hard.aimAngleRad));
        assertTrue(normal.holdMs >= 150 && normal.holdMs <= 1100);
        assertTrue(hard.holdMs >= 150 && hard.holdMs <= 1100);
        assertTrue(hard.holdMs > easy.holdMs, "HARD holdMs should exceed EASY for seed 1");
    }

    @Test
    void nextThrowIsThrowInputNotAScoreDto() {
        ThrowInput input = ScriptedBot.nextThrow("EASY", 1, TABLE, EASY_BONES);
        assertInstanceOf(ThrowInput.class, input);
        StringBuilder json = new StringBuilder();
        input.appendJson(json, "");
        String body = json.toString();
        assertTrue(body.contains("\"aimAngleRad\""));
        assertTrue(body.contains("\"holdMs\""));
        assertTrue(!body.contains("displayedScore") && !body.contains("pocketedCount"));
    }
}
