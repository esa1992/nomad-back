import 'package:client/theme/steppe_ops.dart';
import 'package:flutter/material.dart';

/// Semi-transparent HUD panel with corner brackets (PUBG-like).
class HudPanel extends StatelessWidget {
  const HudPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accentEdge = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool accentEdge;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CornerBracketPainter(
        color: accentEdge ? SteppeOps.accent : SteppeOps.rim,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SteppeOps.panel,
          border: Border.all(
            color: accentEdge
                ? SteppeOps.accent.withValues(alpha: 0.45)
                : SteppeOps.mist.withValues(alpha: 0.12),
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  const _CornerBracketPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const double arm = 14;
    final Paint p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    void corner(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y), Offset(x + dx * arm, y), p);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy * arm), p);
    }

    corner(0, 0, 1, 1);
    corner(size.width, 0, -1, 1);
    corner(0, size.height, 1, -1);
    corner(size.width, size.height, -1, -1);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Primary lobby CTA — amber fill, condensed label.
class SteppePlayButton extends StatelessWidget {
  const SteppePlayButton({
    super.key,
    required this.label,
    required this.onTap,
    this.minWidth = 220,
    this.dense = false,
  });

  final String label;
  final VoidCallback onTap;
  final double minWidth;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final double height = dense ? 44 : 52;
    final EdgeInsets pad = dense
        ? const EdgeInsets.symmetric(horizontal: 18, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 28, vertical: 14);
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: SteppeOps.accent.withValues(alpha: 0.35),
            blurRadius: dense ? 10 : 16,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: SteppeOps.accent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: dense ? 0 : minWidth,
              minHeight: height,
            ),
            child: Padding(
              padding: pad,
              child: Center(
                child: Text(
                  label,
                  style: dense
                      ? SteppeOps.cta.copyWith(fontSize: 14, letterSpacing: 1.1)
                      : SteppeOps.cta,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SteppeGhostButton extends StatelessWidget {
  const SteppeGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.minWidth = 160,
    this.filled = false,
    this.dense = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final double minWidth;
  final bool filled;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final double height = dense ? 38 : 44;
    final EdgeInsets pad = dense
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 20, vertical: 10);
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: filled ? SteppeOps.panelSolid : Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: dense ? 0 : minWidth,
              minHeight: height,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: SteppeOps.mist.withValues(alpha: 0.55),
                ),
              ),
              child: Padding(
                padding: pad,
                child: Center(
                  child: Text(
                    label,
                    style: SteppeOps.label.copyWith(
                      letterSpacing: dense ? 0.6 : 1.1,
                      fontSize: dense ? 12 : 14,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SteppeChip extends StatelessWidget {
  const SteppeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SteppeOps.accent : Colors.transparent,
      child: InkWell(
        onTap: onSelected,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? SteppeOps.accent
                  : SteppeOps.mist.withValues(alpha: 0.45),
            ),
          ),
          child: Padding(
            padding: dense
                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: SteppeOps.label.copyWith(
                color: selected ? SteppeOps.onAccent : SteppeOps.mist,
                fontSize: dense ? 12 : 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered wait indicator while a network round-trip is in flight.
class SteppeLoading extends StatelessWidget {
  const SteppeLoading({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: SteppeOps.accent,
            ),
          ),
          if (label != null && label!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              label!,
              style: SteppeOps.labelMuted.copyWith(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class SteppeBanner extends StatelessWidget {
  const SteppeBanner({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: SteppeOps.panel,
            border: Border.all(color: SteppeOps.danger),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(message, style: SteppeOps.label, textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(height: 12),
        SteppePlayButton(label: retryLabel, onTap: onRetry, minWidth: 160),
      ],
    );
  }
}
