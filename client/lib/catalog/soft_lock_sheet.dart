import 'package:client/l10n/app_localizations.dart';
import 'package:client/profile/bind_sheet.dart';
import 'package:flutter/material.dart';

const Color _wood = Color(0xFF241810);
const Color _cream = Color(0xFFF4E8C8);
const Color _accent = Color(0xFFF0B429);
const Color _onAccent = Color(0xFF241810);
const Color _scrim = Color(0x99241810);
const Color _softLockFill = Color(0xE0241810);

const TextStyle _label = TextStyle(
  color: _cream,
  fontSize: 14,
  fontWeight: FontWeight.w600,
  height: 1.2,
);
const TextStyle _body = TextStyle(
  color: _cream,
  fontSize: 16,
  fontWeight: FontWeight.w400,
  height: 1.5,
);
const TextStyle _heading = TextStyle(
  color: _cream,
  fontSize: 20,
  fontWeight: FontWeight.w600,
  height: 1.2,
);

enum SoftLockKind { ranked, boards }

/// D-96 guest soft-lock: Ranked / Boards → Bind now / Not now.
Future<void> showSoftLockSheet(
  BuildContext context, {
  required SoftLockKind kind,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: _scrim,
    builder: (BuildContext sheetContext) {
      return SoftLockSheet(
        kind: kind,
        onBindNow: () {
          Navigator.of(sheetContext).pop();
          showBindSheet(context, markPromptSeen: false);
        },
        onNotNow: () => Navigator.of(sheetContext).pop(),
      );
    },
  );
}

class SoftLockSheet extends StatelessWidget {
  const SoftLockSheet({
    super.key,
    required this.kind,
    required this.onBindNow,
    required this.onNotNow,
  });

  final SoftLockKind kind;
  final VoidCallback onBindNow;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String title = kind == SoftLockKind.ranked
        ? l10n.rankedLockTitle
        : l10n.boardsLockTitle;
    final String body = kind == SoftLockKind.ranked
        ? l10n.rankedLockBody
        : l10n.boardsLockBody;
    return Material(
      color: _softLockFill,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: _heading),
              const SizedBox(height: 8),
              Text(body, style: _body),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: onBindNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: _onAccent,
                  ),
                  child: Text(
                    l10n.bindNow,
                    style: _label.copyWith(color: _onAccent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: onNotNow,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _cream,
                    side: const BorderSide(color: _cream),
                  ),
                  child: Text(l10n.notNow, style: _label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
