import 'package:flutter/material.dart';
import 'package:system_shell/apps/browser_app.dart';

import '../widgets/top_bar.dart';
import '../widgets/desktop_background.dart';
import '../widgets/psito_dock.dart';
import '../models/psito_app_item.dart';
import '../apps/notepad_app.dart';
import '../apps/calculator_app.dart';
import '../apps/clock_app.dart';
import '../apps/files_app.dart';
import '../apps/buddy_app.dart';

class WindowInstance {
  final String id;
  final PsitoAppItem app;
  Offset position;

  WindowInstance({required this.id, required this.app, required this.position});
}

class DesktopScreen extends StatefulWidget {
  const DesktopScreen({super.key});

  @override
  State<DesktopScreen> createState() => _DesktopScreenState();
}

class _DesktopScreenState extends State<DesktopScreen> {
  Offset? _mousePosition;
  final List<WindowInstance> _openedWindows = [];

  void _openApp(PsitoAppItem app) {
    setState(() {
      double offset = (_openedWindows.length * 30.0) % 150.0;
      _openedWindows.add(
        WindowInstance(
          id: '${app.id}_${DateTime.now().millisecondsSinceEpoch}',
          app: app,
          position: Offset(150.0 + offset, 80.0 + offset),
        ),
      );
    });
    debugPrint('🦜 Abrindo app em multitarefa: ${app.name}');
  }

  void _closeWindow(String windowId) {
    setState(() {
      _openedWindows.removeWhere((w) => w.id == windowId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      // Rastreia perfeitamente a posição do mouse na tela toda
      onHover: (event) {
        setState(() {
          _mousePosition = event.position;
        });
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Área de Trabalho / Wallpaper
            const DesktopBackground(),

            // Renderiza todas as janelas abertas (Multitasking)
            for (var window in _openedWindows)
              Positioned(
                left: window.position.dx,
                top: window.position.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      window.position += details.delta;
                    });
                  },
                  child: Container(
                    width: 480,
                    height: 360,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E252B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: window.app.color, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 25,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Barra de título da janela
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(15),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    window.app.icon,
                                    size: 18,
                                    color: window.app.color,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    window.app.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => _closeWindow(window.id),
                                color: Colors.white70,
                                splashRadius: 16,
                              ),
                            ],
                          ),
                        ),
                        // Conteúdo interno do app
                        Expanded(child: _buildAppContent(window.app.id)),
                      ],
                    ),
                  ),
                ),
              ),

            // Barra Superior do Sistema
            const Positioned(top: 0, left: 0, right: 0, child: TopBar()),

            // Dock na parte inferior central
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(child: PsitoDock(onAppTap: _openApp)),
            ),

            // Ponteiro do Mouse Customizado e Alinhado
            if (_mousePosition != null)
              Positioned(
                left: _mousePosition!.dx,
                top: _mousePosition!.dy,
                child: IgnorePointer(
                  child: Transform.rotate(
                    angle: -0.60, // -45 graus (-π/4)
                    child: const Icon(
                      Icons.navigation_rounded, // Ícone de seta pontiaguda de navegação
                      color: Color(0xFFFFC107), // Amarelo Calopsita
                      size: 22,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppContent(String appId) {
    switch (appId) {
      case 'notepad':
        return const NotepadApp();
      case 'calculator':
        return const CalculatorApp();
      case 'clock':
        return const ClockApp();
      case 'files':
        return const FilesApp();
      case 'buddy':
        return const BuddyApp();
      case 'browser':
        return const BrowserApp();
      default:
        return const Center(
          child: Text(
            'App desconhecido',
            style: TextStyle(color: Colors.white60),
          ),
        );
    }
  }
}
