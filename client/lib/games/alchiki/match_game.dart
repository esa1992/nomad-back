import 'dart:math' as math;

import 'package:client/game/alchiki_sandbox_game.dart';
import 'package:client/game/bone_body.dart';
import 'package:client/game/felt_circle.dart';
import 'package:client/game/physics_stepper.dart';
import 'package:client/game/saka_body.dart';
import 'package:client/game/throw_juice.dart';
import 'package:client/games/alchiki/aiming_marker.dart';
import 'package:client/games/alchiki/throw_hand.dart';
import 'package:client/input/aim_controller.dart';
import 'package:client/input/throw_input.dart';
import 'package:client/replay/keyframe_player.dart';
import 'package:client/replay/throw_resolved.dart';
import 'package:client/schema/table_constants.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/painting.dart';

/// Counts actual Forge2D steps so settle time matches the 1/60 JVM clock (WR-01).
class MatchFixedDtWorld extends Forge2DWorld {
  MatchFixedDtWorld({super.gravity});

  final PhysicsStepper stepper = PhysicsStepper();
  int stepsThisTick = 0;

  @override
  void update(double dt) {
    stepsThisTick = 0;
    stepper.tick(dt, (double stepDt) {
      stepsThisTick++;
      physicsWorld.stepDt(stepDt);
    });
  }
}

/// Lifted Forge2D match table. Next throw starts at the rim; pocketed ids stay gone.
class AlchikiMatchGame extends Forge2DGame {
  AlchikiMatchGame({
    this.difficulty = 'EASY',
    this.mode,
    this.localSeat,
    this.turnSeat,
    this.localLoadout = const <String, String>{},
    this.hostLoadout = const <String, String>{},
    this.joinerLoadout = const <String, String>{},
  }) : super(
         gravity: Vector2.zero(),
         world: MatchFixedDtWorld(gravity: Vector2.zero()),
         zoom: 100,
       );

  final String difficulty;
  final String? mode;
  String? localSeat;
  String? turnSeat;

  /// Server seat loadouts at match start / rematch only (D-56, D-57). Never mid-throw.
  final Map<String, String> localLoadout;
  final Map<String, String> hostLoadout;
  final Map<String, String> joinerLoadout;

  static const Color _youFill = Color(0xFFFFF6D6);
  static const Color _youStripe = Color(0xFF8B4513);
  static const Color _oppFill = Color(0xFF7EB6D9);
  static const Color _oppStripe = Color(0xFF2F5F7A);
  static final Vector2 hostSpawn = Vector2(-0.25, -1.12);
  static final Vector2 joinerSpawn = Vector2(0.25, -1.12);

  /// Presentation-only SKU→Color (ECON-03 / D-54). stick_pull ignored on Alchiki.
  static Color fillForSku(String? skuId, Color fallback) {
    return _themePaint(skuId, fallback);
  }

  static Color stripeForLoadout(Map<String, String> loadout, Color fallback) {
    final String? ornament = loadout['saka_ornament'];
    final String? material = loadout['saka_material'];
    if (ornament != null && !ornament.contains('default')) {
      return _themePaint(ornament, fallback);
    }
    if (material != null && !material.contains('default')) {
      return _themePaint(material, fallback);
    }
    return fallback;
  }

  static Color trailForLoadout(Map<String, String> loadout) {
    return _themePaint(loadout['trail'], const Color(0xFFF4E8C8));
  }

  /// Presentation rim tint for table_fx; null keeps FeltCircle.rimIdle (D-54).
  static Color? tableFxForLoadout(Map<String, String> loadout) {
    final String? skuId = loadout['table_fx'];
    if (skuId == null || skuId.isEmpty) {
      return null;
    }
    final String key = skuId.toLowerCase();
    if (key.contains('default')) {
      return null;
    }
    const Color sentinel = Color(0x00000001);
    final Color painted = _themePaint(skuId, sentinel);
    return painted == sentinel ? null : painted;
  }

  static Color victoryForLoadout(Map<String, String> loadout) {
    return _themePaint(loadout['victory'], const Color(0xFFF4E8C8));
  }

  static Color _themePaint(String? skuId, Color fallback) {
    if (skuId == null || skuId.isEmpty) {
      return fallback;
    }
    final String key = skuId.toLowerCase();
    if (key.contains('default')) {
      return fallback;
    }
    if (key.contains('gold')) {
      return const Color(0xFFF0B429);
    }
    if (key.contains('neon')) {
      return const Color(0xFF7CFF6B);
    }
    if (key.contains('ice')) {
      return const Color(0xFF7EB6D9);
    }
    if (key.contains('fire')) {
      return const Color(0xFFE85D04);
    }
    if (key.contains('space')) {
      return const Color(0xFF3D2B8E);
    }
    if (key.contains('knot')) {
      return const Color(0xFF8B4513);
    }
    return fallback;
  }

