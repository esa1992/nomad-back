import 'package:client/game/alchiki_sandbox_game.dart';
import 'package:client/game/felt_circle.dart';
import 'package:client/game/knucklebone_look.dart';
import 'package:client/input/aim_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scoring circle is packed earth, not billiard felt', () {
    expect(FeltCircle.fill, isNot(const Color(0xFF1B6B3A)));
    expect(FeltCircle.fill, const Color(0xFF5C3C22));
  });

  test('aim defaults toward the sohi cluster', () {
    expect(AimController().aimAngleRad, closeTo(1.5708, 0.001));
  });

  test('table squash is stronger than a flat top-down view', () {
    expect(presentationScaleY, lessThan(0.86));
    expect(presentationScaleY, greaterThan(0.6));
  });

  testWidgets('knucklebone and pit painters draw without throwing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomPaint(
            painter: _LookPainter(),
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CustomPaint), findsWidgets);
  });
}

class _LookPainter extends CustomPainter {
  const _LookPainter();

  @override
  void paint(Canvas canvas, Size size) {
    KnuckleboneLook.paintPit(
      canvas,
      center: Offset(size.width / 2, size.height / 2),
      radius: 80,
      rim: const Color(0xFFE8D4A8),
      flashing: false,
    );
    KnuckleboneLook.paint(
      canvas,
      center: Offset(size.width / 2, size.height / 2),
      radius: 18,
      fill: const Color(0xFFFFF6D6),
      crease: const Color(0xFF8B4513),
      bodyAngle: 0.4,
      shooter: true,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
