package com.nomadgames.rating.internal;

import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;

@Entity
@Table(name = "glicko_settlements")
@IdClass(GlickoSettlementId.class)
public class GlickoSettlementEntity {

    @Id
    @Column(name = "match_id", nullable = false)
    private UUID matchId;

    @Id
    @Column(name = "player_id", nullable = false)
    private UUID playerId;

    protected GlickoSettlementEntity() {}

    public GlickoSettlementEntity(UUID matchId, UUID playerId) {
        this.matchId = matchId;
        this.playerId = playerId;
    }

    public UUID getMatchId() {
        return matchId;
    }

    public UUID getPlayerId() {
        return playerId;
    }
}
