package com.nomadgames.rating.internal;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

public interface GlickoSettlementRepository extends JpaRepository<GlickoSettlementEntity, GlickoSettlementId> {

    boolean existsByMatchIdAndPlayerId(UUID matchId, UUID playerId);
}
