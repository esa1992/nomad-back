package com.nomadgames.session;

import java.time.Instant;

public record WsTicketResponse(String ticket, Instant expiresAt, String reconnectToken) {
    public WsTicketResponse(String ticket, Instant expiresAt) {
        this(ticket, expiresAt, null);
    }
}
