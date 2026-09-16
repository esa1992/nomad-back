package com.nomadgames.session;

import java.util.UUID;

public record RematchAcceptResponse(boolean accepted, UUID matchId, int rematchSeconds, String turn) {}
