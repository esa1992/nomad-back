import 'dart:math' as math;

import 'package:flutter/material.dart';

const Color _felt = Color(0xFF1B6B3A);
const Color _wood = Color(0xFF241810);
const Color _cream = Color(0xFFF4E8C8);
const Color _saka = Color(0xFFFFF6D6);
const Color _sakaStripe = Color(0xFF8B4513);
const Color _bone = Color(0xFFD4A574);
const Color _rim = Color(0xFFE8D4A8);
const Color _accent = Color(0xFFF0B429);

class HowtoCircleDiagram extends StatelessWidget {
  const HowtoCircleDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _CirclePainter(),
      child: SizedBox.expand(),
    );
  }
}

class HowtoAimDiagram extends StatelessWidget {
  const HowtoAimDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _AimPainter(), child: SizedBox.expand());
  }
}

class HowtoHoldDiagram extends StatelessWidget {
  const HowtoHoldDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _HoldPainter(), child: SizedBox.expand());
  }
}

class HowtoScoreDiagram extends StatelessWidget {
  const HowtoScoreDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _ScorePainter(),
      child: SizedBox.expand(),
    );
  }
}

class HowtoWinDiagram extends StatelessWidget {
  const HowtoWinDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _WinPainter(), child: SizedBox.expand());
  }
}

class _CirclePainter extends CustomPainter {
  const _CirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    _paintTable(canvas, size, pocketed: false);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AimPainter extends CustomPainter {
  const _AimPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset saka = _paintTable(canvas, size, pocketed: false);
    final double arrowLen = size.shortestSide * 0.22;
    final Offset tip = saka + Offset(arrowLen * 0.72, -arrowLen * 0.72);
    final Paint arrow = Paint()
      ..color = _cream
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(saka, tip, arrow);
    final Offset dir = tip - saka;
    final double angle = math.atan2(dir.dy, dir.dx);
    final Path head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - 12 * math.cos(angle - 0.45),
        tip.dy - 12 * math.sin(angle - 0.45),
      )
      ..lineTo(
        tip.dx - 12 * math.cos(angle + 0.45),
        tip.dy - 12 * math.sin(angle + 0.45),
      )
      ..close();
    canvas.drawPath(head, Paint()..color = _cream);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HoldPainter extends CustomPainter {
  const _HoldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double meterWidth = size.width * 0.62;
    final double meterLeft = (size.width - meterWidth) / 2;
    final double meterTop = size.height * 0.28;
    final RRect track = RRect.fromLTRBR(
      meterLeft,
      meterTop,
      meterLeft + meterWidth,
      meterTop + 8,
      const Radius.circular(4),
    );
    canvas.drawRRect(track, Paint()..color = _wood);
    canvas.drawRRect(
      RRect.fromLTRBR(
        meterLeft,
        meterTop,
        meterLeft + meterWidth * 0.7,
        meterTop + 8,
        const Radius.circular(4),
      ),
      Paint()..color = _accent,
    );
    canvas.drawRRect(
      track,
      Paint()
        ..color = _cream
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final RRect button = RRect.fromLTRBR(
      size.width * 0.22,
      size.height * 0.48,
      size.width * 0.78,
      size.height * 0.72,
      const Radius.circular(4),
    );
    canvas.drawRRect(button, Paint()..color = _accent);
    _paintLabel(
      canvas,
      'Hold Throw',
      Offset(size.width / 2, size.height * 0.60),
      const TextStyle(
        color: _wood,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScorePainter extends CustomPainter {
  const _ScorePainter();

  @override
  void paint(Canvas canvas, Size size) {
    _paintTable(canvas, size, pocketed: true);
    _paintLabel(
      canvas,
      '+1',
      Offset(size.width * 0.82, size.height * 0.22),
      const TextStyle(
        color: _cream,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WinPainter extends CustomPainter {
  const _WinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _paintLabel(
      canvas,
      'You 5 — Bot 2',
      Offset(size.width / 2, size.height * 0.40),
      const TextStyle(
        color: _cream,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    );
    _paintLabel(
      canvas,
      'First to 5',
      Offset(size.width / 2, size.height * 0.62),
      const TextStyle(
        color: _cream,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Offset _paintTable(Canvas canvas, Size size, {required bool pocketed}) {
  final Offset center = Offset(size.width / 2, size.height * 0.46);
  final double radius = size.shortestSide * 0.34;
  canvas.drawCircle(center, radius, Paint()..color = _felt);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = _rim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3,
  );

  const List<Offset> boneOffsets = <Offset>[
    Offset(0.22, 0.00),
    Offset(0.11, 0.19),
    Offset(-0.11, 0.19),
    Offset(-0.22, 0.00),
    Offset(-0.11, -0.19),
  ];
  final double boneR = radius * 0.11;
  for (int i = 0; i < boneOffsets.length; i++) {
    if (pocketed && i == 0) {
      continue;
    }
    final Offset pos = center + boneOffsets[i] * (radius * 0.42);
    canvas.drawCircle(pos, boneR, Paint()..color = _bone);
  }
  if (pocketed) {
    final Offset out = center + Offset(radius * 1.18, 0);
    canvas.drawCircle(out, boneR, Paint()..color = _bone);
  }

  final Offset saka = center + Offset(0, radius * 0.62);
  final double sakaR = boneR * 1.15;
  canvas.drawCircle(saka, sakaR, Paint()..color = _saka);
  canvas.drawLine(
    saka + Offset(-sakaR * 0.7, 0),
    saka + Offset(sakaR * 0.7, 0),
    Paint()
      ..color = _sakaStripe
      ..strokeWidth = 2,
  );
  return saka;
}

void _paintLabel(Canvas canvas, String text, Offset center, TextStyle style) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
  );
}
