package com.nomadgames.session;

import java.util.List;
import java.util.Map;
import java.util.UUID;

public record MatchCreatedResponse(
        UUID matchId,
        String status,
        String game,
        String difficulty,
        List<String> boneIds,
        int playerScore,
        int botScore,
        String turn,
        long turnDeadlineEpochMs,
        long matchDeadlineEpochMs,
        long hardCapEpochMs,
        Map<String, String> localLoadout) {}
