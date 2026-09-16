import 'package:client/platform/api/nomad_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bindApiProvider = Provider<BindApi>((Ref ref) {
  return BindApi(ref.watch(nomadApiProvider));
});

/// AUTH-02/03/04 client: bind, login (D-93 adopt), logout mint.
class BindApi {
  BindApi(this._api);

  final NomadApi _api;

  Future<GuestSession> bind({
    required String username,
    required String password,
  }) {
    return _api.bind(username: username, password: password);
  }

  Future<GuestSession> login({
    required String username,
    required String password,
    String? guestPlayerId,
    String adopt = 'none',
    bool persist = true,
  }) {
    return _api.login(
      username: username,
      password: password,
      guestPlayerId: guestPlayerId,
      adopt: adopt,
      persist: persist,
    );
  }

  Future<GuestSession> logout() {
    return _api.logout();
  }
}
