package com.nomadgames.rating;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

import com.nomadgames.rating.internal.Glicko2;
import com.nomadgames.rating.internal.Glicko2.Rating;

/**
 * MODE-04 / D-104 Glicko-2 defaults + score updates (period m=1).
 */
class Glicko2Test {

    @Test
    void defaultsMatchStack() {
        assertEquals(1500.0, Glicko2.DEFAULT_R, 1e-9);
        assertEquals(350.0, Glicko2.DEFAULT_RD, 1e-9);
        assertEquals(0.06, Glicko2.DEFAULT_VOLATILITY, 1e-9);
        assertEquals(0.5, Glicko2.TAU, 1e-9);
        Rating unrated = Rating.unrated();
        assertEquals(Glicko2.DEFAULT_R, unrated.r(), 1e-9);
        assertEquals(Glicko2.DEFAULT_RD, unrated.rd(), 1e-9);
        assertEquals(Glicko2.DEFAULT_VOLATILITY, unrated.sigma(), 1e-9);
    }

    @Test
    void winLossDrawScores() {
        Rating a = Rating.unrated();
        Rating b = Rating.unrated();

        Rating aWin = Glicko2.update(a, b, 1.0);
        Rating bLoss = Glicko2.update(b, a, 0.0);
        assertTrue(aWin.r() > a.r(), "win raises rating");
        assertTrue(bLoss.r() < b.r(), "loss lowers rating");
        assertTrue(aWin.rd() < a.rd(), "RD shrinks after a game");

        Rating aDraw = Glicko2.update(a, b, 0.5);
        Rating bDraw = Glicko2.update(b, a, 0.5);
        assertEquals(aDraw.r(), bDraw.r(), 1e-6, "symmetric draw keeps equal ratings");
        assertEquals(1500.0, aDraw.r(), 1e-3);
    }
}
