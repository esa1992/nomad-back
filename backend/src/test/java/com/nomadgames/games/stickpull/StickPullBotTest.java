package com.nomadgames.games.stickpull;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;

import org.junit.jupiter.api.Test;

/**
 * BOT-02 Stick Pull bot jitter envelopes.
 */
class StickPullBotTest {

    @Test
    void easyMeanTpsInBand() {
        List<Long> delays = StickPullBot.schedule(StickPullBot.Difficulty.EASY, 42L, 200);
        double mean = StickPullBot.meanTpsFromDelays(delays);
        assertTrue(mean >= 2.0 && mean <= 4.5, "EASY mean tps=" + mean);
    }

    @Test
    void normalMeanTpsInBand() {
        List<Long> delays = StickPullBot.schedule(StickPullBot.Difficulty.NORMAL, 7L, 200);
        double mean = StickPullBot.meanTpsFromDelays(delays);
        assertTrue(mean >= 3.5 && mean <= 6.5, "NORMAL mean tps=" + mean);
    }

    @Test
    void hardMeanTpsInBand() {
        List<Long> delays = StickPullBot.schedule(StickPullBot.Difficulty.HARD, 99L, 200);
        double mean = StickPullBot.meanTpsFromDelays(delays);
        assertTrue(mean >= 5.0 && mean <= 8.5, "HARD mean tps=" + mean);
    }

    @Test
    void easyPausesPresent() {
        List<Long> delays = StickPullBot.schedule(StickPullBot.Difficulty.EASY, 11L, 80);
        boolean longPause = delays.stream().anyMatch(d -> d >= 500);
        assertTrue(longPause, "EASY must insert ≥500ms pauses: " + delays);
    }

    @Test
    void parseUnknownDefaultsEasy() {
        assertEquals(StickPullBot.Difficulty.EASY, StickPullBot.parse(null));
        assertEquals(StickPullBot.Difficulty.EASY, StickPullBot.parse(""));
        assertEquals(StickPullBot.Difficulty.EASY, StickPullBot.parse("IMPOSSIBLE"));
        assertEquals(StickPullBot.Difficulty.HARD, StickPullBot.parse("hard"));
    }
}
