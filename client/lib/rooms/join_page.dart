import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class JoinPage extends ConsumerStatefulWidget {
  const JoinPage({super.key});

  @override
  ConsumerState<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends ConsumerState<JoinPage> {
  static const Color _wood = Color(0xFF241810);
  static const Color _onDark = Color(0xFFF4E8C8);
  static const Color _accent = Color(0xFFF0B429);
  static const Color _onAccent = Color(0xFF241810);
  static const Color _destructive = Color(0xFFC43C2C);

  static const TextStyle _label = TextStyle(
    color: _onDark,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
  static const TextStyle _body = TextStyle(
    color: _onDark,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const TextStyle _heading = TextStyle(
    color: _onDark,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
  static const TextStyle _display = TextStyle(
    color: _onDark,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 4,
  );

  final TextEditingController _code = TextEditingController();
  int? _errorStatus;
  bool _joining = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String get _normalized =>
      _code.text.replaceAll(RegExp(r'\s'), '').toUpperCase();

  bool get _canJoin {
    final int length = _normalized.length;
    return length >= 4 && length <= 6 && !_joining;
  }

  String _helper(AppLocalizations l10n) {
    return switch (_errorStatus) {
      404 => l10n.errorNoSuchRoom,
      409 => l10n.errorAlreadyStarted,
      410 => l10n.errorHostLeft,
      _ => l10n.emptyJoinBody,
    };
  }

  Future<void> _join() async {
    if (!_canJoin) {
      return;
    }
    setState(() => _joining = true);
    try {
      final RoomLobby lobby = await ref
          .read(nomadApiProvider)
          .joinRoom(code: _normalized);
      if (!mounted) {
        return;
      }
      context.go(
        '/lobby?roomId=${Uri.encodeQueryComponent(lobby.roomId)}',
      );
    } on NomadApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _joining = false;
        _errorStatus = error.statusCode;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _joining = false;
        _errorStatus = 404;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool error = _errorStatus == 404 ||
        _errorStatus == 409 ||
        _errorStatus == 410;
    final Color outline = error ? _destructive : _onDark;
    return Scaffold(
      backgroundColor: _wood,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.joinByCode, style: _heading),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: TextField(
                controller: _code,
                style: _display,
                textAlign: TextAlign.center,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  TextInputFormatter.withFunction((
                    TextEditingValue oldValue,
                    TextEditingValue newValue,
                  ) {
                    return newValue.copyWith(
                      text: newValue.text.toUpperCase(),
                    );
                  }),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  counterText: '',
                  helperText: _helper(l10n),
                  helperMaxLines: 3,
                  helperStyle: _body,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: outline),
                  ),
                ),
                ),
              ),
              const Spacer(),
              Opacity(
                opacity: _canJoin ? 1 : 0.4,
                child: _JoinButton(
                  label: l10n.joinRoom,
                  fill: _accent,
                  textColor: _onAccent,
                  outlined: false,
                  onTap: _canJoin ? _join : null,
                ),
              ),
              const SizedBox(height: 16),
              _JoinButton(
                label: l10n.backToCatalog,
                fill: _wood,
                textColor: _onDark,
                outlined: true,
                onTap: () => context.go('/'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({
    required this.label,
    required this.fill,
    required this.textColor,
    required this.outlined,
    required this.onTap,
  });

  final String label;
  final Color fill;
  final Color textColor;
  final bool outlined;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: outlined ? Colors.transparent : fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: outlined
            ? const BorderSide(color: _JoinPageState._onDark)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(
              child: Text(label, style: _JoinPageState._label.copyWith(color: textColor)),
            ),
          ),
        ),
      ),
    );
  }
}
