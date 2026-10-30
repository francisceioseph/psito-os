import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shell/app_registry.dart';
import '../shell/window_manager.dart';
import '../widgets/top_bar.dart';
import '../widgets/desktop_background.dart';
import '../widgets/launcher.dart';
import '../widgets/psito_dock.dart';
import '../widgets/psito_window.dart';

class DesktopScreen extends StatefulWidget {
  const DesktopScreen({super.key});

  @override
  State<DesktopScreen> createState() => _DesktopScreenState();
}

class _DesktopScreenState extends State<DesktopScreen> {
  static const _topBarHeight = 40.0;

  /// Espaço reservado para a dock (com o zoom do hover).
  static const _dockReserve = 100.0;

  final _windows = WindowManager();

  // Fora do setState: mover o mouse só redesenha o cursor
  final _mousePosition = ValueNotifier<Offset?>(null);

  final _launcherOpen = ValueNotifier(false);

  /// Super foi pressionado e nenhuma outra tecla veio antes de soltar.
  bool _superAlone = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _windows.dispose();
    _mousePosition.dispose();
    _launcherOpen.dispose();
    super.dispose();
  }

  void _toggleLauncher() => _launcherOpen.value = !_launcherOpen.value;

  // Super sozinho alterna o launcher; Super+tecla fica para os atalhos da
  // etapa 6, que vão assumir este handler.
  bool _onKey(KeyEvent event) {
    final isSuper =
        event.logicalKey == LogicalKeyboardKey.metaLeft ||
        event.logicalKey == LogicalKeyboardKey.metaRight;
    if (event is KeyDownEvent) {
      _superAlone = isSuper;
    } else if (event is KeyUpEvent && isSuper) {
      if (_superAlone) _toggleLauncher();
      _superAlone = false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Listener no topo vê o ponteiro mesmo durante arrastes e sobre
    // MouseRegions aninhados
    return Listener(
      onPointerHover: (event) => _mousePosition.value = event.position,
      onPointerMove: (event) => _mousePosition.value = event.position,
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            _windows.workArea = Rect.fromLTRB(
              0,
              _topBarHeight,
              constraints.maxWidth,
              constraints.maxHeight - _dockReserve,
            );
            return Stack(
              children: [
                // Área de Trabalho / Wallpaper
                const DesktopBackground(),

                // Janelas em z-order e prévia do snap
                Positioned.fill(
                  child: ListenableBuilder(
                    listenable: _windows,
                    builder: (context, _) => Stack(
                      children: [
                        for (final window in _windows.windows)
                          Positioned.fromRect(
                            key: ValueKey(window.id),
                            rect: window.bounds,
                            // Minimizadas ficam na árvore para não perder o estado
                            child: Offstage(
                              offstage: window.minimized,
                              child: TickerMode(
                                enabled: !window.minimized,
                                child: PsitoWindow(
                                  window: window,
                                  manager: _windows,
                                  focused: window.id == _windows.focusedId,
                                ),
                              ),
                            ),
                          ),
                        if (_windows.snapPreviewRect case final rect?)
                          Positioned.fromRect(
                            rect: rect.deflate(8),
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFC107)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFFFC107),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Barra Superior do Sistema
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: TopBar(onMenuTap: _toggleLauncher),
                ),

                // Dock na parte inferior central
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ListenableBuilder(
                      listenable: _windows,
                      builder: (context, _) => PsitoDock(
                        apps: registeredApps,
                        runningAppIds: {
                          for (final w in _windows.windows) w.app.id,
                        },
                        onAppTap: _windows.activateApp,
                      ),
                    ),
                  ),
                ),

                // Menu Psito, por cima de tudo menos do cursor
                ValueListenableBuilder(
                  valueListenable: _launcherOpen,
                  builder: (context, open, _) {
                    if (!open) return const SizedBox.shrink();
                    return Positioned.fill(
                      child: Launcher(
                        apps: registeredApps,
                        onLaunch: (app) {
                          _launcherOpen.value = false;
                          _windows.open(app);
                        },
                        onClose: () => _launcherOpen.value = false,
                      ),
                    );
                  },
                ),

                // Ponteiro do Mouse Customizado e Alinhado
                ValueListenableBuilder(
                  valueListenable: _mousePosition,
                  builder: (context, position, _) {
                    if (position == null) return const SizedBox.shrink();
                    return Positioned(
                      left: position.dx,
                      top: position.dy,
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
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
