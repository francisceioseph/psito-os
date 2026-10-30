import 'package:flutter/material.dart';

import 'screens/desktop_screen.dart';
import 'shell/settings_store.dart';

class PsitoOSApp extends StatelessWidget {
  final SettingsStore settings;

  const PsitoOSApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    // O tema acompanha a cor de destaque escolhida nas Configurações
    return ValueListenableBuilder(
      valueListenable: settings,
      builder: (context, value, _) => MaterialApp(
        title: 'Psito OS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF12181B),
          colorScheme: ColorScheme.dark(
            primary: value.accent, // Amarelo calopsita 🦜 por padrão
            secondary: const Color(0xFFFF5722), // Bochecha alaranjada
          ),
        ),
        home: DesktopScreen(settings: settings),
      ),
    );
  }
}
