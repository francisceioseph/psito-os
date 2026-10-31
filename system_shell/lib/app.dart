import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

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
        home: DesktopScreen(settings: settings, services: services),
      ),
    );
  }
}
