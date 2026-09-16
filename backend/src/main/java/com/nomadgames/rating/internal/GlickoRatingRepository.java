package com.nomadgames.rating.internal;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

public interface GlickoRatingRepository extends JpaRepository<GlickoRatingEntity, GlickoRatingId> {

    Optional<GlickoRatingEntity> findByPlayerIdAndGameAndSeasonKey(UUID playerId, String game, String seasonKey);
}
