package com.nomadgames.alchiki.proto;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

import org.dyn4j.dynamics.Body;
import org.dyn4j.geometry.Geometry;
import org.dyn4j.geometry.MassType;
import org.dyn4j.geometry.Vector2;
import org.dyn4j.world.World;

/**
 * Authority burst-sim: zero-g dyn4j 6 world, seed-1 hex, sleep or 1.2s timeout (D-09, D-11).
 * pocketedCount comes from rest poses only — input score-like fields are ignored (D-10).
 */
public final class Dyn4jBurstSim {
    private static final int STEP_CAP = 400;
    private static final int KEYFRAME_CAP = 40;
    /** Seed-1 impulse cannot pocket a 1.40m circle; match leftover path scales hold impulse. */
    private static final double MATCH_IMPULSE_SCALE = 3.0;
    private static final String[] TARGET_IDS = {"b1", "b2", "b3", "b4", "b5", "b6", "b7"};

    /** Locked seed-1 layout — must match 01-03, do not invent a client hex helper. */
    private static final double[][] SEED1 = {
        {0.0, -1.15},
        {0.22, 0.0},
        {0.11, 0.19053},
        {-0.11, 0.19053},
        {-0.22, 0.0},
        {-0.11, -0.19053},
        {0.11, -0.19053}
    };

    private static final String[] IDS = {"saka", "b1", "b2", "b3", "b4", "b5", "b6"};

    private Dyn4jBurstSim() {}

    public static final class Result {
        private final ThrowResolved resolved;

        Result(ThrowResolved resolved) {
            this.resolved = Objects.requireNonNull(resolved, "resolved");
        }

        public ThrowResolved resolved() {
            return resolved;
        }

        public List<Keyframe> keyframes() {
            return resolved.keyframes;
        }

        public int pocketedCount() {
            return resolved.pocketedCount;
        }

        public boolean sakaOut() {
            return resolved.sakaOut;
        }
    }

    public static Result simulate(ThrowInput input) {
        return simulate(input, TableConstants.settleTimeoutS);
    }

    public static Result simulate(ThrowInput input, double settleTimeoutS) {
        World<Body> world = newWorld();
        return runBurst(input, world, spawnSeed1(world), settleTimeoutS, 1.0);
    }

    public static Result simulate(ThrowInput input, Set<String> remainingBoneIds) {
        return simulate(input, remainingBoneIds, TableConstants.settleTimeoutS);
    }

    public static Result simulate(ThrowInput input, Set<String> remainingBoneIds, double settleTimeoutS) {
        World<Body> world = newWorld();
        return runBurst(input, world, spawnRemaining(world, remainingBoneIds), settleTimeoutS, MATCH_IMPULSE_SCALE);
    }

    /**
     * PRIVATE table: two rim sakas. Impulse applies only to {@code throwingSakaId}.
     * Does not mutate the seed-1 {@code IDS} array used by {@link #simulate(ThrowInput, Set)}.
     */
    public static Result simulatePrivate(
            ThrowInput input, Set<String> remainingBoneIds, String throwingSakaId, List<String> parkedSakaIds) {
        Objects.requireNonNull(parkedSakaIds, "parkedSakaIds");
        World<Body> world = newWorld();
        return runBurst(
                input,
                world,
                spawnPrivate(world, remainingBoneIds),
                TableConstants.settleTimeoutS,
                MATCH_IMPULSE_SCALE,
                throwingSakaId);
    }

    public static Map<String, Body> spawnForBoneCount(int boneCount) {
        return spawnForBoneCount(newWorld(), boneCount);
    }

    public static Map<String, Body> spawnForBoneCount(World<Body> world, int boneCount) {
        Objects.requireNonNull(world, "world");
        if (boneCount != 5 && boneCount != 6 && boneCount != 7) {
            throw new IllegalArgumentException("boneCount");
        }
        Map<String, Body> bodies = new LinkedHashMap<>();
        addDisk(world, bodies, "saka", SEED1[0][0], SEED1[0][1], true);
        int hexTargets = boneCount == 7 ? 6 : boneCount;
        for (int i = 1; i <= hexTargets; i++) {
            addDisk(world, bodies, IDS[i], SEED1[i][0], SEED1[i][1], false);
        }
        if (boneCount == 7) {
            addDisk(world, bodies, "b7", 0.0, 0.0, false);
        }
        return bodies;
    }

