import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/l10n/system_localizations.dart';
import 'package:system_shell/shell/app_registry.dart';

import 'screens/desktop_screen.dart';

import 'package:psito_services/system_services.dart';

import 'shell/settings_store.dart';

class PsitoOSApp extends StatelessWidget {
  final SettingsStore settings;
  final SystemServices services;

  const PsitoOSApp({super.key, required this.settings, required this.services});

  @override
  Widget build(BuildContext context) {
    // O tema acompanha a cor de destaque escolhida nas Configurações
    return ValueListenableBuilder(
      valueListenable: settings,
      builder: (context, value, _) => MaterialApp(
        title: 'Psito OS',
        debugShowCheckedModeBanner: false,
        theme: psitoTheme(value.accent),
        locale: resolvePsitoLocale(value.language),
        localizationsDelegates: psitoLocalizationsDelegates([
          SystemLocalizations.delegate,
          for (final app in registeredApps) ...app.localizationsDelegates,
        ]),
        supportedLocales: psitoLocales,
        home: DesktopScreen(settings: settings, services: services),
      ),
    );
  }
}
