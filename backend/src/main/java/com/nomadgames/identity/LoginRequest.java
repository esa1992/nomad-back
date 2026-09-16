package com.nomadgames.identity;

import java.util.UUID;

/**
 * Bound login body. When {@code guestPlayerId} is set, possession must be proven via
 * {@code Authorization: Bearer} guest access and/or {@code guestRefreshToken}.
 */
public record LoginRequest(
        String username, String password, UUID guestPlayerId, String adopt, String guestRefreshToken) {}