  static Map<String, Vector2> bonesForDifficulty(String difficulty) {
    final Map<String, Vector2> hex = {
      for (final entry in AlchikiSandboxGame.seed1Bones.entries)
        entry.key: entry.value.clone(),
    };
    switch (difficulty.toUpperCase()) {
      case 'HARD':
        hex['b7'] = Vector2(0.0, 0.30);
        return hex;
      case 'NORMAL':
        return hex;
      default:
        hex.remove('b6');
        return hex;
    }
  }

  final AimController aim = AimController();
  SakaBody? _botSaka;
  late SakaBody hostSaka;
  late SakaBody joinerSaka;
  late final PresentationLayer parlor;
  late final FeltCircle felt;
  late final List<BoneBody> bones;
  late final AimingMarker aimingMarker;
  final Set<String> pocketedIds = <String>{};
  final Set<String> _pendingPocketedIds = <String>{};
  final Set<String> _foulRestoreIds = <String>{};
  final Set<String> _flashedBoneIds = <String>{};
  final List<PlusOnePopup> _plusOnes = <PlusOnePopup>[];

  bool get isPrivate =>
      mode == 'private' || mode == 'casual' || mode == 'ranked';

  SakaBody get saka => throwingSaka;

  SakaBody get throwingSaka {
    if (!isPrivate) {
      return _botSaka!;
    }
    return turnSeat == 'joiner' ? joinerSaka : hostSaka;
  }

  SakaBody get opponentSaka {
    if (!isPrivate) {
      return _botSaka!;
    }
    return localSeat == 'joiner' ? hostSaka : joinerSaka;
  }

  bool get isLocalTurn => !isPrivate || turnSeat == localSeat;

  bool showAimingMarker = false;
  bool showThrowHand = false;
  double holdChargeT = 0;
  double throwFlickT = 0;
  bool aimLocked = false;
  bool throwing = false;
  bool tableSettled = true;
  bool replaying = false;
  double simTimeS = 0;
  double replayTimeMs = 0;
  int previewCount = 0;
  bool sakaOut = false;
  Color? trailTint;
  void Function()? onSettled;
  void Function()? onReplayEnded;
  ThrowResolved? _replayResolved;
  List<ReplayTarget> _replayTargets = const [];
  bool _holdingRest = false;
  double _restHoldMs = 0;

  static const double _replayDtCapS = 1 / 30;
  static const double _restHoldAfterThrowMs = 500;

  double _fitZoom = 100;
  double cameraPunch = 0;

  MatchFixedDtWorld get _matchWorld => world as MatchFixedDtWorld;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await initializeForge2D();
    await super.onLoad();

    camera.viewfinder.anchor = Anchor.center;

