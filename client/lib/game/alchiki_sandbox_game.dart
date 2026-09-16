import 'package:client/game/bone_body.dart';
import 'package:client/game/felt_circle.dart';
import 'package:client/game/physics_stepper.dart';
import 'package:client/game/saka_body.dart';
import 'package:client/input/aim_controller.dart';
import 'package:client/input/throw_input.dart';
import 'package:client/replay/keyframe_player.dart';
import 'package:client/replay/throw_resolved.dart';
import 'package:client/schema/table_constants.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/text.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/painting.dart';

/// 0.20 native hook. Wave 1 locked flame_forge2d 0.19 — no-op so World can exist.
Future<void> initializeForge2D() async {}

/// 2.5D presentation squash. Negative Y also maps Y-up meters onto Flame (D-06).
const double presentationScaleY = 0.86;

/// Sleep of every dynamic body, or [TableConstants.settleTimeoutS] (1.2 s).
bool computeSettled(bool allDynamicSleeping, double simTimeS) {
  return allDynamicSleeping || simTimeS >= TableConstants.settleTimeoutS;
}

class FixedDtWorld extends Forge2DWorld {
  FixedDtWorld({super.gravity});

  final PhysicsStepper stepper = PhysicsStepper();

  @override
  void update(double dt) {
    stepper.tick(dt, physicsWorld.stepDt);
  }
}

/// Zero-g Forge2D sandbox. Gravity is Vector2.zero() (D-06).
class AlchikiSandboxGame extends Forge2DGame {
  AlchikiSandboxGame()
    : super(
        gravity: Vector2.zero(),
        world: FixedDtWorld(gravity: Vector2.zero()),
        zoom: 100,
      );

  /// Seed-1 hex (meters, Y-up). Locked so 01-04 Dyn4jBurstSim matches.
  static const int boneCount = TableConstants.boneCount;
  static final Map<String, Vector2> seed1Bones = {
    'b1': Vector2(0.22, 0.0),
    'b2': Vector2(0.11, 0.19053),
    'b3': Vector2(-0.11, 0.19053),
    'b4': Vector2(-0.22, 0.0),
    'b5': Vector2(-0.11, -0.19053),
    'b6': Vector2(0.11, -0.19053),
  };

  final AimController aim = AimController();
  late final SakaBody saka;
  late final PresentationLayer parlor;
  late final FeltCircle felt;
  late final List<BoneBody> bones;
  late final FpsTextComponent fpsHud;
  final Set<String> _flashedBoneIds = {};
  final List<PlusOnePopup> _plusOnes = [];

  bool aimLocked = false;
  bool throwing = false;
  bool tableSettled = true;
  bool replaying = false;
  double simTimeS = 0;
  double replayTimeMs = 0;
  int previewCount = 0;
  bool sakaOut = false;
  void Function()? onSettled;
  void Function()? onReplayEnded;
  ThrowResolved? _replayResolved;
  List<ReplayTarget> _replayTargets = const [];

  int get debugFps =>
      isLoaded ? fpsHud.fpsComponent.fps.round() : 0;

  int get debugBodyCount {
    if (!isLoaded) {
      return 0;
    }
    return world.physicsWorld.bodies
        .where((body) => body.bodyType == BodyType.dynamic)
        .length;
  }

