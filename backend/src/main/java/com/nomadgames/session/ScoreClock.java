package com.nomadgames.session;

import java.time.Instant;

public record ScoreClock(
        int aScore,
        int bScore,
        int aTurns,
        int bTurns,
        Instant matchDeadline,
        Instant hardCap,
        boolean privateMatch,
        /** Remaining sohi on the table; 0 ends the match by score. Use -1 to ignore. */
        int bonesRemaining) {}
