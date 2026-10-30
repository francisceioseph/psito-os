import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

import '../shell/app_registry.dart';
import '../widgets/top_bar.dart';
import '../widgets/desktop_background.dart';
import '../widgets/psito_dock.dart';

class WindowInstance {
  final String id;
  final PsitoApp app;
  String title;
  Offset position;
  late final PsitoAppContext context;

  WindowInstance({required this.id, required this.app, required this.position})
    : title = app.name;
}

/// O que um app enxerga do shell, para uma janela.
class _ShellAppContext implements PsitoAppContext {
  final _DesktopScreenState _shell;

  @override
  final String windowId;

  _ShellAppContext(this._shell, this.windowId);

  @override
  void setTitle(String title) => _shell._setTitle(windowId, title);

  @override
  void close() => _shell._closeWindow(windowId);

  @override
  void notify(PsitoNotification notification) {
    // A central de notificações chega na etapa 4 da fase 1
    debugPrint('🦜 Notificação de $windowId: ${notification.title}');
  }
}

class DesktopScreen extends StatefulWidget {
  const DesktopScreen({super.key});

  @override
  State<DesktopScreen> createState() => _DesktopScreenState();
}

class _DesktopScreenState extends State<DesktopScreen> {
  Offset? _mousePosition;
  final List<WindowInstance> _openedWindows = [];

  void _openApp(PsitoApp app) {
    double offset = (_openedWindows.length * 30.0) % 150.0;
    final window = WindowInstance(
      id: '${app.id}_${DateTime.now().millisecondsSinceEpoch}',
      app: app,
      position: Offset(150.0 + offset, 80.0 + offset),
    );
    window.context = _ShellAppContext(this, window.id);
    setState(() => _openedWindows.add(window));
    app.onOpen(window.context);
    debugPrint('🦜 Abrindo app em multitarefa: ${app.name}');
  }

  void _closeWindow(String windowId) {
    final index = _openedWindows.indexWhere((w) => w.id == windowId);
    if (index < 0) return;
    final window = _openedWindows[index];
    setState(() => _openedWindows.removeAt(index));
    window.app.onClose(window.context);
  }

  void _setTitle(String windowId, String title) {
    final index = _openedWindows.indexWhere((w) => w.id == windowId);
    if (index < 0) return;
    setState(() => _openedWindows[index].title = title);
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
                    width: window.app.defaultSize.width,
                    height: window.app.defaultSize.height,
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
                                    window.title,
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
                        Expanded(child: window.app.build(window.context)),
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
              child: Center(
                child: PsitoDock(apps: registeredApps, onAppTap: _openApp),
              ),
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
}
