package com.nomadgames.matchmaking;

import java.time.Instant;
import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonInclude;

public record RoomLobbyResponse(
        UUID roomId,
        @JsonInclude(JsonInclude.Include.NON_NULL) String code,
        String hostLabel,
        String joinerLabel,
        boolean hostReady,
        boolean joinerReady,
        String status,
        Instant idleExpiresAt,
        UUID matchId,
        boolean bothReady,
        String game) {}
