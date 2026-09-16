package com.nomadgames.session;

import java.util.UUID;

public record RematchPollResponse(
        boolean acceptedHost,
        boolean acceptedJoiner,
        int rematchSeconds,
        UUID matchId,
        boolean expired) {}
