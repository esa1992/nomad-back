import 'package:client/platform/api/nomad_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final rankedApiProvider = Provider<RankedApi>((Ref ref) {
  return RankedApi(ref.watch(nomadApiProvider));
});

/// MODE-04 Ranked enqueue/poll/cancel (D-97, D-98).
class RankedApi {
  RankedApi(this._api);

  final NomadApi _api;

  Future<CasualQueueStatus> enqueue({String game = 'ALCHIKI'}) {
    return _api.enqueueRanked(game: game);
  }

  Future<CasualQueueStatus> poll() {
    return _api.pollRanked();
  }

  Future<CasualQueueStatus> dequeue() {
    return _api.dequeueRanked();
  }
}
