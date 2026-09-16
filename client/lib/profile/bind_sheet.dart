import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/auth/bind_api.dart';
import 'package:client/platform/auth/bind_prompt_store.dart';
import 'package:client/profile/sign_in_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const Color _wood = Color(0xFF241810);
const Color _cream = Color(0xFFF4E8C8);
const Color _accent = Color(0xFFF0B429);
const Color _onAccent = Color(0xFF241810);
const Color _destructive = Color(0xFFC43C2C);
const Color _fieldBorder = Color(0xFFE8D4A8);
const Color _scrim = Color(0x99241810);

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

/// D-92 gate: first Alchiki bot win + guest + unseen prompt only.
bool shouldOfferBindAfterBotWin({
  required bool isBotMode,
  required bool isPlayerWin,
  required bool isGuest,
  required bool promptSeen,
}) {
  return isBotMode && isPlayerWin && isGuest && !promptSeen;
}

/// Presents the 07-UI-SPEC bind modal bottom sheet; marks prompt seen on dismiss/success.
Future<void> showBindSheet(
  BuildContext context, {
  BindApi? bindApi,
  BindPromptStore? promptStore,
  bool markPromptSeen = true,
}) async {
  final BindPromptStore store =
      promptStore ??
      ProviderScope.containerOf(context).read(bindPromptStoreProvider);
  final BindApi api =
      bindApi ?? ProviderScope.containerOf(context).read(bindApiProvider);

  bool openSignIn = false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: _scrim,
    builder: (BuildContext sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: BindSheet(
          onBind: (String username, String password) async {
            await api.bind(username: username, password: password);
          },
          onNotNow: () => Navigator.of(sheetContext).pop(),
          onSignInInstead: () {
            openSignIn = true;
            Navigator.of(sheetContext).pop();
          },
          onSuccess: () => Navigator.of(sheetContext).pop(),
        ),
      );
    },
  );

  if (markPromptSeen) {
    await store.markSeen();
  }
  if (openSignIn && context.mounted) {
    await showSignInSheet(context, bindApi: api);
  }
}

/// Wood bind bottom-sheet body (D-92 / AUTH-02). Password never logged.
class BindSheet extends StatefulWidget {
  const BindSheet({
    super.key,
    required this.onBind,
    required this.onNotNow,
    required this.onSignInInstead,
    this.onSuccess,
    this.usernameTaken = false,
  });

  final Future<void> Function(String username, String password) onBind;
  final VoidCallback onNotNow;
  final VoidCallback onSignInInstead;
  final VoidCallback? onSuccess;

  /// When true, shows username-taken copy and Sign in instead (widget tests / injected).
  final bool usernameTaken;

  @override
  State<BindSheet> createState() => _BindSheetState();
}

class _BindSheetState extends State<BindSheet> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _submitting = false;
  bool _usernameTaken = false;
  bool _bindError = false;

  @override
  void initState() {
    super.initState();
    _usernameTaken = widget.usernameTaken;
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final String username = _username.text.trim();
    final String password = _password.text;
    if (username.isEmpty || password.length < 8) {
      setState(() {
        _bindError = true;
        _usernameTaken = false;
      });
      return;
    }
    setState(() {
      _submitting = true;
      _bindError = false;
      _usernameTaken = false;
    });
    try {
      await widget.onBind(username, password);
      if (!mounted) {
        return;
      }
      widget.onSuccess?.call();
    } on NomadApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        if (error.statusCode == 409) {
          _usernameTaken = true;
          _bindError = false;
        } else {
          _bindError = true;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _bindError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Material(
      color: _wood,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _cream.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  _usernameTaken ? l10n.usernameTakenTitle : l10n.bindSheetTitle,
                  style: _heading,
                ),
                const SizedBox(height: 8),
                Text(
                  _usernameTaken ? l10n.usernameTakenBody : l10n.bindSheetBody,
                  style: _body,
                ),
                const SizedBox(height: 24),
                Text(l10n.usernameLabel, style: _label),
                const SizedBox(height: 4),
                SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _username,
                    style: _body,
                    enabled: !_submitting,
                    decoration: _fieldDecoration(error: _usernameTaken),
                  ),
                ),
                const SizedBox(height: 8),
                Text(l10n.passwordLabel, style: _label),
                const SizedBox(height: 4),
                SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _password,
                    style: _body,
                    obscureText: true,
                    enabled: !_submitting,
                    decoration: _fieldDecoration(error: _bindError),
                  ),
                ),
                const SizedBox(height: 8),
                Text(l10n.passwordRule, style: _body),
                if (_bindError) ...[
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: _destructive),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(l10n.errorBind, style: _body),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      disabledBackgroundColor: _accent.withValues(alpha: 0.4),
                      foregroundColor: _onAccent,
                    ),
                    child: Text(
                      l10n.bindAccount,
                      style: _label.copyWith(color: _onAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _submitting ? null : widget.onNotNow,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _cream,
                      side: const BorderSide(color: _cream),
                    ),
                    child: Text(l10n.notNow, style: _label),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: TextButton(
                    onPressed: _submitting ? null : widget.onSignInInstead,
                    style: TextButton.styleFrom(foregroundColor: _cream),
                    child: Text(l10n.signInInstead, style: _label),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({required bool error}) {
    return InputDecoration(
      filled: true,
      fillColor: _wood,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: error ? _destructive : _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: error ? _destructive : _accent),
      ),
      disabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: (error ? _destructive : _fieldBorder).withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
