package com.nomadgames.alchiki.proto;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.dyn4j.collision.Fixture;
import org.dyn4j.dynamics.Body;
import org.dyn4j.geometry.Circle;
import org.dyn4j.geometry.Vector2;
import org.dyn4j.world.World;
import org.junit.jupiter.api.Test;

class BurstSimTest {
    static final String POCKETING_THROW =
            """
            {
              "schemaVersion": 1,
              "yUp": true,
              "aimAngleRad": 1.5707963267948966,
              "holdMs": 640,
              "seed": 1,
              "tableId": "alchiki-match-v1"
            }
            """;

    private static final String FIXTURE =
            """
            {
              "schemaVersion": 1,
              "yUp": true,
              "aimAngleRad": 1.0471975512,
              "holdMs": 640,
              "seed": 1,
              "tableId": "alchiki-proto-v1"
            }
            """;

    private static final String SLEEP_THROW =
            """
            {
              "schemaVersion": 1,
              "yUp": true,
              "aimAngleRad": -1.57079632679,
              "holdMs": 150,
              "seed": 1,
              "tableId": "alchiki-proto-v1"
            }
            """;

    @Test
    void fixtureThrowProducesKeyframesAndScore() {
        ThrowInput input = ThrowInput.parse(FIXTURE);
        assertEquals(1, input.schemaVersion);
        assertTrue(input.yUp);
        assertEquals(1.0471975512, input.aimAngleRad, 1e-9);
        assertEquals(640, input.holdMs);
        assertEquals(1, input.seed);
        assertEquals("alchiki-proto-v1", input.tableId);

        Dyn4jBurstSim.Result result = Dyn4jBurstSim.simulate(input);
        assertTrue(result.keyframes().size() >= 3, "expected closed keyframe buffer");
        assertTrue(result.pocketedCount() >= 0);
        if (result.sakaOut()) {
            assertEquals(0, result.resolved().displayedScore());
        }
    }

    @Test
    void timeoutStillScores() {
        ThrowInput input = ThrowInput.parse(FIXTURE);
        Dyn4jBurstSim.Result result = Dyn4jBurstSim.simulate(input, 1.2);
        assertTrue(result.keyframes().size() >= 3, "timeout still emits frames");
        assertTrue(result.pocketedCount() >= 0, "timeout still emits a score");
    }

    @Test
    void outputHasNoClientPosesField() {
        String tainted =
                """
                {
                  "schemaVersion": 1,
                  "yUp": true,
                  "aimAngleRad": 1.0471975512,
                  "holdMs": 640,
                  "seed": 1,
                  "tableId": "alchiki-proto-v1",
                  "pocketedCount": 99,
                  "clientPoses": [{"id":"saka","x":0.0,"y":0.0}],
                  "score": 7
                }
                """;
        ThrowInput input = ThrowInput.parse(tainted);
        Dyn4jBurstSim.Result result = Dyn4jBurstSim.simulate(input);
        assertNotEquals(99, result.pocketedCount(), "harness must not read pocketedCount from input");
        assertNotEquals(7, result.pocketedCount(), "harness must not read score from input");
        assertTrue(
                result.keyframes().size() >= 3,
                "scored pocketedCount comes from dyn4j rest poses, not clientPoses");
    }

    @Test
    void spawnForBoneCountFiveAndSevenReuseBoneRadius() {
        World<Body> easy = new World<Body>();
        Map<String, Body> five = Dyn4jBurstSim.spawnForBoneCount(easy, 5);
        assertEquals(Set.of("saka", "b1", "b2", "b3", "b4", "b5"), five.keySet());
        assertBoneFamilyRadii(five);

        World<Body> hard = new World<Body>();
        Map<String, Body> seven = Dyn4jBurstSim.spawnForBoneCount(hard, 7);
        assertEquals(Set.of("saka", "b1", "b2", "b3", "b4", "b5", "b6", "b7"), seven.keySet());
        assertBoneFamilyRadii(seven);
        Vector2 b7 = seven.get("b7").getWorldCenter();
        assertEquals(0.0, b7.x, 1e-9);
        assertEquals(0.30, b7.y, 1e-9);
    }

    @Test
    void sleepPathWritesFinalKeyframe() {
        ThrowInput input = ThrowInput.parse(SLEEP_THROW);
        Dyn4jBurstSim.Result result = Dyn4jBurstSim.simulate(input, 5.0);
        assertEquals("sleep", result.resolved().settleReason);
        Keyframe last = result.keyframes().get(result.keyframes().size() - 1);
        assertEquals(result.resolved().simMs, last.tMs);
    }

    @Test
    void constructedSakaOutWithPocketsHasDisplayedScoreZero() {
        ThrowInput input = ThrowInput.parse(FIXTURE);
        ThrowResolved resolved =
                new ThrowResolved(
                        input,
                        TableConstants.PROTO_V1,
                        true,
                        "sleep",
                        200,
                        2,
                        true,
                        List.of("b1", "b2"),
                        List.of(new Keyframe(0, List.of(new Keyframe.BodyPose("saka", 0, 0, 0)))));
        assertEquals(0, resolved.displayedScore());
        assertEquals(2, resolved.pocketedCount);
    }

