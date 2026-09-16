import 'package:client/platform/api/nomad_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final boardsApiProvider = Provider<BoardsApi>((Ref ref) {
  return BoardsApi(ref.watch(nomadApiProvider));
});

/// LEAD boards read (D-105 / D-106).
class BoardsApi {
  BoardsApi(this._api);

  final NomadApi _api;

  Future<BoardsSnapshot> fetch({
    required String game,
    required String scope,
  }) {
    return _api.fetchBoards(game: game, scope: scope);
  }
}
