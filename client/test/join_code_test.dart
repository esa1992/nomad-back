import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/app.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _JoinFailApi extends NomadApi {
  _JoinFailApi(SessionStore session, {required this.statusCode})
    : super(sessionStore: session);

  final int statusCode;

  @override
  Future<RoomLobby> joinRoom({required String code}) async {
    throw NomadApiException('join failed', statusCode: statusCode);
  }
}

Future<void> _pumpJoin(WidgetTester tester, {required int statusCode}) async {
  final SessionStore session = SessionStore.memory();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(session),
        nomadApiProvider.overrideWithValue(
          _JoinFailApi(session, statusCode: statusCode),
        ),
      ],
      child: const NomadApp(initialLocation: '/join'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterCodeAndJoin(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'K7M4Q');
  await tester.pump();
  await tester.tap(find.text('Join room'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('404 keeps No such room and typed code', (WidgetTester tester) async {
    await _pumpJoin(tester, statusCode: 404);
    await _enterCodeAndJoin(tester);

    expect(find.textContaining('No such room'), findsOneWidget);
    expect(find.text('K7M4Q'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('409 keeps already started and typed code', (WidgetTester tester) async {
    await _pumpJoin(tester, statusCode: 409);
    await _enterCodeAndJoin(tester);

    expect(find.textContaining('already started'), findsOneWidget);
    expect(find.text('K7M4Q'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('410 keeps Host left and typed code', (WidgetTester tester) async {
    await _pumpJoin(tester, statusCode: 410);
    await _enterCodeAndJoin(tester);

    expect(find.textContaining('Host left. That code no longer works'), findsOneWidget);
    expect(find.text('K7M4Q'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
