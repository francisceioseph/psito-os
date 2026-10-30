import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shell/app_registry.dart';
import '../shell/notification_center.dart';
import '../shell/settings_store.dart';
import '../shell/shortcuts.dart';
import '../shell/window_manager.dart';
import '../shell/window_switcher.dart';
import '../widgets/top_bar.dart';
import '../widgets/desktop_background.dart';
import '../widgets/launcher.dart';
import '../widgets/notification_panel.dart';
import '../widgets/notification_toasts.dart';
import '../widgets/psito_dock.dart';
import '../widgets/psito_window.dart';
import '../widgets/window_switcher_overlay.dart';

class DesktopScreen extends StatefulWidget {
  /// Sem store, as configurações ficam só em memória (testes).
  final SettingsStore? settings;

  const DesktopScreen({super.key, this.settings});

  @override
  State<DesktopScreen> createState() => _DesktopScreenState();
}

class _DesktopScreenState extends State<DesktopScreen> {
  static const _topBarHeight = 40.0;

  /// Espaço reservado para a dock (com o zoom do hover).
  static const _dockReserve = 100.0;

  late final SettingsStore _settings =
      widget.settings ?? SettingsStore.memory();
  late final _notifications = NotificationCenter(
    silent: () => _settings.value.doNotDisturb,
  );
  late final _windows = WindowManager(
    onNotify: _notifications.post,
    settings: _settings,
    onUpdateSettings: _settings.update,
  );

  // Fora do setState: mover o mouse só redesenha o cursor
  final _mousePosition = ValueNotifier<Offset?>(null);

  final _launcherOpen = ValueNotifier(false);
  final _panelOpen = ValueNotifier(false);
  final _switcher = WindowSwitcher();
  final _superTap = SuperTapDetector();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _windows.dispose();
    _notifications.dispose();
    if (widget.settings == null) _settings.dispose();
    _mousePosition.dispose();
    _launcherOpen.dispose();
    _panelOpen.dispose();
    _switcher.dispose();
    super.dispose();
  }

  // Launcher e painel se excluem: abrir um fecha o outro
  void _toggleLauncher() {
    _panelOpen.value = false;
    _launcherOpen.value = !_launcherOpen.value;
  }

  void _togglePanel() {
    _launcherOpen.value = false;
    _panelOpen.value = !_panelOpen.value;
    if (_panelOpen.value) _notifications.markAllRead();
  }

  /// Traz para frente (restaurando) a janela que notificou; se ela já
  /// fechou, abre o app de novo.
  void _openNotificationSource(ShellNotification notification) {
    _panelOpen.value = false;
    if (_windows.contains(notification.windowId)) {
      _windows.focus(notification.windowId);
      return;
    }
    for (final app in registeredApps) {
      if (app.id == notification.appId) _windows.activateApp(app);
    }
  }

  /// Atalhos globais. Devolve true quando consome a tecla, que então não
  /// chega ao app em foco.
  bool _onKey(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (_switcher.isOpen) {
      if (event is KeyUpEvent) {
        if (_switcher.releases(event.logicalKey)) _commitSwitcher();
        return false;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _switcher.cancel();
      } else {
        final action = resolveShortcut(event, keyboard);
        if (action == ShellAction.switchNext) _switcher.step();
        if (action == ShellAction.switchPrev) _switcher.step(reverse: true);
      }
      // Com o seletor aberto, nenhuma tecla vai para o app
      return true;
    }

    if (_superTap.handle(event)) {
      _toggleLauncher();
      return true;
    }
    final action = resolveShortcut(event, keyboard);
    if (action == null) return false;
    _run(action, keyboard);
    return true;
  }

  void _run(ShellAction action, HardwareKeyboard keyboard) {
    final focused = _windows.focused;
    switch (action) {
      case ShellAction.launcher:
        _toggleLauncher();
      case ShellAction.switchNext || ShellAction.switchPrev:
        _launcherOpen.value = false;
        _panelOpen.value = false;
        _switcher.start(
          _windows.windows,
          holdKeys: keyboard.isAltPressed
              ? {LogicalKeyboardKey.altLeft, LogicalKeyboardKey.altRight}
              : {
                  LogicalKeyboardKey.controlLeft,
                  LogicalKeyboardKey.controlRight,
                },
          reverse: action == ShellAction.switchPrev,
        );
      case ShellAction.closeWindow:
        if (focused != null) _windows.close(focused.id);
      case ShellAction.maximize:
        if (focused != null) _windows.toggleMaximize(focused.id);
      case ShellAction.snapLeft:
        if (focused != null) _toggleSnap(focused, SnapMode.left);
      case ShellAction.snapRight:
        if (focused != null) _toggleSnap(focused, SnapMode.right);
      case ShellAction.minimize:
        if (focused != null) _windows.minimize(focused.id);
    }
  }

  /// Repetir o snap do mesmo lado devolve a janela ao tamanho de antes.
  void _toggleSnap(ShellWindow window, SnapMode mode) {
    if (window.snap == mode) {
      _windows.restore(window.id);
    } else {
      _windows.snap(window.id, mode);
    }
  }

  void _commitSwitcher() {
    final id = _switcher.commit();
    if (id != null) _windows.focus(id);
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
            final accent = Theme.of(context).colorScheme.primary;
            // expand: todos os filhos são posicionados, e sem isso o Stack
            // encolheria a zero
            return Stack(
              fit: StackFit.expand,
              children: [
                // Área de Trabalho / Wallpaper
                Positioned.fill(
                  child: ValueListenableBuilder(
                    valueListenable: _settings,
                    builder: (context, settings, _) =>
                        DesktopBackground(wallpaper: settings.wallpaper),
                  ),
                ),

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
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: accent, width: 1.5),
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
                  child: ListenableBuilder(
                    listenable: Listenable.merge([_notifications, _settings]),
                    builder: (context, _) => TopBar(
                      onMenuTap: _toggleLauncher,
                      onNotificationsTap: _togglePanel,
                      unreadCount: _notifications.unreadCount,
                      use24h: _settings.value.use24h,
                      showSeconds: _settings.value.showSeconds,
                      doNotDisturb: _settings.value.doNotDisturb,
                    ),
                  ),
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

                // Toasts abaixo da top bar, à direita
                Positioned(
                  top: _topBarHeight + 8,
                  right: 12,
                  child: NotificationToasts(
                    center: _notifications,
                    onTap: _openNotificationSource,
                  ),
                ),

                // Painel de notificações
                ValueListenableBuilder(
                  valueListenable: _panelOpen,
                  builder: (context, open, _) {
                    if (!open) return const SizedBox.shrink();
                    return Positioned.fill(
                      child: NotificationPanel(
                        center: _notifications,
                        onClose: () => _panelOpen.value = false,
                        onTap: _openNotificationSource,
                      ),
                    );
                  },
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

                // Seletor de janelas (Alt+Tab / Ctrl+Tab)
                ListenableBuilder(
                  listenable: _switcher,
                  builder: (context, _) {
                    if (!_switcher.isOpen) return const SizedBox.shrink();
                    return Positioned.fill(
                      child: WindowSwitcherOverlay(
                        switcher: _switcher,
                        onPick: (id) {
                          _switcher.cancel();
                          _windows.focus(id);
                        },
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
                          child: Icon(
                            Icons.navigation_rounded, // Ícone de seta pontiaguda de navegação
                            color:
                                accent, // Cor de destaque (amarelo calopsita)
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