    public static Map<String, Body> spawnRemaining(Set<String> boneIds) {
        return spawnRemaining(newWorld(), boneIds);
    }

    public static Map<String, Body> spawnRemaining(World<Body> world, Set<String> boneIds) {
        Objects.requireNonNull(world, "world");
        Objects.requireNonNull(boneIds, "boneIds");
        Map<String, Body> bodies = new LinkedHashMap<>();
        addDisk(world, bodies, "saka", 0.0, -1.15, true);
        for (String id : TARGET_IDS) {
            if (!boneIds.contains(id)) {
                continue;
            }
            if ("b7".equals(id)) {
                addDisk(world, bodies, "b7", 0.0, 0.0, false);
                continue;
            }
            int index = indexOf(id);
            addDisk(world, bodies, id, SEED1[index][0], SEED1[index][1], false);
        }
        return bodies;
    }

    static Map<String, Body> spawnPrivate(World<Body> world, Set<String> boneIds) {
        Objects.requireNonNull(world, "world");
        Objects.requireNonNull(boneIds, "boneIds");
        Map<String, Body> bodies = new LinkedHashMap<>();
        addDisk(world, bodies, "saka-host", -0.25, -1.12, true);
        addDisk(world, bodies, "saka-joiner", 0.25, -1.12, true);
        for (String id : TARGET_IDS) {
            if (!boneIds.contains(id)) {
                continue;
            }
            if ("b7".equals(id)) {
                addDisk(world, bodies, "b7", 0.0, 0.0, false);
                continue;
            }
            int index = indexOf(id);
            addDisk(world, bodies, id, SEED1[index][0], SEED1[index][1], false);
        }
        return bodies;
    }

    public static List<String> targetIdsForBoneCount(int boneCount) {
        return spawnForBoneCount(boneCount).keySet().stream().filter(id -> !"saka".equals(id)).toList();
    }

    private static Result runBurst(
            ThrowInput input, World<Body> world, Map<String, Body> bodies, double settleTimeoutS, double impulseScale) {
        return runBurst(input, world, bodies, settleTimeoutS, impulseScale, "saka");
    }

    private static Result runBurst(
            ThrowInput input,
            World<Body> world,
            Map<String, Body> bodies,
            double settleTimeoutS,
            double impulseScale,
            String throwingSakaId) {
        Objects.requireNonNull(input, "input");
        Objects.requireNonNull(throwingSakaId, "throwingSakaId");
        JsonSupport.requireFinite("settleTimeoutS", settleTimeoutS);
        if (settleTimeoutS < 0) {
            throw new IllegalArgumentException("settleTimeoutS");
        }

        double impulseNs = ThrowInput.impulseFromHoldMs(input.holdMs) * impulseScale;
        double ix = Math.cos(input.aimAngleRad) * impulseNs;
        double iy = Math.sin(input.aimAngleRad) * impulseNs;
        Body throwing = bodies.get(throwingSakaId);
        if (throwing != null) {
            throwing.applyImpulse(new Vector2(ix, iy));
        }

        int maxSteps = Math.min(STEP_CAP, Math.max(1, (int) Math.round(settleTimeoutS * TableConstants.physicsHz)));
        List<Keyframe> frames = new ArrayList<>();
        frames.add(capture(0, bodies));

        String settleReason = "timeout";
        int stepsRun = 0;
        for (int i = 0; i < maxSteps; i++) {
            world.step(1);
            stepsRun = i + 1;
            int tMs = (int) Math.round(stepsRun * (1000.0 / TableConstants.physicsHz));
            if ((i + 1) % 3 == 0 && frames.size() < KEYFRAME_CAP) {
                frames.add(capture(tMs, bodies));
            }
            if (allAtRest(bodies)) {
                settleReason = "sleep";
                Keyframe rest = capture(tMs, bodies);
                if (!frames.isEmpty() && frames.get(frames.size() - 1).tMs == tMs) {
                    frames.set(frames.size() - 1, rest);
                } else if (frames.size() < KEYFRAME_CAP) {
                    frames.add(rest);
                } else {
                    frames.set(frames.size() - 1, rest);
                }
                break;
            }
        }
        if (frames.size() < 3 && frames.size() < KEYFRAME_CAP) {
            frames.add(capture((int) Math.round(stepsRun * (1000.0 / TableConstants.physicsHz)), bodies));
        }

        PocketScore score = scoreFromRestPoses(bodies, throwingSakaId);
        int simMs = (int) Math.round(stepsRun * (1000.0 / TableConstants.physicsHz));
        ThrowResolved resolved =
                new ThrowResolved(
                        input,
                        TableConstants.PROTO_V1,
                        true,
                        settleReason,
                        simMs,
                        score.pocketedCount,
                        score.sakaOut,
                        score.pocketedIds,
                        frames);
        return new Result(resolved);
    }

