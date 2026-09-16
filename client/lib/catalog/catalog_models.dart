import 'package:flutter_riverpod/flutter_riverpod.dart';

enum Difficulty {
  easy,
  normal,
  hard;

  String get query => name.toUpperCase();
}

/// Last Alchiki catalog difficulty chip — reused by empty-queue Play vs bot.
final lastBotDifficultyProvider =
    NotifierProvider<LastBotDifficulty, String>(LastBotDifficulty.new);

class LastBotDifficulty extends Notifier<String> {
  @override
  String build() => 'EASY';

  void setDifficulty(String query) {
    state = query;
  }
}

/// Stick Pull bot chip memory — must not clobber Alchiki lastBotDifficulty (D-79).
final lastStickPullBotDifficultyProvider =
    NotifierProvider<LastStickPullBotDifficulty, String>(
      LastStickPullBotDifficulty.new,
    );

class LastStickPullBotDifficulty extends Notifier<String> {
  @override
  String build() => 'EASY';

  void setDifficulty(String query) {
    state = query;
  }
}

enum CatalogAvailability { playable, comingSoon }

class CatalogTile {
  const CatalogTile({required this.id, required this.availability});

  final String id;
  final CatalogAvailability availability;
}

class CatalogSnapshot {
  const CatalogSnapshot({required this.tiles});

  final List<CatalogTile> tiles;

  static const local = CatalogSnapshot(
    tiles: [
      CatalogTile(id: 'alchiki', availability: CatalogAvailability.playable),
      CatalogTile(
        id: 'stick_pull',
        availability: CatalogAvailability.playable,
      ),
      CatalogTile(
        id: 'more_games',
        availability: CatalogAvailability.comingSoon,
      ),
    ],
  );
}
