import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/locale_controller.dart';
import 'package:client/platform/router.dart';
import 'package:client/theme/steppe_ops.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NomadApp extends ConsumerStatefulWidget {
  const NomadApp({super.key, this.initialLocation = '/splash'});

  final String initialLocation;

  @override
  ConsumerState<NomadApp> createState() => _NomadAppState();
}

class _NomadAppState extends ConsumerState<NomadApp> {
  late final GoRouter _router = buildRouter(
    initialLocation: widget.initialLocation,
  );

  @override
  Widget build(BuildContext context) {
    final Locale? localeOverride = ref.watch(localeOverrideProvider);
    return MaterialApp.router(
      theme: SteppeOps.theme(),
      locale: localeOverride,
      localeListResolutionCallback: (locales, supported) {
        for (final Locale locale in locales ?? const <Locale>[]) {
          if (supported.contains(Locale(locale.languageCode))) {
            return Locale(locale.languageCode);
          }
        }
        return const Locale('en');
      },
      supportedLocales: const [Locale('en'), Locale('ru')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: _router,
    );
  }
}
