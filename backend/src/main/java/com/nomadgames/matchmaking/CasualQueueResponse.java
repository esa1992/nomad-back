package com.nomadgames.matchmaking;

import java.util.UUID;

public record CasualQueueResponse(String status, UUID matchId, String mode, UUID ticketId, String game) {

    static CasualQueueResponse idle() {
        return new CasualQueueResponse("IDLE", null, null, null, null);
    }
}
