import 'package:client/boards/boards_page.dart';
import 'package:client/catalog/catalog_page.dart';
import 'package:client/games/alchiki/match_page.dart';
import 'package:client/games/alchiki/rematch_waiting_page.dart';
import 'package:client/games/stick_pull/stick_pull_match_page.dart';
import 'package:client/howto/alchiki_howto_page.dart';
import 'package:client/howto/stick_pull_howto_page.dart';
import 'package:client/matchmaking/fallback_page.dart';
import 'package:client/matchmaking/searching_page.dart';
import 'package:client/platform/splash_page.dart';
import 'package:client/profile/profile_page.dart';
import 'package:client/rooms/join_page.dart';
import 'package:client/rooms/lobby_page.dart';
import 'package:client/sandbox_page.dart';
import 'package:client/shop/shop_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

GoRouter buildRouter({String initialLocation = '/splash'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const CatalogPage(),
      ),
      GoRoute(
        path: '/howto/alchiki',
        builder: (context, state) {
          final String difficulty =
              state.uri.queryParameters['difficulty'] ?? 'EASY';
          final String? fromPauseRaw = state.uri.queryParameters['fromPause'];
          final bool fromPause = fromPauseRaw == '1' ||
              fromPauseRaw == 'true';
          final String? mode = state.uri.queryParameters['mode'];
          final String? matchId = state.uri.queryParameters['matchId'];
          return AlchikiHowToPage(
            difficulty: difficulty,
            fromPause: fromPause,
            mode: mode,
            matchId: matchId,
          );
        },
      ),
      GoRoute(
        path: '/howto/stick-pull',
        builder: (context, state) {
          final String difficulty =
              state.uri.queryParameters['difficulty'] ?? 'EASY';
          final String? fromPauseRaw = state.uri.queryParameters['fromPause'];
          final bool fromPause = fromPauseRaw == '1' ||
              fromPauseRaw == 'true';
          final String? mode = state.uri.queryParameters['mode'];
          final String? matchId = state.uri.queryParameters['matchId'];
          return StickPullHowToPage(
            difficulty: difficulty,
            fromPause: fromPause,
            mode: mode,
            matchId: matchId,
          );
        },
      ),
      GoRoute(
        path: '/match/rematch-wait',
        builder: (context, state) {
          final String matchId = state.uri.queryParameters['matchId'] ?? '';
          final String opponent =
              state.uri.queryParameters['opponent'] ?? '';
          return RematchWaitingPage(
            matchId: matchId,
            opponentLabel: opponent,
          );
        },
      ),
      GoRoute(
        path: '/match',
        builder: (context, state) {
          final String? mode = state.uri.queryParameters['mode'];
          final String? matchId = state.uri.queryParameters['matchId'];
          final String? game = state.uri.queryParameters['game'];
          final String difficulty = state.uri.queryParameters['difficulty'] ??
              (mode == 'private' || mode == 'casual' ? 'NORMAL' : 'EASY');
          if (game == 'stickPull') {
            return StickPullMatchPage(
              difficulty: difficulty,
              matchId: matchId,
              mode: mode,
            );
          }
          return AlchikiMatchPage(
            difficulty: difficulty,
            mode: mode,
            matchId: matchId,
          );
        },
      ),
      GoRoute(
        path: '/lobby',
        builder: (context, state) {
          final String roomId = state.uri.queryParameters['roomId'] ?? '';
          final String code = state.uri.queryParameters['code'] ?? '';
          final String hostLabel = state.uri.queryParameters['hostLabel'] ?? '';
          final String? game = state.uri.queryParameters['game'];
          return LobbyPage(
            roomId: roomId,
            code: code,
            hostLabel: hostLabel,
            game: game,
          );
        },
      ),
      GoRoute(
        path: '/join',
        builder: (context, state) => const JoinPage(),
      ),
      GoRoute(
        path: '/shop',
        builder: (context, state) => const ShopPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/boards',
        builder: (context, state) => const BoardsPage(),
      ),
      GoRoute(
        path: '/matchmaking',
        builder: (context, state) {
          final String? game = state.uri.queryParameters['game'];
          final String? mode = state.uri.queryParameters['mode'];
          return SearchingPage(game: game, mode: mode);
        },
      ),
      GoRoute(
        path: '/matchmaking/fallback',
        builder: (context, state) {
          final String? game = state.uri.queryParameters['game'];
          return FallbackPage(game: game);
        },
      ),
      GoRoute(
        path: '/debug/sandbox',
        builder: (context, state) => const SandboxPage(),
      ),
    ],
  );
}
