import 'package:flutter/material.dart';
import 'screens/desktop_screen.dart';

class PsitoOSApp extends StatelessWidget {
  const PsitoOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Psito OS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF12181B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFC107), // Amarelo calopsita 🦜
          secondary: Color(0xFFFF5722), // Bochecha alaranjada
        ),
      ),
      home: const DesktopScreen(),
    );
  }
}