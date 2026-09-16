package com.nomadgames.session.internal;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MatchRepository extends JpaRepository<MatchEntity, UUID> {

    @Query(
            """
            select case when count(m) > 0 then true else false end
            from MatchEntity m
            where m.status = 'IN_PLAY'
              and (m.mode = 'PRIVATE' or m.mode = 'CASUAL')
              and (m.hostId = :playerId or m.joinerId = :playerId)
            """)
    boolean existsInPlayHumanSeat(@Param("playerId") UUID playerId);
}
