package com.nomadgames.rating.internal;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

public class GlickoSettlementId implements Serializable {

    private UUID matchId;
    private UUID playerId;

    public GlickoSettlementId() {}

    public GlickoSettlementId(UUID matchId, UUID playerId) {
        this.matchId = matchId;
        this.playerId = playerId;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) {
            return true;
        }
        if (!(o instanceof GlickoSettlementId that)) {
            return false;
        }
        return Objects.equals(matchId, that.matchId) && Objects.equals(playerId, that.playerId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(matchId, playerId);
    }
}