  @override
  Future<void> onLoad() async {
    await initializeForge2D();
    await super.onLoad();

    camera.viewfinder.anchor = Anchor.center;

    parlor = PresentationLayer();
    felt = FeltCircle();
    saka = SakaBody();
    bones = [
      for (final entry in seed1Bones.entries)
        BoneBody(boneId: entry.key, spawn: entry.value.clone()),
    ];
    fpsHud = FpsTextComponent(
      position: Vector2(-1.72, 1.52),
      anchor: Anchor.topLeft,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFF4E8C8),
          fontSize: 0.14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    await camera.viewfinder.add(fpsHud);
    await world.add(parlor);
    await parlor.addAll([
      felt,
      saka,
      ...bones,
      AimArrow(sandbox: this),
      TableDragLayer(sandbox: this),
    ]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (replaying) {
      _advanceReplay(dt);
      return;
    }
    if (throwing && !tableSettled) {
      simTimeS += dt;
      _flashNewlyPocketedBones();
      if (computeSettled(_allDynamicSleeping(), simTimeS)) {
        _freezePoses();
        tableSettled = true;
        throwing = false;
        _applyPreviewAfterSettle();
        onSettled?.call();
      }
    }
  }

  void startReplay(ThrowResolved resolved) {
    _replayResolved = resolved;
    replayTimeMs = 0;
    replaying = true;
    throwing = false;
    tableSettled = true;
    aimLocked = true;
    _replayTargets = [
      BodyReplayTarget(id: 'saka', body: saka.body),
      for (final bone in bones)
        BodyReplayTarget(id: bone.boneId, body: bone.body),
    ];
    _freezePoses();
    KeyframePlayer.applyFrame(0, resolved.keyframes, _replayTargets);
  }

  void cancelReplay() {
    replaying = false;
    _replayResolved = null;
    _replayTargets = const [];
    replayTimeMs = 0;
  }

  void _advanceReplay(double dt) {
    final resolved = _replayResolved;
    if (resolved == null || resolved.keyframes.isEmpty) {
      _finishReplay();
      return;
    }
    replayTimeMs += dt * 1000;
    // Keyframes win if local preview poses diverge (D-10, D-11).
    KeyframePlayer.applyFrame(replayTimeMs, resolved.keyframes, _replayTargets);
    final lastMs = resolved.keyframes.last.tMs.toDouble();
    if (replayTimeMs >= lastMs) {
      KeyframePlayer.applyFrame(lastMs, resolved.keyframes, _replayTargets);
      _finishReplay();
    }
  }

  void _finishReplay() {
    replaying = false;
    _replayResolved = null;
    _replayTargets = const [];
    aimLocked = true;
    onReplayEnded?.call();
  }

  bool _allDynamicSleeping() {
    for (final body in world.physicsWorld.bodies) {
      if (body.bodyType == BodyType.dynamic && body.isAwake) {
        return false;
      }
    }
    return true;
  }

  void _freezePoses() {
    for (final body in world.physicsWorld.bodies) {
      if (body.bodyType == BodyType.dynamic) {
        body.linearVelocity.setZero();
        body.angularVelocity = 0;
        body.setAwake(false);
      }
    }
  }

  void _flashNewlyPocketedBones() {
    for (final bone in bones) {
      if (_flashedBoneIds.contains(bone.boneId) || !bone.isMounted) {
        continue;
      }
      final p = bone.body.worldCenter;
      if (isFullyOutside(
        p.x,
        p.y,
        TableConstants.circleRadiusM,
        TableConstants.boneRadiusM,
      )) {
        _flashedBoneIds.add(bone.boneId);
        felt.flashRim(200);
      }
    }
  }

  void _applyPreviewAfterSettle() {
    _clearPlusOnes();
    final sakaPos = saka.body.worldCenter;
    sakaOut = isFullyOutside(
      sakaPos.x,
      sakaPos.y,
      TableConstants.circleRadiusM,
      TableConstants.sakaRadiusM,
    );
    previewCount = 0;
    for (final bone in bones) {
      if (!bone.isMounted) {
        continue;
      }
      final p = bone.body.worldCenter;
      if (isFullyOutside(
        p.x,
        p.y,
        TableConstants.circleRadiusM,
        TableConstants.boneRadiusM,
      )) {
        previewCount++;
        final popup = PlusOnePopup(position: bone.position.clone());
        _plusOnes.add(popup);
        parlor.add(popup);
      }
    }
  }

  void _clearPlusOnes() {
    for (final popup in _plusOnes) {
      popup.removeFromParent();
    }
    _plusOnes.clear();
  }

  void resetTable() {
    cancelReplay();
    _clearPlusOnes();
    saka.snapToSpawn();
    for (final bone in bones) {
      bone.snapToSpawn();
    }
    _flashedBoneIds.clear();
    previewCount = 0;
    sakaOut = false;
    tableSettled = true;
    throwing = false;
    aimLocked = false;
    simTimeS = 0;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final minSide = size.x < size.y ? size.x : size.y;
    if (minSide > 0) {
      camera.viewfinder.zoom = minSide / (TableConstants.circleRadiusM * 2.6);
    }
  }

  void throwSaka(ThrowInput input) {
    cancelReplay();
    throwing = true;
    tableSettled = false;
    simTimeS = 0;
    aimLocked = true;
    saka.applyThrowImpulse(input);
  }
}

/// Applies JVM poses onto a Forge2D body. Playback overwrites local preview.
class BodyReplayTarget implements ReplayTarget {
  BodyReplayTarget({required this.id, required this.body});

  @override
  final String id;
  final Body body;

  @override
  void setTransform(double x, double y, double angle) {
    body.setTransform(Vector2(x, y), angle);
    body.linearVelocity.setZero();
    body.angularVelocity = 0;
    body.setAwake(false);
  }
}

/// Floating +1 after settle. Cream, not accent gold (UI-SPEC).
class PlusOnePopup extends PositionComponent {
  PlusOnePopup({required super.position})
    : super(priority: 40, anchor: Anchor.center);

  double _age = 0;
  static const double lifeS = 0.9;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= lifeS) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / lifeS).clamp(0.0, 1.0);
    final painter = TextPainter(
      text: TextSpan(
        text: '+1',
        style: TextStyle(
          color: const Color(0xFFF4E8C8).withValues(alpha: 1 - t),
          fontSize: 0.22,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
  }
}

class PresentationLayer extends PositionComponent {
  PresentationLayer()
    : super(
        anchor: Anchor.center,
        scale: Vector2(1, -presentationScaleY),
      );
}

class AimArrow extends PositionComponent {
  AimArrow({required this.sandbox}) : super(priority: 10);

  static const double lengthM = 0.42;

  final AlchikiSandboxGame sandbox;

  @override
  void render(Canvas canvas) {
    if (!sandbox.saka.isMounted) {
      return;
    }
    final from = sandbox.saka.position;
    final dir = sandbox.aim.aimDir;
    final to = from + dir * lengthM;
    final paint = Paint()
      ..color = const Color(0xFFF4E8C8)
      ..strokeWidth = 0.03
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from.toOffset(), to.toOffset(), paint);
    final head = to.toOffset();
    final left = (to - dir * 0.08 + Vector2(-dir.y, dir.x) * 0.04).toOffset();
    final right = (to - dir * 0.08 + Vector2(dir.y, -dir.x) * 0.04).toOffset();
    canvas.drawLine(head, left, paint);
    canvas.drawLine(head, right, paint);
  }
}

class TableDragLayer extends PositionComponent with DragCallbacks {
  TableDragLayer({required this.sandbox})
    : super(
        size: Vector2.all(TableConstants.circleRadiusM * 3),
        anchor: Anchor.center,
        priority: 20,
      );

  final AlchikiSandboxGame sandbox;

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (sandbox.aimLocked) {
      return;
    }
    final local = event.localEndPosition;
    if (local.x.isNaN || local.y.isNaN) {
      return;
    }
    sandbox.aim.updateFromWorldPoint(
      localToParent(local),
      sandbox.saka.position,
    );
  }
}
