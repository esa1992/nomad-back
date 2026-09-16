import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/auth/bind_api.dart';
import 'package:client/platform/auth/session_store.dart';
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

/// Presents Sign in sheet (AUTH-03 / D-93 adopt contract).
Future<bool> showSignInSheet(
  BuildContext context, {
  BindApi? bindApi,
  SessionStore? sessionStore,
}) async {
  final BindApi api =
      bindApi ?? ProviderScope.containerOf(context).read(bindApiProvider);
  final SessionStore session =
      sessionStore ??
      ProviderScope.containerOf(context).read(sessionStoreProvider);

  final bool? signedIn = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: _scrim,
    builder: (BuildContext sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SignInSheet(
          onLogin: ({
            required String username,
            required String password,
            required String adopt,
            required bool persist,
          }) async {
            final String? guestId = await session.playerId();
            return api.login(
              username: username,
              password: password,
              guestPlayerId: guestId,
              adopt: adopt,
              persist: persist,
            );
          },
          onDismiss: () => Navigator.of(sheetContext).pop(false),
          onSuccess: () => Navigator.of(sheetContext).pop(true),
        ),
      );
    },
  );
  return signedIn == true;
}

/// Destructive Log out confirm → API logout → caller routes to catalog (D-95).
Future<bool> showLogOutConfirm(
  BuildContext context, {
  BindApi? bindApi,
}) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final bool? confirmed = await showDialog<bool>(
    context: context,
    barrierColor: _scrim,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        backgroundColor: _wood,
        title: Text(l10n.logOutTitle, style: _heading),
        content: Text(l10n.logOutBody, style: _body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: _cream),
            child: Text(l10n.stay, style: _label),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _destructive,
              foregroundColor: _cream,
              side: const BorderSide(color: _destructive),
            ),
            child: Text(l10n.logOut, style: _label.copyWith(color: _cream)),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) {
    return false;
  }
  final BindApi api =
      bindApi ?? ProviderScope.containerOf(context).read(bindApiProvider);
  await api.logout();
  return true;
}

/// Wood sign-in sheet with D-93 adoptHint handling (never silent sum).
class SignInSheet extends StatefulWidget {
  const SignInSheet({
    super.key,
    required this.onLogin,
    required this.onDismiss,
    this.onSuccess,
    this.forceReplaceGuest = false,
  });

  final Future<GuestSession> Function({
    required String username,
    required String password,
    required String adopt,
    required bool persist,
  }) onLogin;
  final VoidCallback onDismiss;
  final VoidCallback? onSuccess;

  /// Widget-test hook: show replaceGuest confirm chrome immediately.
  final bool forceReplaceGuest;

  @override
  State<SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<SignInSheet> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _submitting = false;
  bool _signInError = false;
  bool _replaceGuest = false;
  bool _importOffer = false;
  String? _pendingUser;
  String? _pendingPass;

  @override
  void initState() {
    super.initState();
    _replaceGuest = widget.forceReplaceGuest;
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit({String adopt = 'none', bool persist = false}) async {
    if (_submitting) {
      return;
    }
    final String username = (_pendingUser ?? _username.text).trim();
    final String password = _pendingPass ?? _password.text;
    if (username.isEmpty || password.length < 8) {
      setState(() => _signInError = true);
      return;
    }
    setState(() {
      _submitting = true;
      _signInError = false;
    });
    try {
      final GuestSession session = await widget.onLogin(
        username: username,
        password: password,
        adopt: adopt,
        persist: persist,
      );
      if (!mounted) {
        return;
      }
      if (adopt == 'none' && !persist) {
        if (session.dropRequired) {
          setState(() {
            _submitting = false;
            _replaceGuest = true;
            _importOffer = false;
            _pendingUser = username;
            _pendingPass = password;
          });
          return;
        }
        if (session.importEligible) {
          setState(() {
            _submitting = false;
            _importOffer = true;
            _replaceGuest = false;
            _pendingUser = username;
            _pendingPass = password;
          });
          return;
        }
        // No adopt decision needed — persist bound session via adopt=drop cleanup
        // or re-login with persist. adopt=none already authenticated; persist now.
        await widget.onLogin(
          username: username,
          password: password,
          adopt: 'none',
          persist: true,
        );
        if (!mounted) {
          return;
        }
        widget.onSuccess?.call();
        return;
      }
      widget.onSuccess?.call();
    } on NomadApiException {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _signInError = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _signInError = true;
      });
    }
  }

  Future<void> _confirmDrop() => _submit(adopt: 'drop', persist: true);

  Future<void> _confirmImport() => _submit(adopt: 'import', persist: true);

  Future<void> _declineImportKeepBound() =>
      _submit(adopt: 'drop', persist: true);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_replaceGuest) {
      return _ConfirmPanel(
        title: l10n.replaceGuestTitle,
        body: l10n.replaceGuestBody,
        primaryLabel: l10n.signInAnyway,
        primaryDestructive: true,
        secondaryLabel: l10n.notNow,
        onPrimary: _submitting ? null : _confirmDrop,
        onSecondary: _submitting ? null : widget.onDismiss,
      );
    }
    if (_importOffer) {
      return _ConfirmPanel(
        title: l10n.signInTitle,
        body: l10n.bindSheetBody,
        primaryLabel: l10n.bindThisGuest,
        primaryDestructive: false,
        secondaryLabel: l10n.signInAnyway,
        onPrimary: _submitting ? null : _confirmImport,
        onSecondary: _submitting ? null : _declineImportKeepBound,
      );
    }
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
                Text(l10n.signInTitle, style: _heading),
                const SizedBox(height: 8),
                Text(l10n.signInBody, style: _body),
                const SizedBox(height: 24),
                Text(l10n.usernameLabel, style: _label),
                const SizedBox(height: 4),
                SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _username,
                    style: _body,
                    enabled: !_submitting,
                    decoration: _fieldDecoration(error: _signInError),
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
                    decoration: _fieldDecoration(error: _signInError),
                  ),
                ),
                const SizedBox(height: 8),
                Text(l10n.passwordRule, style: _body),
                if (_signInError) ...[
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: _destructive),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(l10n.errorSignIn, style: _body),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submitting
                        ? null
                        : () => _submit(adopt: 'none', persist: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      disabledBackgroundColor: _accent.withValues(alpha: 0.4),
                      foregroundColor: _onAccent,
                    ),
                    child: Text(
                      l10n.signIn,
                      style: _label.copyWith(color: _onAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _submitting ? null : widget.onDismiss,
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

class _ConfirmPanel extends StatelessWidget {
  const _ConfirmPanel({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.primaryDestructive,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final bool primaryDestructive;
  final String secondaryLabel;
  final Future<void> Function()? onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _wood,
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
                  onPressed: onPrimary == null
                      ? null
                      : () => onPrimary!.call(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        primaryDestructive ? _destructive : _accent,
                    foregroundColor:
                        primaryDestructive ? _cream : _onAccent,
                    side: primaryDestructive
                        ? const BorderSide(color: _destructive)
                        : BorderSide.none,
                  ),
                  child: Text(
                    primaryLabel,
                    style: _label.copyWith(
                      color: primaryDestructive ? _cream : _onAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: onSecondary,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _cream,
                    side: const BorderSide(color: _cream),
                  ),
                  child: Text(secondaryLabel, style: _label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
