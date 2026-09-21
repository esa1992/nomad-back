package com.nomadgames.games.alchiki;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Set;

import org.springframework.stereotype.Component;

import com.nomadgames.alchiki.proto.Dyn4jBurstSim;
import com.nomadgames.alchiki.proto.Keyframe;
import com.nomadgames.alchiki.proto.ThrowInput;
import com.nomadgames.alchiki.proto.ThrowResolved;
import com.nomadgames.games.alchiki.internal.ScriptedBot;
import com.nomadgames.session.BodyPoseView;
import com.nomadgames.session.BotThrowView;
import com.nomadgames.session.GameEngine;
import com.nomadgames.session.KeyframeView;
import com.nomadgames.session.MatchStatus;
import com.nomadgames.session.PlayerThrowView;
import com.nomadgames.session.PrivateTable;
import com.nomadgames.session.ScoreClock;
import com.nomadgames.session.ScoredThrow;
import com.nomadgames.session.ThrowInputView;

@Component
public class AlchikiEngine implements GameEngine {

    @Override
    public List<String> start(String difficulty) {
        int bones =
                switch (difficulty) {
                    case "EASY" -> 5;
                    case "HARD" -> 7;
                    case "NORMAL" -> 6;
                    default -> throw new IllegalArgumentException("difficulty");
                };
        return Dyn4jBurstSim.targetIdsForBoneCount(bones);
    }

    @Override
    public PrivateTable startPrivate() {
        return new PrivateTable(start("NORMAL"), "saka-host", "saka-joiner");
    }

    @Override
    public ScoredThrow applyThrow(String rawJson, Set<String> remainingBoneIds) {
        return applyThrow(ThrowInput.parse(rawJson), remainingBoneIds);
    }

    public ScoredThrow applyThrow(ThrowInput input, Set<String> remainingBoneIds) {
        ThrowResolved resolved = Dyn4jBurstSim.simulate(input, remainingBoneIds).resolved();
        PlayerThrowView view = toView(resolved);
        return new ScoredThrow(
                view, resolved.displayedScore(), resolved.sakaOut, List.copyOf(resolved.pocketedIds));
    }

    @Override
    public ScoredThrow applyThrow(
            String rawJson, Set<String> remainingBoneIds, String throwingSakaId, List<String> parkedSakaIds) {
        ThrowResolved resolved = Dyn4jBurstSim.simulatePrivate(
                        ThrowInput.parse(rawJson), remainingBoneIds, throwingSakaId, parkedSakaIds)
                .resolved();
        PlayerThrowView view = toView(resolved);
        return new ScoredThrow(
                view, resolved.displayedScore(), resolved.sakaOut, List.copyOf(resolved.pocketedIds));
    }

    @Override
    public BotThrowView nextBotThrow(
            String difficulty, int seed, String tableId, Set<String> remainingBoneIds) {
        ThrowInput botInput = ScriptedBot.nextThrow(difficulty, seed, tableId, remainingBoneIds);
        StringBuilder raw = new StringBuilder();
        botInput.appendJson(raw, "");
        ScoredThrow scored = applyThrow(raw.toString(), remainingBoneIds);
        return toBotView(botInput, scored);
    }

    @Override
    public MatchStatus resolve(ScoreClock clock, Instant now) {
        MatchStatus status = AlchikiRules.resolve(
                clock.aScore(),
                clock.bScore(),
                clock.aTurns(),
                clock.bTurns(),
                now,
                clock.matchDeadline(),
                clock.hardCap(),
                clock.bonesRemaining());
        if (!clock.privateMatch()) {
            return status;
        }
        return switch (status) {
            case PLAYER_WIN -> MatchStatus.HOST_WIN;
            case BOT_WIN -> MatchStatus.JOINER_WIN;
            default -> status;
        };
    }

    @Override
    public boolean forfeitThrowIfExpired(Instant now, Instant turnDeadline) {
        return AlchikiRules.forfeitThrowIfExpired(now, turnDeadline);
    }

    @Override
    public Duration turnClock() {
        return AlchikiRules.TURN_CLOCK;
    }

    @Override
    public Duration matchLimit() {
        return AlchikiRules.MATCH_LIMIT;
    }

    @Override
    public Duration hardCap() {
        return AlchikiRules.HARD_CAP;
    }

    private static BotThrowView toBotView(ThrowInput input, ScoredThrow scored) {
        PlayerThrowView view = scored.playerThrow();
        return new BotThrowView(
                new ThrowInputView(
                        input.schemaVersion,
                        input.yUp,
                        input.aimAngleRad,
                        input.holdMs,
                        input.seed,
                        input.tableId),
                scored.displayedScore(),
                view.sakaOut(),
                view.pocketedCount(),
                List.copyOf(scored.pocketedIds()),
                view.keyframes());
    }

    private static PlayerThrowView toView(ThrowResolved resolved) {
        List<KeyframeView> frames = resolved.keyframes.stream()
                .map(AlchikiEngine::toKeyframe)
                .toList();
        return new PlayerThrowView(
                resolved.schemaVersion,
                resolved.yUp,
                resolved.settled,
                resolved.settleReason,
                resolved.simMs,
                resolved.pocketedCount,
                resolved.sakaOut,
                resolved.displayedScore(),
                List.copyOf(resolved.pocketedIds),
                frames);
    }

    private static KeyframeView toKeyframe(Keyframe frame) {
        List<BodyPoseView> bodies = frame.bodies.stream()
                .map(pose -> new BodyPoseView(pose.id, pose.x, pose.y, pose.angle))
                .toList();
        return new KeyframeView(frame.tMs, bodies);
    }
}
