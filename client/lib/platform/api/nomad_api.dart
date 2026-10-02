import 'dart:io' show Platform;

import 'package:client/catalog/catalog_models.dart';
import 'package:client/input/throw_input.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:client/replay/throw_resolved.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final nomadApiProvider = Provider<NomadApi>((ref) {
  return NomadApi(sessionStore: ref.watch(sessionStoreProvider));
});

class NomadApiException implements Exception {
  NomadApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class MatchStart {
  const MatchStart({
    required this.matchId,
    required this.difficulty,
    required this.boneIds,
    required this.turn,
    this.playerScore = 0,
    this.botScore = 0,
    this.status = 'IN_PLAY',
    this.playerTurns = 0,
    this.botTurns = 0,
    this.turnDeadlineEpochMs = 0,
    this.matchDeadlineEpochMs = 0,
    this.hardCapEpochMs = 0,
    this.mode,
    this.hostId,
    this.joinerId,
    this.hostLabel,
    this.joinerLabel,
    this.reconnectSecondsLeft,
    this.pauseBudgetGone = false,
    this.coinsGranted = 0,
    this.gemsGranted = 0,
    this.localLoadout = const <String, String>{},
    this.hostLoadout = const <String, String>{},
    this.joinerLoadout = const <String, String>{},
  });

  final String matchId;
  final String difficulty;
  final List<String> boneIds;
  final String turn;
  final int playerScore;
  final int botScore;
  final String status;
  final int playerTurns;
  final int botTurns;
  final int turnDeadlineEpochMs;
  final int matchDeadlineEpochMs;
  final int hardCapEpochMs;
  final String? mode;
  final String? hostId;
  final String? joinerId;
  final String? hostLabel;
  final String? joinerLabel;
  final int? reconnectSecondsLeft;
  final bool pauseBudgetGone;
  final int coinsGranted;
  final int gemsGranted;
  final Map<String, String> localLoadout;
  final Map<String, String> hostLoadout;
  final Map<String, String> joinerLoadout;
}

class WsTicket {
  const WsTicket({required this.ticket, this.expiresAt, this.reconnectToken});

  final String ticket;
  final DateTime? expiresAt;
  final String? reconnectToken;
}

class SakaPose {
  const SakaPose({
    required this.id,
    required this.x,
    required this.y,
    required this.angle,
  });

  final String id;
  final double x;
  final double y;
  final double angle;
}

class RejoinResult {
  const RejoinResult({
    required this.match,
    required this.reconnectToken,
    this.playerThrow,
    this.sakaPoses = const <SakaPose>[],
  });

  final MatchStart match;
  final String reconnectToken;
  final ThrowResolved? playerThrow;
  final List<SakaPose> sakaPoses;
}

class RematchAccept {
  const RematchAccept({
    required this.accepted,
    this.matchId,
    this.rematchSeconds = 10,
    this.turn,
  });

  final bool accepted;
  final String? matchId;
  final int rematchSeconds;
  final String? turn;
}

class RematchPoll {
  const RematchPoll({
    required this.acceptedHost,
    required this.acceptedJoiner,
    required this.rematchSeconds,
    this.matchId,
    this.expired = false,
  });

  final bool acceptedHost;
  final bool acceptedJoiner;
  final int rematchSeconds;
  final String? matchId;
  final bool expired;
}

class ThrowSubmitResult {
  const ThrowSubmitResult({
    required this.playerThrow,
    required this.playerScore,
    required this.botScore,
    required this.turn,
    required this.bonesLeft,
    this.botThrow,
    this.status = 'IN_PLAY',
    this.playerTurns = 0,
    this.botTurns = 0,
    this.turnDeadlineEpochMs = 0,
    this.matchDeadlineEpochMs = 0,
    this.hardCapEpochMs = 0,
  });

  final ThrowResolved playerThrow;
  final ThrowResolved? botThrow;
  final int playerScore;
  final int botScore;
  final String turn;
  final List<String> bonesLeft;
  final String status;
  final int playerTurns;
  final int botTurns;
  final int turnDeadlineEpochMs;
  final int matchDeadlineEpochMs;
  final int hardCapEpochMs;
}

class RoomCreated {
  const RoomCreated({
    required this.roomId,
    required this.code,
    required this.hostLabel,
    required this.idleExpiresAt,
  });

  final String roomId;
  final String code;
  final String hostLabel;
  final DateTime idleExpiresAt;
}

class RoomLobby {
  const RoomLobby({
    required this.roomId,
    this.code,
    required this.hostLabel,
    this.joinerLabel,
    this.hostReady = false,
    this.joinerReady = false,
    this.bothReady = false,
    required this.status,
    required this.idleExpiresAt,
    this.matchId,
    this.game,
  });

  final String roomId;
  final String? code;
  final String hostLabel;
  final String? joinerLabel;
  final bool hostReady;
  final bool joinerReady;
  final bool bothReady;
  final String status;
  final DateTime idleExpiresAt;
  final String? matchId;
  final String? game;
}

class GuestSession {
  const GuestSession({
    required this.playerId,
    required this.accessToken,
    required this.refreshToken,
    required this.guest,
    this.adoptHint,
  });