    @Test
    void spawnRemainingPlacesOnlyLeftoverIdsAndSaka() {
        World<Body> world = new World<Body>();
        Map<String, Body> leftover = Dyn4jBurstSim.spawnRemaining(world, Set.of("b1", "b3"));
        assertEquals(Set.of("saka", "b1", "b3"), leftover.keySet());
        Vector2 saka = leftover.get("saka").getWorldCenter();
        assertEquals(0.0, saka.x, 1e-9);
        assertEquals(-1.15, saka.y, 1e-9);
        assertBoneFamilyRadii(leftover);
    }

    @Test
    void simulateRemainingOmitsDroppedIdsFromKeyframesAndPockets() {
        ThrowInput input = ThrowInput.parse(POCKETING_THROW);
        Set<String> remaining = Set.of("b1", "b3");
        Dyn4jBurstSim.Result result = Dyn4jBurstSim.simulate(input, remaining);
        Set<String> bodyIds = keyframeBodyIds(result.keyframes());
        assertTrue(bodyIds.contains("saka"));
        assertTrue(bodyIds.containsAll(Set.of("saka", "b1", "b3")));
        assertFalse(bodyIds.contains("b2"));
        assertFalse(bodyIds.contains("b4"));
        assertFalse(bodyIds.contains("b5"));
        assertFalse(bodyIds.contains("b6"));
        assertFalse(bodyIds.contains("b7"));
        for (String pocketed : result.resolved().pocketedIds) {
            assertTrue(remaining.contains(pocketed), "omitted id must not score: " + pocketed);
        }
    }

    @Test
    void simulateRemainingUsesLeftoverPoseNotSeedLine() {
        ThrowInput input = ThrowInput.parse(POCKETING_THROW);
        Keyframe.BodyPose displaced = new Keyframe.BodyPose("b3", 0.55, -0.45, 0.0);
        Dyn4jBurstSim.Result result =
                Dyn4jBurstSim.simulate(input, Set.of("b3"), Map.of("b3", displaced));
        assertFalse(result.keyframes().isEmpty());
        Keyframe.BodyPose first = result.keyframes().get(0).bodies.stream()
                .filter(pose -> "b3".equals(pose.id))
                .findFirst()
                .orElseThrow();
        double seedY = 0.12;
        assertTrue(
                Math.abs(first.y - displaced.y) < Math.abs(first.y - seedY),
                "bot/next throw must start from leftover rest, not the seed line");
        assertTrue(Math.abs(first.x - displaced.x) < 0.35);
        assertTrue(Math.abs(first.y - displaced.y) < 0.35);
    }

    @Test
    void cannedThrowPocketsAtLeastOneEasyBone() {
        ThrowInput input = ThrowInput.parse(POCKETING_THROW);
        Dyn4jBurstSim.Result result = Dyn4jBurstSim.simulate(input, Set.of("b1", "b2", "b3", "b4", "b5"));
        assertFalse(result.resolved().pocketedIds.isEmpty(), "canned throw must pocket at least one EASY bone");
    }

    @Test
    void simulatePrivateJoinerDoesNotNpeOrPocketSaka() {
        ThrowInput input = ThrowInput.parse(POCKETING_THROW);
        Dyn4jBurstSim.Result result = Dyn4jBurstSim.simulatePrivate(
                input, Set.of("b1", "b2", "b3", "b4", "b5", "b6"), "saka-joiner", List.of("saka-host"));
        assertNotNull(result);
        assertNotNull(result.resolved());
        Set<String> bodyIds = keyframeBodyIds(result.keyframes());
        assertTrue(bodyIds.contains("saka-host"));
        assertTrue(bodyIds.contains("saka-joiner"));
        assertFalse(bodyIds.contains("saka"), "private spawn must not use bot saka id");
        for (String pocketed : result.resolved().pocketedIds) {
            assertFalse(pocketed.startsWith("saka"), "saka ids must not score: " + pocketed);
        }
    }

    @Test
    void simulateRemainingStillSpawnsOnlyBotSakaId() {
        ThrowInput input = ThrowInput.parse(POCKETING_THROW);
        Dyn4jBurstSim.Result result = Dyn4jBurstSim.simulate(input, Set.of("b1", "b3"));
        Set<String> bodyIds = keyframeBodyIds(result.keyframes());
        assertTrue(bodyIds.contains("saka"));
        assertFalse(bodyIds.contains("saka-host"));
        assertFalse(bodyIds.contains("saka-joiner"));
    }

    private static void assertBoneFamilyRadii(Map<String, Body> bodies) {
        for (Map.Entry<String, Body> entry : bodies.entrySet()) {
            Fixture fixture = entry.getValue().getFixture(0);
            assertNotNull(fixture);
            Circle circle = (Circle) fixture.getShape();
            if ("saka".equals(entry.getKey())) {
                assertEquals(TableConstants.sakaRadiusM, circle.getRadius(), 1e-9);
            } else {
                assertEquals(TableConstants.boneRadiusM, circle.getRadius(), 1e-9);
            }
        }
    }

    private static Set<String> keyframeBodyIds(List<Keyframe> frames) {
        Set<String> ids = new HashSet<>();
        for (Keyframe frame : frames) {
            for (Keyframe.BodyPose pose : frame.bodies) {
                ids.add(pose.id);
            }
        }
        return ids;
    }

}

