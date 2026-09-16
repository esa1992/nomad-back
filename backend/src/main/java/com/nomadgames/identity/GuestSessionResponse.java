package com.nomadgames.identity;

import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record GuestSessionResponse(
        UUID playerId, String accessToken, String refreshToken, boolean guest, AdoptHint adoptHint) {

    public GuestSessionResponse(UUID playerId, String accessToken, String refreshToken, boolean guest) {
        this(playerId, accessToken, refreshToken, guest, null);
    }
}
