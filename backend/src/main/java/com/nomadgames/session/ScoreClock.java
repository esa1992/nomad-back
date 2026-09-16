package com.nomadgames.session;

import java.time.Instant;

public record ScoreClock(
        int aScore,
        int bScore,
        int aTurns,
        int bTurns,
        Instant matchDeadline,
        Instant hardCap,
        boolean privateMatch) {}
