package com.nomadgames.session;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Set;

public interface GameEngine {

    List<String> start(String difficulty);

    ScoredThrow applyThrow(String rawJson, Set<String> remainingBoneIds);

    ScoredThrow applyThrow(
            String rawJson, Set<String> remainingBoneIds, List<BodyPoseView> leftoverPoses);

    ScoredThrow applyThrow(
            String rawJson,
            Set<String> remainingBoneIds,
            String throwingSakaId,
            List<String> parkedSakaIds);

    ScoredThrow applyThrow(
            String rawJson,
            Set<String> remainingBoneIds,
            String throwingSakaId,
            List<String> parkedSakaIds,
            List<BodyPoseView> leftoverPoses);

    /**
     * NORMAL six target bone ids plus saka-host and saka-joiner identifiers.
     * Client does not pick turn order (D-30, D-31); two-body spawn is later.
     */
    PrivateTable startPrivate();

    BotThrowView nextBotThrow(String difficulty, int seed, String tableId, Set<String> remainingBoneIds);

    BotThrowView nextBotThrow(
            String difficulty,
            int seed,
            String tableId,
            Set<String> remainingBoneIds,
            List<BodyPoseView> leftoverPoses);

    MatchStatus resolve(ScoreClock clock, Instant now);

    boolean forfeitThrowIfExpired(Instant now, Instant turnDeadline);

    Duration turnClock();

    Duration matchLimit();

    Duration hardCap();
}
