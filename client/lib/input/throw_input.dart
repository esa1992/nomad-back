import 'dart:convert';

import 'package:client/schema/table_constants.dart';

/// Shared throw DTO. Clamp holdMs, reject non-finite aim, schemaVersion 1 (D-05, D-09).
class ThrowInput {
  static const int schemaVersionRequired = 1;

  final int schemaVersion;
  final bool yUp;
  final double aimAngleRad;
  final int holdMs;
  final int seed;
  final String tableId;

  const ThrowInput({
    required this.schemaVersion,
    required this.yUp,
    required this.aimAngleRad,
    required this.holdMs,
    required this.seed,
    required this.tableId,
  });

  factory ThrowInput.parse(Map<String, Object?> json) {
    final schemaVersion = (json['schemaVersion'] as num?)?.toInt();
    if (schemaVersion != schemaVersionRequired) {
      throw FormatException(
        'schemaVersion must be $schemaVersionRequired, got $schemaVersion',
      );
    }

    final yUp = json['yUp'];
    if (yUp != true) {
      throw const FormatException('yUp must be true');
    }

    final aimAngleRad = (json['aimAngleRad'] as num?)?.toDouble();
    if (aimAngleRad == null || !aimAngleRad.isFinite) {
      throw FormatException('aimAngleRad must be finite, got $aimAngleRad');
    }

    final rawHold = (json['holdMs'] as num?)?.toInt() ?? 0;
    final holdMs = rawHold.clamp(TableConstants.holdMsMin, TableConstants.holdMsMax);

    return ThrowInput(
      schemaVersion: schemaVersion!,
      yUp: true,
      aimAngleRad: aimAngleRad,
      holdMs: holdMs,
      seed: (json['seed'] as num?)?.toInt() ?? 0,
      tableId: json['tableId'] as String? ?? '',
    );
  }

  factory ThrowInput.parseJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('ThrowInput JSON must be an object');
    }
    return ThrowInput.parse(Map<String, Object?>.from(decoded));
  }

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'yUp': yUp,
        'aimAngleRad': aimAngleRad,
        'holdMs': holdMs,
        'seed': seed,
        'tableId': tableId,
      };

  String toJsonString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) {
    return other is ThrowInput &&
        other.schemaVersion == schemaVersion &&
        other.yUp == yUp &&
        other.aimAngleRad == aimAngleRad &&
        other.holdMs == holdMs &&
        other.seed == seed &&
        other.tableId == tableId;
  }

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    yUp,
    aimAngleRad,
    holdMs,
    seed,
    tableId,
  );

  static double impulseFromHoldMs(int holdMs) {
    final clamped = holdMs.clamp(
      TableConstants.holdMsMin,
      TableConstants.holdMsMax,
    );
    final t =
        (clamped - TableConstants.holdMsMin) /
        (TableConstants.holdMsMax - TableConstants.holdMsMin);
    return TableConstants.impulseMinNs +
        t * (TableConstants.impulseMaxNs - TableConstants.impulseMinNs);
  }
}