    private static World<Body> newWorld() {
        World<Body> world = new World<Body>();
        world.setGravity(new Vector2(0.0, 0.0));
        world.getSettings().setStepFrequency(1.0 / 60.0);
        world.getSettings().setAtRestDetectionEnabled(true);
        return world;
    }

    private static Map<String, Body> spawnSeed1(World<Body> world) {
        return spawnForBoneCount(world, 6);
    }

    private static void addDisk(
            World<Body> world, Map<String, Body> bodies, String id, double x, double y, boolean saka) {
        double radius = saka ? TableConstants.sakaRadiusM : TableConstants.boneRadiusM;
        double mass = saka ? TableConstants.sakaMassKg : TableConstants.boneMassKg;
        double density = mass / (Math.PI * radius * radius);
        Body body = new Body();
        body.addFixture(Geometry.createCircle(radius), density, TableConstants.friction, TableConstants.restitution);
        body.setMass(MassType.NORMAL);
        body.setLinearDamping(TableConstants.linearDamping);
        body.setAngularDamping(TableConstants.angularDamping);
        body.translate(x, y);
        body.setUserData(id);
        world.addBody(body);
        bodies.put(id, body);
    }

    private static int indexOf(String id) {
        for (int i = 0; i < IDS.length; i++) {
            if (IDS[i].equals(id)) {
                return i;
            }
        }
        throw new IllegalArgumentException(id);
    }

    private static Keyframe capture(int tMs, Map<String, Body> bodies) {
        List<Keyframe.BodyPose> poses = new ArrayList<>();
        for (Map.Entry<String, Body> entry : bodies.entrySet()) {
            if (poses.size() >= 8) {
                break;
            }
            Vector2 p = entry.getValue().getWorldCenter();
            double angle = entry.getValue().getTransform().getRotationAngle();
            poses.add(new Keyframe.BodyPose(entry.getKey(), p.x, p.y, angle));
        }
        return new Keyframe(tMs, Keyframe.copyCapped(poses));
    }

    private static boolean allAtRest(Map<String, Body> bodies) {
        for (Body body : bodies.values()) {
            if (!body.isAtRest()) {
                return false;
            }
        }
        return true;
    }

    private static PocketScore scoreFromRestPoses(Map<String, Body> bodies, String throwingSakaId) {
        List<String> pocketedIds = new ArrayList<>();
        Body throwing = bodies.get(throwingSakaId);
        boolean sakaOut = throwing != null && isFullyOutside(throwing, TableConstants.sakaRadiusM);
        for (Map.Entry<String, Body> entry : bodies.entrySet()) {
            if (entry.getKey().startsWith("saka")) {
                continue;
            }
            if (isFullyOutside(entry.getValue(), TableConstants.boneRadiusM)) {
                pocketedIds.add(entry.getKey());
            }
        }
        return new PocketScore(pocketedIds.size(), sakaOut, pocketedIds);
    }

    private static boolean isFullyOutside(Body body, double bodyRadiusM) {
        Vector2 p = body.getWorldCenter();
        return p.distance(0.0, 0.0) > TableConstants.circleRadiusM + bodyRadiusM;
    }

    private record PocketScore(int pocketedCount, boolean sakaOut, List<String> pocketedIds) {}
}
