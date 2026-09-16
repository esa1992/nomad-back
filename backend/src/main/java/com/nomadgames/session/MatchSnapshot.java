package com.nomadgames.session;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonInclude;

public record MatchSnapshot(
        String status,
        int playerScore,
        int botScore,
        String turn,
        List<String> bonesLeft,
        int playerTurns,
        int botTurns,
        long turnDeadlineEpochMs,
        long matchDeadlineEpochMs,
        long hardCapEpochMs,
        String mode,
        @JsonInclude(JsonInclude.Include.NON_NULL) String difficulty,
        UUID hostId,
        UUID joinerId,
        String hostLabel,
        String joinerLabel,
        Integer reconnectSecondsLeft,
        @JsonInclude(JsonInclude.Include.NON_NULL) Boolean pauseBudgetGone,
        int coinsGranted,
        int gemsGranted,
        Map<String, String> localLoadout,
        Map<String, String> hostLoadout,
        Map<String, String> joinerLoadout) {}
