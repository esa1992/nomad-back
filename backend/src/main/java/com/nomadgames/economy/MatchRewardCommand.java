package com.nomadgames.economy;

import java.util.UUID;

/** Plain command for match reward grants — owned by economy (session must not leak types here). */
public record MatchRewardCommand(
        UUID matchId, UUID playerId, String outcome, String difficulty, boolean humanMatch) {}