    parlor = PresentationLayer();
    felt = FeltCircle();
    aimingMarker = AimingMarker(
      isShown: () => showAimingMarker && isPrivate,
      opponentWorldPos: () => opponentSaka.position,
      cameraZoom: () => camera.viewfinder.zoom,
    );
    bones = [
      for (final entry in bonesForDifficulty(difficulty).entries)
        BoneBody(boneId: entry.key, spawn: entry.value.clone()),
    ];
    final List<Component> bodies;
    if (isPrivate) {
      final bool localIsHost = localSeat == 'host';
      final Map<String, String> hostMap =
          hostLoadout.isNotEmpty ? hostLoadout : (localIsHost ? localLoadout : const <String, String>{});
      final Map<String, String> joinerMap =
          joinerLoadout.isNotEmpty ? joinerLoadout : (!localIsHost ? localLoadout : const <String, String>{});
      hostSaka = SakaBody(
        fill: fillForSku(
          hostMap['saka_color'],
          localIsHost ? _youFill : _oppFill,
        ),
        stripe: stripeForLoadout(
          hostMap,
          localIsHost ? _youStripe : _oppStripe,
        ),
        spawn: hostSpawn,
        id: 'saka-host',
      );
      joinerSaka = SakaBody(
        fill: fillForSku(
          joinerMap['saka_color'],
          localIsHost ? _oppFill : _youFill,
        ),
        stripe: stripeForLoadout(
          joinerMap,
          localIsHost ? _oppStripe : _youStripe,
        ),
        spawn: joinerSpawn,
        id: 'saka-joiner',
      );
      final Map<String, String> trailMap =
          localLoadout.isNotEmpty ? localLoadout : hostMap;
      trailTint = trailForLoadout(trailMap);
      felt.rimTint = tableFxForLoadout(trailMap);
      bodies = [felt, hostSaka, joinerSaka, ...bones];
    } else {
      _botSaka = SakaBody(
        fill: fillForSku(localLoadout['saka_color'], _youFill),
        stripe: stripeForLoadout(localLoadout, _youStripe),
      );
      trailTint = trailForLoadout(localLoadout);
      felt.rimTint = tableFxForLoadout(localLoadout);
      bodies = [felt, _botSaka!, ...bones];
    }
    await world.add(parlor);
    await parlor.addAll([
      ...bodies,
      ThrowJuice(
        isLive: () => throwing || replaying,
        saka: () => throwingSaka,
        bones: () => bones,
        trailColor: () => trailTint ?? const Color(0xFFF4E8C8),
        onImpact: () {
          cameraPunch = 1;
        },
      ),
      MatchAimArrow(game: this),
      aimingMarker,
      MatchTableDragLayer(game: this),
    ]);
    await camera.viewport.add(
      ThrowHandHud(
        aim: () => aim,
        visible: () =>
            showThrowHand && isLocalTurn && !showAimingMarker,
        chargeT: () => holdChargeT,
        flickT: () => throwFlickT,
        sakaFill: () => throwingSaka.paint.color,
        sakaCrease: () => throwingSaka.stripeColor,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (throwing || replaying) {
      throwFlickT = math.min(1.0, throwFlickT + dt / 0.26);
    }
    if (cameraPunch > 0.001) {
      cameraPunch *= math.exp(-dt * 7);
      _applyZoom();
    } else if (cameraPunch != 0) {
      cameraPunch = 0;
      _applyZoom();
    }
    if (replaying) {
      _advanceReplay(dt);
      return;
    }
    if (throwing && !tableSettled) {
      simTimeS += _matchWorld.stepsThisTick * PhysicsStepper.step;
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

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final minSide = size.x < size.y ? size.x : size.y;
    if (minSide > 0) {
      _fitZoom = minSide / (TableConstants.circleRadiusM * 2.6);
      _applyZoom();
    }
  }

  void _applyZoom() {
    camera.viewfinder.zoom = _fitZoom * (1 + 0.04 * cameraPunch);
  }

  void throwSaka(ThrowInput input) {
    if (!isLoaded) {
      return;
    }
    cancelReplay();
    throwing = true;
    tableSettled = false;
    simTimeS = 0;
    aimLocked = true;
    throwFlickT = 0.01;
    throwingSaka.applyThrowImpulse(input);
  }

  void applySakaPose({
    required String id,
    required double x,
    required double y,
    required double angle,
  }) {
    if (!isLoaded || !isPrivate) {
      return;
    }
    final SakaBody? target;
    if (id == 'saka-host' || id.endsWith('-host')) {
      target = hostSaka;
    } else if (id == 'saka-joiner' || id.endsWith('-joiner')) {
      target = joinerSaka;
    } else {
      target = null;
    }
    if (target == null) {
      return;
    }
    target.body.setTransform(Vector2(x, y), angle);
    target.body.linearVelocity.setZero();
    target.body.angularVelocity = 0;
  }

  /// Applies a playerThrow snapshot without recreating omitted pocketed bodies.
  void applyPlayerThrow(ThrowResolved resolved) {
    _queuePocketed(resolved);
    if (resolved.keyframes.isEmpty) {
      _finalizePocketed();
      return;
    }
    _replayTargets = _currentReplayTargets();
    KeyframePlayer.applyFrame(
      resolved.keyframes.last.tMs.toDouble(),
      resolved.keyframes,
      _replayTargets,
    );
    _finalizePocketed();
  }

  void startReplay(ThrowResolved resolved) {
    // Keep pocketed sohi visible through the replay — drop only after flight ends.
    _queuePocketed(resolved);
    _replayResolved = resolved;
    replayTimeMs = 0;
    _holdingRest = false;
    _restHoldMs = 0;
    replaying = true;
    throwing = false;
    tableSettled = true;
    aimLocked = true;
    throwFlickT = 0.01;
    _replayTargets = _currentReplayTargets();
    _freezePoses();
    KeyframePlayer.applyFrame(0, resolved.keyframes, _replayTargets);
  }

  void startTurn() => resetSakaToRim();

  void resetSakaToRim() {
    cancelReplay();
    _finalizePocketed();
    if (isPrivate) {
      hostSaka.snapToSpawn();
      joinerSaka.snapToSpawn();
    } else {
      _botSaka?.snapToSpawn();
    }
    throwing = false;
    tableSettled = true;
    aimLocked = false;
    simTimeS = 0;
    sakaOut = false;
    throwFlickT = 0;
    cameraPunch = 0;
    _applyZoom();
  }

  void _queuePocketed(ThrowResolved resolved) {
    _pendingPocketedIds.clear();
    _foulRestoreIds.clear();
    if (resolved.sakaOut) {
      // Foul: sohi leave in the replay then snap back for the next throw.
      _foulRestoreIds.addAll(resolved.pocketedIds);
    } else {
      _pendingPocketedIds.addAll(resolved.pocketedIds);
    }
  }

  void _finalizePocketed() {
    if (_pendingPocketedIds.isNotEmpty) {
      pocketedIds.addAll(_pendingPocketedIds);
      _pendingPocketedIds.clear();
      _dropPocketedBones();
    }
    _restoreFoulBones();
  }

  void _restoreFoulBones() {
    if (_foulRestoreIds.isEmpty) {
      return;
    }
    for (final BoneBody bone in bones) {
      if (_foulRestoreIds.contains(bone.boneId)) {
        bone.snapToSpawn();
      }
    }
    _foulRestoreIds.clear();
  }

  void cancelReplay() {
    replaying = false;
    _replayResolved = null;
    _replayTargets = const [];
    replayTimeMs = 0;
    _holdingRest = false;
    _restHoldMs = 0;
  }

  void _advanceReplay(double dt) {
    final ThrowResolved? resolved = _replayResolved;
    if (resolved == null || resolved.keyframes.isEmpty) {
      _finishReplay();
      return;
    }
    // One long frame after waiting on the API must not skip the whole throw.
    final double step = dt.clamp(0.0, _replayDtCapS);
    if (_holdingRest) {
      _restHoldMs += step * 1000;
      if (_restHoldMs >= _restHoldAfterThrowMs) {
        _finishReplay();
      }
      return;
    }
    replayTimeMs += step * 1000;
    KeyframePlayer.applyFrame(replayTimeMs, resolved.keyframes, _replayTargets);
    final lastMs = resolved.keyframes.last.tMs.toDouble();
    if (replayTimeMs >= lastMs) {
      KeyframePlayer.applyFrame(lastMs, resolved.keyframes, _replayTargets);
      _holdingRest = true;
      _restHoldMs = 0;
    }
  }

  void _finishReplay() {
    replaying = false;
    _replayResolved = null;
    _replayTargets = const [];
    aimLocked = true;
    startTurn();
    onReplayEnded?.call();
  }

  List<ReplayTarget> _currentReplayTargets() {
    return [
      if (isPrivate) ...[
        BodyReplayTarget(id: 'saka-host', body: hostSaka.body),
        BodyReplayTarget(id: 'saka-joiner', body: joinerSaka.body),
      ] else
        BodyReplayTarget(id: 'saka', body: saka.body),
      for (final bone in bones)
        if (bone.isMounted && !pocketedIds.contains(bone.boneId))
          BodyReplayTarget(id: bone.boneId, body: bone.body),
    ];
  }

  void _dropPocketedBones() {
    final List<BoneBody> gone = [
      for (final bone in bones)
        if (pocketedIds.contains(bone.boneId)) bone,
    ];
    for (final bone in gone) {
      bones.remove(bone);
      if (bone.isMounted) {
        bone.removeFromParent();
      }
    }
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
    final sakaPos = throwingSaka.body.worldCenter;
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
}

class MatchAimArrow extends PositionComponent {
  MatchAimArrow({required this.game}) : super(priority: 10);

  static const double lengthM = 0.42;

  final AlchikiMatchGame game;

  @override
  void render(Canvas canvas) {
    if (game.showAimingMarker || !game.isLocalTurn) {
      return;
    }
    if (!game.saka.isMounted) {
      return;
    }
    final from = game.saka.position;
    final dir = game.aim.aimDir;
    final to = from + dir * lengthM;
    final paint = Paint()
      ..color = game.trailTint ?? const Color(0xFFF4E8C8)
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

class MatchTableDragLayer extends PositionComponent with DragCallbacks {
  MatchTableDragLayer({required this.game})
    : super(
        size: Vector2.all(TableConstants.circleRadiusM * 3),
        anchor: Anchor.center,
        priority: 20,
      );

  final AlchikiMatchGame game;

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (game.aimLocked || !game.isLocalTurn) {
      return;
    }
    final local = event.localEndPosition;
    if (local.x.isNaN || local.y.isNaN) {
      return;
    }
    game.aim.updateFromWorldPoint(localToParent(local), game.saka.position);
  }
}