  final String playerId;
  final String accessToken;
  final String refreshToken;
  final bool guest;

  /// D-93 server hint: IMPORT_ELIGIBLE | DROP_REQUIRED when guestPlayerId was sent.
  final String? adoptHint;

  bool get importEligible => adoptHint == 'IMPORT_ELIGIBLE';

  bool get dropRequired => adoptHint == 'DROP_REQUIRED';
}

/// Server wallet projection from GET /v1/wallet (display-only; not purchase authority).
class WalletBalance {
  const WalletBalance({required this.coins, required this.gems});

  final int coins;
  final int gems;
}

/// Flat shop catalog from GET /v1/shop/catalog (client groups by slot).
class ShopCatalog {
  const ShopCatalog({required this.skus});

  final List<ShopSku> skus;
}

class ShopSku {
  const ShopSku({
    required this.id,
    required this.slot,
    required this.nameKey,
    required this.priceCoins,
    required this.priceGems,
    required this.owned,
    required this.equipped,
    required this.free,
  });

  final String id;
  final String slot;
  final String nameKey;
  final int priceCoins;
  final int priceGems;
  final bool owned;
  final bool equipped;
  final bool free;
}

/// Soft purchase outcome from POST /v1/shop/purchases.
class PurchaseResult {
  const PurchaseResult({
    required this.skuId,
    required this.owned,
    required this.coins,
    required this.gems,
  });

  final String skuId;
  final bool owned;
  final int coins;
  final int gems;
}

/// Projection from POST/GET/DELETE /v1/matchmaking/casual.
class CasualQueueStatus {
  const CasualQueueStatus({
    required this.status,
    this.matchId,
    this.mode,
    this.ticketId,
    this.game,
  });

  /// IDLE | SEARCHING | MATCHED
  final String status;
  final String? matchId;
  final String? mode;
  final String? ticketId;
  final String? game;

  bool get isMatched =>
      status == 'MATCHED' && matchId != null && matchId!.isNotEmpty;
}

/// Self profile from GET /v1/profile (display-only XP/MMR — T-05-02).
class PlayerProfile {
  const PlayerProfile({
    required this.displayName,
    required this.subtitle,
    required this.avatarPreset,
    required this.level,
    required this.xp,
    required this.xpToNext,
    required this.matches,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.rating,
    required this.bestRating,
    required this.cosmetics,
    required this.games,
  });

  final String displayName;
  final String subtitle;
  final String avatarPreset;
  final int level;
  final int xp;
  final int xpToNext;
  final int matches;
  final int wins;
  final int losses;
  final double winRate;
  final int rating;
  final int bestRating;
  final Map<String, String> cosmetics;
  final Map<String, GameStats> games;
}

/// GET /v1/boards skill board payload (LEAD-01…03).
class BoardsSnapshot {
  const BoardsSnapshot({
    required this.game,
    required this.scope,
    required this.entries,
  });

  final String game;
  final String scope;
  final List<BoardEntry> entries;
}

class BoardEntry {
  const BoardEntry({
    required this.rank,
    required this.playerId,
    required this.username,
    required this.rating,
    this.guest = false,
  });

  final int rank;
  final String playerId;
  final String username;
  final int rating;
  final bool guest;
}

class GameStats {
  const GameStats({
    required this.matches,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.noMatchesYet,
  });

  final int matches;
  final int wins;
  final int losses;
  final int draws;
  final bool noMatchesYet;
}

class NomadApi {
  NomadApi({
    required this.sessionStore,
    Dio? dio,
    Dio? refreshDio,
    String? baseUrl,
  }) : baseUrl = baseUrl ?? resolveBaseUrl(),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl ?? resolveBaseUrl(),
               contentType: Headers.jsonContentType,
             ),
           ),
       _refreshDio =
           refreshDio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl ?? resolveBaseUrl(),
               contentType: Headers.jsonContentType,
             ),
           ) {
    if (dio == null) {
      _installAuthInterceptor();
    }
  }

  static String resolveBaseUrl() {
    const String defined = String.fromEnvironment('NOMAD_API_URL');
    if (defined.isNotEmpty) {
      return defined;
    }
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://127.0.0.1:8080';
  }

  final SessionStore sessionStore;
  final String baseUrl;
  final Dio _dio;
  final Dio _refreshDio;

  String? accessToken;

  void _installAuthInterceptor() {
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          final String? token = accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          if (error.response?.statusCode != 401) {
            handler.next(error);
            return;
          }
          try {
            await refresh();
            final RequestOptions retry = error.requestOptions;
            retry.headers['Authorization'] = 'Bearer $accessToken';
            final Dio naked = Dio(
              BaseOptions(
                baseUrl: baseUrl,
                contentType: Headers.jsonContentType,
              ),
            );
            handler.resolve(await naked.fetch<dynamic>(retry));
          } catch (_) {
            accessToken = null;
            await sessionStore.clear();
            handler.next(error);
          }
        },
      ),
    );
  }

  Future<GuestSession> mintGuest() async {
    try {
      final Response<dynamic> response = await _refreshDio.post<dynamic>(
        '/v1/identity/guest',
        data: <String, Object>{},
      );
      final GuestSession session = _parseSession(response.data);
      accessToken = session.accessToken;
      await sessionStore.persist(
        playerId: session.playerId,
        refreshToken: session.refreshToken,
      );
      await sessionStore.persistGuest(session.guest);
      return session;
    } on DioException catch (error) {
      throw NomadApiException(
        'Guest mint failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  /// AUTH-02: bind username+password to current guest JWT (same playerId).
  Future<GuestSession> bind({
    required String username,
    required String password,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/v1/identity/bind',
        data: <String, String>{
          'username': username,
          'password': password,
        },
      );
      final GuestSession session = _parseSession(response.data);
      accessToken = session.accessToken;
      await sessionStore.persist(
        playerId: session.playerId,
        refreshToken: session.refreshToken,
      );
      await sessionStore.persistGuest(session.guest);
      return session;
    } on DioException catch (error) {
      throw NomadApiException(
        'Bind failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  /// AUTH-03: permitAll login with D-93 adopt=none|import|drop.
  /// When [guestPlayerId] is set, sends guest Bearer access and refresh as possession proof (CR-01).
  /// When [persist] is false, tokens are not written (probe before replaceGuest confirm).
  Future<GuestSession> login({
    required String username,
    required String password,
    String? guestPlayerId,
    String adopt = 'none',
    bool persist = true,
  }) async {
    try {
      final Map<String, Object?> body = <String, Object?>{
        'username': username,
        'password': password,
        'adopt': adopt,
      };
      final Map<String, String> headers = <String, String>{};
      if (guestPlayerId != null && guestPlayerId.isNotEmpty) {
        body['guestPlayerId'] = guestPlayerId;
        final String? guestAccess = accessToken;
        if (guestAccess != null && guestAccess.isNotEmpty) {
          headers['Authorization'] = 'Bearer $guestAccess';
        }
        final String? guestRefresh = await sessionStore.refreshToken();
        if (guestRefresh != null && guestRefresh.isNotEmpty) {
          body['guestRefreshToken'] = guestRefresh;
        }
      }
      final Response<dynamic> response = await _refreshDio.post<dynamic>(
        '/v1/identity/login',
        data: body,
        options: headers.isEmpty ? null : Options(headers: headers),
      );
      final GuestSession session = _parseSession(response.data);
      if (persist) {
        accessToken = session.accessToken;
        await sessionStore.persist(
          playerId: session.playerId,
          refreshToken: session.refreshToken,
        );
        await sessionStore.persistGuest(session.guest);
        await sessionStore.clearReconnect();
      }
      return session;
    } on DioException catch (error) {
      throw NomadApiException(
        'Sign in failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  /// AUTH-04: revoke refresh and mint guest; persist guest session (D-95).
  Future<GuestSession> logout() async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/v1/identity/logout',
        data: <String, Object>{},
      );
      final GuestSession session = _parseSession(response.data);
      accessToken = session.accessToken;
      await sessionStore.persist(
        playerId: session.playerId,
        refreshToken: session.refreshToken,
      );
      await sessionStore.persistGuest(session.guest);
      await sessionStore.clearReconnect();
      return session;
    } on DioException catch (error) {
      throw NomadApiException(
        'Log out failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<GuestSession> refresh() async {
    final String? token = await sessionStore.refreshToken();
    if (token == null || token.isEmpty) {
      throw NomadApiException('No refresh token', statusCode: 401);
    }
    try {
      final Response<dynamic> response = await _refreshDio.post<dynamic>(
        '/v1/identity/refresh',
        data: <String, String>{'refreshToken': token},
      );
      final Map<String, dynamic> body = _asMap(response.data);
      final String access = body['accessToken'] as String;
      final String nextRefresh = body['refreshToken'] as String;
      final bool guest = body['guest'] == true;
      accessToken = access;
      final String playerId =
          body['playerId']?.toString() ??
          await sessionStore.playerId() ??
          '';
      await sessionStore.persist(playerId: playerId, refreshToken: nextRefresh);
      await sessionStore.persistGuest(guest);
      return GuestSession(
        playerId: playerId,
        accessToken: access,
        refreshToken: nextRefresh,
        guest: guest,
      );
    } on DioException catch (error) {
      accessToken = null;
      await sessionStore.clear();
      throw NomadApiException(
        'Refresh failed',
        statusCode: error.response?.statusCode ?? 401,
      );
    }
  }

  Future<MatchStart> startMatch({
    String difficulty = 'EASY',
    String game = 'ALCHIKI',
  }) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/v1/matches',
        data: <String, String>{
          'game': game,
          'mode': 'BOT',
          'difficulty': difficulty,
        },
      );
      return _parseMatchStart(response.data);
    } on DioException catch (error) {
      throw NomadApiException(
        'Match start failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<ThrowSubmitResult> submitThrow(
    String matchId,
    ThrowInput? input,
  ) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/v1/matches/$matchId/throws',
        data: input?.toJson() ?? <String, Object>{},
      );
      return _parseThrowSubmit(response.data, input);
    } on DioException catch (error) {
      throw NomadApiException(
        'Throw submit failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  /// Bot half, after the player throw is already in flight on screen.
  Future<ThrowSubmitResult> continueBot(String matchId) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/v1/matches/$matchId/bot-turn',
      );
      return _parseThrowSubmit(response.data, null);
    } on DioException catch (error) {
      throw NomadApiException(
        'Bot turn failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<MatchStart> getMatch(String matchId) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/v1/matches/$matchId',
      );
      return _parseMatchSnapshot(matchId, response.data);
    } on DioException catch (error) {
      throw NomadApiException(
        'Match get failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<WsTicket> wsTicket(String matchId) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/v1/matches/$matchId/ws-ticket',
        data: <String, Object>{},
      );
      final Map<String, dynamic> body = _asMap(response.data);
      final String? expiresRaw = body['expiresAt'] as String?;
      return WsTicket(
        ticket: body['ticket'] as String,
        expiresAt: expiresRaw == null ? null : DateTime.tryParse(expiresRaw),
        reconnectToken: body['reconnectToken'] as String?,
      );
    } on DioException catch (error) {
      throw NomadApiException(
        'WS ticket failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<RematchAccept> rematch(String matchId, {bool accept = true}) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/v1/matches/$matchId/rematch',
        data: <String, bool>{'accept': accept},
      );
      final Map<String, dynamic> body = _asMap(response.data);
      return RematchAccept(
        accepted: body['accepted'] == true,
        matchId: body['matchId']?.toString(),
        rematchSeconds: (body['rematchSeconds'] as num?)?.toInt() ?? 10,
        turn: body['turn'] as String?,
      );
    } on DioException catch (error) {
      throw NomadApiException(
        'Rematch failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<RematchPoll> getRematch(String matchId) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/v1/matches/$matchId/rematch',
      );
      final Map<String, dynamic> body = _asMap(response.data);
      return RematchPoll(
        acceptedHost: body['acceptedHost'] == true,
        acceptedJoiner: body['acceptedJoiner'] == true,
        rematchSeconds: (body['rematchSeconds'] as num?)?.toInt() ?? 0,
        matchId: body['matchId']?.toString(),
        expired: body['expired'] == true,
      );
    } on DioException catch (error) {
      throw NomadApiException(
        'Rematch poll failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<RejoinResult> rejoin(String matchId, String token) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/v1/matches/$matchId/rejoin',
        data: <String, String>{'token': token},
      );
      final Map<String, dynamic> body = _asMap(response.data);
      ThrowResolved? playerThrow;
      if (body['playerThrow'] is Map) {
        try {
          final Map<String, dynamic> throwMap = _asMap(body['playerThrow']);
          throwMap.putIfAbsent('schemaVersion', () => 1);
          throwMap.putIfAbsent('yUp', () => true);
          playerThrow = ThrowResolved.parseMap(
            Map<String, Object?>.from(throwMap),
          );
        } catch (_) {
          playerThrow = null;
        }
      }
      final List<SakaPose> poses = <SakaPose>[];
      final Object? rawPoses = body['sakaPoses'];
      if (rawPoses is List) {
        for (final Object? item in rawPoses) {
          if (item is Map) {
            final Map<String, dynamic> pose = _asMap(item);
            poses.add(
              SakaPose(
                id: pose['id']?.toString() ?? '',
                x: (pose['x'] as num?)?.toDouble() ?? 0,
                y: (pose['y'] as num?)?.toDouble() ?? 0,
                angle: (pose['angle'] as num?)?.toDouble() ?? 0,
              ),
            );
          }
        }
      }
      return RejoinResult(
        match: _parseMatchSnapshot(matchId, body['match'] ?? body),
        reconnectToken: body['reconnectToken'] as String? ?? '',
        playerThrow: playerThrow,
        sakaPoses: poses,
      );
    } on DioException catch (error) {
      throw NomadApiException(
        'Rejoin failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Uri wsUrlForMatch({required String matchId, required String ticket}) {
    final Uri http = Uri.parse(baseUrl);
    final String scheme = http.scheme == 'https' ? 'wss' : 'ws';
    return http.replace(
      scheme: scheme,
      path: '/v1/matches/$matchId/ws',
      queryParameters: <String, String>{'ticket': ticket},
    );
  }

  Future<MatchStart> leaveMatch(String matchId) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/v1/matches/$matchId/leave',
      );
      final Map<String, dynamic> body = _asMap(response.data);
      final Map<String, dynamic> match = body['match'] is Map
          ? _asMap(body['match'])
          : body;
      if (match['status'] == null) {
        match['status'] = 'BOT_WIN';
      }
      return _matchFromMap(
        matchId: matchId,
        body: match,
        boneIdsKey: 'bonesLeft',
      );
    } on DioException catch (error) {
      throw NomadApiException(
        'Leave match failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<RoomCreated> createRoom({String game = 'ALCHIKI'}) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/v1/rooms',
        data: <String, String>{'game': game},
      );
      return _parseRoomCreated(response.data);
    } on DioException catch (error) {
      throw NomadApiException(
        'Room create failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<RoomLobby> joinRoom({required String code}) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/v1/rooms/join',
        data: <String, String>{'code': code},
      );
      return _parseRoomLobby(response.data);
    } on DioException catch (error) {
      throw NomadApiException(
        'Room join failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<RoomLobby> getRoom(String id) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>('/v1/rooms/$id');
      return _parseRoomLobby(response.data);
    } on DioException catch (error) {
      throw NomadApiException(
        'Room get failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<RoomLobby> readyRoom(String id) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/v1/rooms/$id/ready',
        data: <String, Object>{},
      );
      return _parseRoomLobby(response.data);
    } on DioException catch (error) {
      throw NomadApiException(
        'Room ready failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<RoomLobby> leaveRoom(String id) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/v1/rooms/$id/leave',
        data: <String, Object>{},
      );
      return _parseRoomLobby(response.data);
    } on DioException catch (error) {
      throw NomadApiException(
        'Room leave failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<CatalogSnapshot> fetchCatalog() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>('/v1/catalog');
      return _parseCatalog(response.data);
    } on DioException catch (error) {
      throw NomadApiException(
        'Catalog failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<WalletBalance> fetchWallet() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>('/v1/wallet');
      final Map<String, dynamic> body = _asMap(response.data);
      return WalletBalance(
        coins: (body['coins'] as num?)?.toInt() ?? 0,
        gems: (body['gems'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (error) {
      throw NomadApiException(
        'Wallet failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<ShopCatalog> fetchShopCatalog() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/v1/shop/catalog',
      );
      return _parseShopCatalog(response.data);
    } on DioException catch (error) {
      throw NomadApiException(
        'Shop failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  /// Soft-currency buy. Caller supplies idempotencyKey (Random.secure hex); no uuid package.
  Future<PurchaseResult> purchaseSku({
    required String skuId,
    required String idempotencyKey,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/v1/shop/purchases',
        data: <String, Object>{
          'skuId': skuId,
          'idempotencyKey': idempotencyKey,
        },
      );
      final Map<String, dynamic> body = _asMap(response.data);
      return PurchaseResult(
        skuId: body['skuId']?.toString() ?? skuId,
        owned: body['owned'] == true,
        coins: (body['coins'] as num?)?.toInt() ?? 0,
        gems: (body['gems'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (error) {
      final int? code = error.response?.statusCode;
      final String detail = _errorDetail(error);
      throw NomadApiException(
        detail.isNotEmpty ? detail : 'Purchase failed',
        statusCode: code,
      );
    }
  }

  /// Equip owned SKU into loadout slot (D-55). Applies on next match start only (D-56).
  Future<void> equipSku({required String slot, required String skuId}) async {
    try {
      await _dio.post<dynamic>(
        '/v1/shop/equip',
        data: <String, Object>{
          'slot': slot,
          'skuId': skuId,
        },
      );
    } on DioException catch (error) {
      final int? code = error.response?.statusCode;
      final String detail = _errorDetail(error);
      throw NomadApiException(
        detail.isNotEmpty ? detail : 'Equip failed',
        statusCode: code,
      );
    }
  }

  Future<CasualQueueStatus> enqueueCasual({String game = 'ALCHIKI'}) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/v1/matchmaking/casual',
        data: <String, String>{'game': game},
      );
      return _parseCasualQueue(response.data);
    } on DioException catch (error) {
      throw NomadApiException(
        'Casual enqueue failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<CasualQueueStatus> pollCasual() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/v1/matchmaking/casual',
      );
      return _parseCasualQueue(response.data);
    } on DioException catch (error) {
      throw NomadApiException(
        'Casual poll failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<CasualQueueStatus> dequeueCasual() async {
    try {
      final Response<dynamic> response = await _dio.delete<dynamic>(
        '/v1/matchmaking/casual',
      );
      return _parseCasualQueue(response.data);
    } on DioException catch (error) {
      throw NomadApiException(
        'Casual dequeue failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<CasualQueueStatus> enqueueRanked({String game = 'ALCHIKI'}) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/v1/matchmaking/ranked',
        data: <String, String>{'game': game},
      );
      return _parseCasualQueue(response.data);
    } on DioException catch (error) {
      throw NomadApiException(
        'Ranked enqueue failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<CasualQueueStatus> pollRanked() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/v1/matchmaking/ranked',
      );
      return _parseCasualQueue(response.data);
    } on DioException catch (error) {
      throw NomadApiException(
        'Ranked poll failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<CasualQueueStatus> dequeueRanked() async {
    try {
      final Response<dynamic> response = await _dio.delete<dynamic>(
        '/v1/matchmaking/ranked',
      );
      return _parseCasualQueue(response.data);
    } on DioException catch (error) {
      throw NomadApiException(
        'Ranked dequeue failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<PlayerProfile> fetchProfile() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>('/v1/profile');
      return _parseProfile(response.data);
    } on DioException catch (error) {
      throw NomadApiException(
        'Profile failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  /// LEAD-01…03 skill boards (bound JWT; never coin-ordered).
  Future<BoardsSnapshot> fetchBoards({
    required String game,
    required String scope,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/v1/boards',
        queryParameters: <String, String>{'game': game, 'scope': scope},
      );
      return _parseBoards(response.data);
    } on DioException catch (error) {
      throw NomadApiException(
        'Boards failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  BoardsSnapshot _parseBoards(dynamic data) {
    final Map<String, dynamic> body = _asMap(data);
    final List<dynamic> raw = body['entries'] is List
        ? body['entries'] as List<dynamic>
        : const <dynamic>[];
    final List<BoardEntry> entries = <BoardEntry>[];
    for (final dynamic item in raw) {
      final Map<String, dynamic> row = _asMap(item);
      entries.add(
        BoardEntry(
          rank: (row['rank'] as num?)?.toInt() ?? 0,
          playerId: row['playerId']?.toString() ?? '',
          username: row['username']?.toString() ?? '',
          rating: (row['rating'] as num?)?.toInt() ?? 0,
          guest: row['guest'] == true,
        ),
      );
    }
    return BoardsSnapshot(
      game: body['game']?.toString() ?? '',
      scope: body['scope']?.toString() ?? '',
      entries: entries,
    );
  }

  /// Allow-listed preset only; server re-validates (T-05-03).
  Future<PlayerProfile> putAvatar(String avatarPreset) async {
    try {
      final Response<dynamic> response = await _dio.put<dynamic>(
        '/v1/profile/avatar',
        data: <String, Object>{'avatarPreset': avatarPreset},
      );
      return _parseProfile(response.data);
    } on DioException catch (error) {
      throw NomadApiException(
        'Avatar save failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  PlayerProfile _parseProfile(dynamic data) {
    final Map<String, dynamic> body = _asMap(data);
    final Map<String, dynamic> cosmeticsRaw = body['cosmetics'] is Map
        ? _asMap(body['cosmetics'])
        : <String, dynamic>{};
    final Map<String, String> cosmetics = cosmeticsRaw.map(
      (String k, dynamic v) => MapEntry(k, v?.toString() ?? ''),
    );
    final Map<String, dynamic> gamesRaw = body['games'] is Map
        ? _asMap(body['games'])
        : <String, dynamic>{};
    final Map<String, GameStats> games = <String, GameStats>{};
    for (final MapEntry<String, dynamic> entry in gamesRaw.entries) {
      final Map<String, dynamic> row = _asMap(entry.value);
      games[entry.key] = GameStats(
        matches: (row['matches'] as num?)?.toInt() ?? 0,
        wins: (row['wins'] as num?)?.toInt() ?? 0,
        losses: (row['losses'] as num?)?.toInt() ?? 0,
        draws: (row['draws'] as num?)?.toInt() ?? 0,
        noMatchesYet: row['noMatchesYet'] == true,
      );
    }
    return PlayerProfile(
      displayName: body['displayName']?.toString() ?? 'Guest',
      subtitle: body['subtitle']?.toString() ?? '',
      avatarPreset: body['avatarPreset']?.toString() ?? 'avatar_01',
      level: (body['level'] as num?)?.toInt() ?? 1,
      xp: (body['xp'] as num?)?.toInt() ?? 0,
      xpToNext: (body['xpToNext'] as num?)?.toInt() ?? 100,
      matches: (body['matches'] as num?)?.toInt() ?? 0,
      wins: (body['wins'] as num?)?.toInt() ?? 0,
      losses: (body['losses'] as num?)?.toInt() ?? 0,
      winRate: (body['winRate'] as num?)?.toDouble() ?? 0,
      rating: (body['rating'] as num?)?.toInt() ?? 1000,
      bestRating: (body['bestRating'] as num?)?.toInt() ?? 1000,
      cosmetics: cosmetics,
      games: games,
    );
  }

  CasualQueueStatus _parseCasualQueue(dynamic data) {
    final Map<String, dynamic> body = _asMap(data);
    return CasualQueueStatus(
      status: body['status']?.toString() ?? 'IDLE',
      matchId: body['matchId']?.toString(),
      mode: body['mode']?.toString(),
      ticketId: body['ticketId']?.toString(),
      game: body['game'] as String?,
    );
  }

  static String _errorDetail(DioException error) {
    final Object? data = error.response?.data;
    if (data is Map) {
      final Object? detail = data['detail'] ?? data['message'] ?? data['error'];
      if (detail != null) {
        return detail.toString();
      }
    }
    return error.message ?? '';
  }

  ShopCatalog _parseShopCatalog(dynamic data) {
    final Map<String, dynamic> body = _asMap(data);
    final List<dynamic> raw = body['skus'] as List<dynamic>? ?? const <dynamic>[];
    final List<ShopSku> skus = raw.map((dynamic item) {
      final Map<String, dynamic> row = _asMap(item);
      return ShopSku(
        id: row['id']?.toString() ?? '',
        slot: row['slot']?.toString() ?? '',
        nameKey: row['nameKey']?.toString() ?? '',
        priceCoins: (row['priceCoins'] as num?)?.toInt() ?? 0,
        priceGems: (row['priceGems'] as num?)?.toInt() ?? 0,
        owned: row['owned'] == true,
        equipped: row['equipped'] == true,
        free: row['free'] == true,
      );
    }).toList();
    return ShopCatalog(skus: skus);
  }

  GuestSession _parseSession(dynamic data) {
    final Map<String, dynamic> body = _asMap(data);
    final Object? hint = body['adoptHint'];
    return GuestSession(
      playerId: body['playerId'] as String,
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
      guest: body['guest'] == true,
      adoptHint: hint?.toString(),
    );
  }

  MatchStart snapshotFromMap(String matchId, dynamic data) {
    return _parseMatchSnapshot(matchId, data);
  }

  MatchStart _parseMatchStart(dynamic data) {
    final Map<String, dynamic> body = _asMap(data);
    return _matchFromMap(
      matchId: body['matchId']?.toString() ?? '',
      body: body,
      boneIdsKey: 'boneIds',
    );
  }

  MatchStart _parseMatchSnapshot(String matchId, dynamic data) {
    final Map<String, dynamic> body = _asMap(data);
    return _matchFromMap(
      matchId: matchId,
      body: body,
      boneIdsKey: 'bonesLeft',
    );
  }

  MatchStart _matchFromMap({
    required String matchId,
    required Map<String, dynamic> body,
    required String boneIdsKey,
  }) {
    return MatchStart(
      matchId: matchId,
      difficulty: body['difficulty'] as String? ?? 'EASY',
      boneIds: _stringList(body[boneIdsKey] ?? body['boneIds']),
      turn: body['turn'] as String? ?? 'PLAYER',
      playerScore: (body['playerScore'] as num?)?.toInt() ?? 0,
      botScore: (body['botScore'] as num?)?.toInt() ?? 0,
      status: body['status'] as String? ?? 'IN_PLAY',
      playerTurns: (body['playerTurns'] as num?)?.toInt() ?? 0,
      botTurns: (body['botTurns'] as num?)?.toInt() ?? 0,
      turnDeadlineEpochMs: (body['turnDeadlineEpochMs'] as num?)?.toInt() ?? 0,
      matchDeadlineEpochMs: (body['matchDeadlineEpochMs'] as num?)?.toInt() ?? 0,
      hardCapEpochMs: (body['hardCapEpochMs'] as num?)?.toInt() ?? 0,
      mode: body['mode'] as String?,
      hostId: body['hostId']?.toString(),
      joinerId: body['joinerId']?.toString(),
      hostLabel: body['hostLabel'] as String?,
      joinerLabel: body['joinerLabel'] as String?,
      reconnectSecondsLeft: (body['reconnectSecondsLeft'] as num?)?.toInt(),
      pauseBudgetGone: body['pauseBudgetGone'] == true,
      coinsGranted: (body['coinsGranted'] as num?)?.toInt() ?? 0,
      gemsGranted: (body['gemsGranted'] as num?)?.toInt() ?? 0,
      localLoadout: _stringMap(body['localLoadout']),
      hostLoadout: _stringMap(body['hostLoadout']),
      joinerLoadout: _stringMap(body['joinerLoadout']),
    );
  }

  static Map<String, String> _stringMap(dynamic raw) {
    if (raw is! Map) {
      return const <String, String>{};
    }
    return <String, String>{
      for (final MapEntry<dynamic, dynamic> e in raw.entries)
        e.key.toString(): e.value?.toString() ?? '',
    };
  }

  /// Prefer viewer fields; else pick grants[playerId] from MatchSettled (D-45).
  MatchStart applyGrantsMap(MatchStart match, dynamic grants, String? playerId) {
    if (playerId == null || playerId.isEmpty || grants is! Map) {
      return match;
    }
    final Object? raw = grants[playerId];
    if (raw is! Map) {
      return match;
    }
    final Map<String, dynamic> seat = Map<String, dynamic>.from(raw);
    final int coins = (seat['coins'] as num?)?.toInt() ?? match.coinsGranted;
    final int gems = (seat['gems'] as num?)?.toInt() ?? match.gemsGranted;
    if (coins == match.coinsGranted && gems == match.gemsGranted) {
      return match;
    }
    return MatchStart(
      matchId: match.matchId,
      difficulty: match.difficulty,
      boneIds: match.boneIds,
      turn: match.turn,
      playerScore: match.playerScore,
      botScore: match.botScore,
      status: match.status,
      playerTurns: match.playerTurns,
      botTurns: match.botTurns,
      turnDeadlineEpochMs: match.turnDeadlineEpochMs,
      matchDeadlineEpochMs: match.matchDeadlineEpochMs,
      hardCapEpochMs: match.hardCapEpochMs,
      mode: match.mode,
      hostId: match.hostId,
      joinerId: match.joinerId,
      hostLabel: match.hostLabel,
      joinerLabel: match.joinerLabel,
      reconnectSecondsLeft: match.reconnectSecondsLeft,
      pauseBudgetGone: match.pauseBudgetGone,
      coinsGranted: coins,
      gemsGranted: gems,
      localLoadout: match.localLoadout,
      hostLoadout: match.hostLoadout,
      joinerLoadout: match.joinerLoadout,
    );
  }

  ThrowSubmitResult _parseThrowSubmit(dynamic data, ThrowInput? lastInput) {
    final Map<String, dynamic> body = _asMap(data);
    final Map<String, dynamic> throwMap = _asMap(body['playerThrow']);
    if (!throwMap.containsKey('input')) {
      throwMap['input'] =
          lastInput?.toJson() ??
          <String, Object?>{
            'schemaVersion': 1,
            'yUp': true,
            'aimAngleRad': 0,
            'holdMs': 150,
            'seed': 1,
            'tableId': 'alchiki-match-v1',
          };
    }
    final ThrowResolved resolved = ThrowResolved.parseMap(
      Map<String, Object?>.from(throwMap),
    );
    final Map<String, dynamic> match = body['match'] is Map
        ? _asMap(body['match'])
        : <String, dynamic>{};
    return ThrowSubmitResult(
      playerThrow: resolved,
      botThrow: _parseBotThrow(body['botThrow']),
      playerScore: (match['playerScore'] as num?)?.toInt() ?? 0,
      botScore: (match['botScore'] as num?)?.toInt() ?? 0,
      turn: match['turn'] as String? ?? 'PLAYER',
      bonesLeft: _stringList(match['bonesLeft']),
      status: match['status'] as String? ?? 'IN_PLAY',
      playerTurns: (match['playerTurns'] as num?)?.toInt() ?? 0,
      botTurns: (match['botTurns'] as num?)?.toInt() ?? 0,
      turnDeadlineEpochMs: (match['turnDeadlineEpochMs'] as num?)?.toInt() ?? 0,
      matchDeadlineEpochMs: (match['matchDeadlineEpochMs'] as num?)?.toInt() ?? 0,
      hardCapEpochMs: (match['hardCapEpochMs'] as num?)?.toInt() ?? 0,
    );
  }

  ThrowResolved? _parseBotThrow(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<String, dynamic> bot = _asMap(raw);
    bot.putIfAbsent('schemaVersion', () => 1);
    bot.putIfAbsent('yUp', () => true);
    if (!bot.containsKey('pocketedCount')) {
      final List<String> ids = _stringList(bot['pocketedIds']);
      bot['pocketedCount'] = ids.length;
    }
    if (!bot.containsKey('input') || bot['input'] is! Map) {
      return null;
    }
    return ThrowResolved.parseMap(Map<String, Object?>.from(bot));
  }

  List<String> _stringList(dynamic raw) {
    if (raw is! List) {
      return const <String>[];
    }
    return raw.map((dynamic item) => item.toString()).toList();
  }

  RoomCreated _parseRoomCreated(dynamic data) {
    final Map<String, dynamic> body = _asMap(data);
    return RoomCreated(
      roomId: body['roomId'].toString(),
      code: body['code'] as String,
      hostLabel: body['hostLabel'] as String? ?? '',
      idleExpiresAt: DateTime.parse(body['idleExpiresAt'] as String),
    );
  }

  RoomLobby _parseRoomLobby(dynamic data) {
    final Map<String, dynamic> body = _asMap(data);
    final String? idleRaw = body['idleExpiresAt'] as String?;
    return RoomLobby(
      roomId: body['roomId'].toString(),
      code: body['code'] as String?,
      hostLabel: body['hostLabel'] as String? ?? '',
      joinerLabel: body['joinerLabel'] as String?,
      hostReady: body['hostReady'] == true,
      joinerReady: body['joinerReady'] == true,
      bothReady: body['bothReady'] == true,
      status: body['status'] as String? ?? 'LOBBY',
      idleExpiresAt: idleRaw == null ? DateTime.now() : DateTime.parse(idleRaw),
      matchId: body['matchId']?.toString(),
      game: body['game'] as String?,
    );
  }

  CatalogSnapshot _parseCatalog(dynamic data) {
    final Map<String, dynamic> body = _asMap(data);
    final List<dynamic> tiles =
        body['tiles'] as List<dynamic>? ?? const <dynamic>[];
    return CatalogSnapshot(
      tiles: tiles.map((dynamic raw) {
        final Map<String, dynamic> tile = _asMap(raw);
        return CatalogTile(
          id: tile['id'] as String,
          availability: tile['status'] == 'PLAYABLE'
              ? CatalogAvailability.playable
              : CatalogAvailability.comingSoon,
        );
      }).toList(),
    );
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw NomadApiException('Unexpected JSON object');
  }
}
