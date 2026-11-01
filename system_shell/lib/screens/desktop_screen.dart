import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:psito_desktop/psito_desktop.dart';
import 'package:psito_dock/psito_dock.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'package:psito_services/system_services.dart';

import '../shell/app_entry.dart';
import '../shell/app_registry.dart';
import '../shell/notification_center.dart';
import '../shell/settings_store.dart';
import '../shell/shortcuts.dart';
import '../shell/window_manager.dart';
import '../shell/window_switcher.dart';
import '../widgets/top_bar.dart';
import '../widgets/desktop_background.dart';
import '../widgets/battery_panel.dart';
import '../widgets/launcher.dart';
import '../widgets/network_panel.dart';
import '../widgets/power_confirm_dialog.dart';
import '../widgets/power_panel.dart';
import '../widgets/volume_osd.dart';
import '../widgets/volume_panel.dart';
import '../widgets/notification_panel.dart';
import '../widgets/notification_toasts.dart';
import '../widgets/psito_desktop_icons.dart';
import '../widgets/psito_dock.dart';
import '../widgets/psito_window.dart';
import '../widgets/window_switcher_overlay.dart';

class DesktopScreen extends StatefulWidget {
  /// Sem store, as configurações ficam só em memória (testes).
  final SettingsStore? settings;

  /// Sem serviços, usa os falsos (testes).
  final SystemServices? services;

  const DesktopScreen({super.key, this.settings, this.services});

  @override
  State<DesktopScreen> createState() => _DesktopScreenState();
}

/// Camadas abertas pela top bar; só uma fica aberta por vez.
enum _Overlay { launcher, notifications, network, volume, battery, power }

/// Ações de energia que pedem confirmação.
enum _PowerAction { powerOff, reboot }

class _DesktopScreenState extends State<DesktopScreen> {
  static const _topBarHeight = 40.0;

  /// Espaço reservado para a dock (com o zoom do hover).
  static const _dockReserve = 100.0;

  late final SettingsStore _settings =
      widget.settings ?? SettingsStore.memory();
  late final SystemServices _services =
      widget.services ?? SystemServices.fake();
  late final _notifications = NotificationCenter(
    silent: () => _settings.value.doNotDisturb,
  );
  late final _windows = WindowManager(
    onNotify: _notifications.post,
    settings: _settings,
    onUpdateSettings: _settings.update,
    systemInfo: _services.systemInfo.info,
    network: _services.network.state,
    time: _services.time,
  );

  // Fora do setState: mover o mouse só redesenha o cursor
  final _mousePosition = ValueNotifier<Offset?>(null);

  final _overlay = ValueNotifier<_Overlay?>(null);
  final _confirm = ValueNotifier<_PowerAction?>(null);

  /// Aviso de volume depois de uma tecla de volume.
  final _volumeOsd = ValueNotifier(false);
  Timer? _volumeOsdTimer;
  static const _volumeOsdDuration = Duration(milliseconds: 1500);
  static const _volumeStep = 0.05;
  final _switcher = WindowSwitcher();

  /// Os apps registrados como a dock e o launcher os veem.
  final _entries = [
    for (final app in registeredApps) AppEntry.fromPsitoApp(app),
  ];
  PsitoApp _appFor(AppEntry entry) =>
      registeredApps.firstWhere((app) => app.id == entry.id);

  /// A dock do laboratório, só em memória: começa com os apps registrados.
  final _dock = DockStore.memory([
    for (final app in registeredApps) DockApp(app.id),
  ]);
  final _superTap = SuperTapDetector();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _dock.dispose();
    _windows.dispose();
    _notifications.dispose();
    if (widget.settings == null) _settings.dispose();
    if (widget.services == null) _services.dispose();
    _mousePosition.dispose();
    _overlay.dispose();
    _confirm.dispose();
    _volumeOsdTimer?.cancel();
    _volumeOsd.dispose();
    _switcher.dispose();
    super.dispose();
  }

  /// Abrir uma camada fecha a que estiver aberta; abrir a mesma fecha.
  void _toggle(_Overlay overlay) {
    _overlay.value = _overlay.value == overlay ? null : overlay;
    if (_overlay.value == _Overlay.notifications) {
      _notifications.markAllRead();
    }
  }

  void _closeOverlay() => _overlay.value = null;

  void _askPower(_PowerAction action) {
    _closeOverlay();
    _confirm.value = action;
  }

  void _runPower(_PowerAction action) {
    _confirm.value = null;
    switch (action) {
      case _PowerAction.powerOff:
        _services.session.powerOff();
      case _PowerAction.reboot:
        _services.session.reboot();
    }
  }

  void _toggleLauncher() => _toggle(_Overlay.launcher);

  /// Traz para frente (restaurando) a janela que notificou; se ela já
  /// fechou, abre o app de novo.
  void _openNotificationSource(ShellNotification notification) {
    _closeOverlay();
    if (notification.windowId case final id? when _windows.contains(id)) {
      _windows.focus(id);
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
        _closeOverlay();
        _switcher.start(
          [for (final w in _windows.windows) SwitcherEntry.fromWindow(w)],
          holdKeys: keyboard.isAltPressed
              ? {LogicalKeyboardKey.altLeft, LogicalKeyboardKey.altRight}
              : {
                  LogicalKeyboardKey.controlLeft,
                  LogicalKeyboardKey.controlRight,
                },
          focusedId: _windows.focusedId,
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
      case ShellAction.volumeUp:
        _stepVolume(1, osd: true);
      case ShellAction.volumeDown:
        _stepVolume(-1, osd: true);
      case ShellAction.volumeMute:
        final audio = _services.audio;
        audio.setMuted(!audio.state.value.muted);
        _showVolumeOsd();
      // Sem bloqueio no laboratório
      case ShellAction.lock:
        break;
      case ShellAction.showDesktop ||
          ShellAction.clipboard ||
          ShellAction.clipboard1 ||
          ShellAction.clipboard2 ||
          ShellAction.clipboard3 ||
          ShellAction.clipboard4 ||
          ShellAction.clipboard5:
        // O histórico é do shell, que lê o compositor
        break;
    }
  }

  void _stepVolume(int direction, {bool osd = false}) {
    final audio = _services.audio;
    final s = audio.state.value;
    if (!s.available) return;
    audio.setVolume(s.volume + direction * _volumeStep);
    if (osd) _showVolumeOsd();
  }

  void _showVolumeOsd() {
    if (!_services.audio.state.value.available) return;
    _volumeOsd.value = true;
    _volumeOsdTimer?.cancel();
    _volumeOsdTimer = Timer(_volumeOsdDuration, () => _volumeOsd.value = false);
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
                Positioned.fill(
                  child: ValueListenableBuilder(
                    valueListenable: _settings,
                    builder: (context, settings, _) => settings.desktopShowIcons
                        ? _LabDesk(
                            iconSize: settings.desktopIconSize,
                            insets: const EdgeInsets.only(
                              top: TopBar.height,
                              bottom: _dockReserve,
                            ),
                          )
                        : const SizedBox.shrink(),
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
                    listenable: Listenable.merge([
                      _notifications,
                      _settings,
                      _services.network.state,
                      _services.audio.state,
                      _services.battery.state,
                    ]),
                    builder: (context, _) => TopBar(
                      onMenuTap: _toggleLauncher,
                      onNotificationsTap: () => _toggle(_Overlay.notifications),
                      network: _services.network.state.value,
                      onNetworkTap: () => _toggle(_Overlay.network),
                      audio: _services.audio.state.value,
                      onVolumeTap: () => _toggle(_Overlay.volume),
                      onVolumeScroll: _stepVolume,
                      battery: _services.battery.state.value,
                      showBatteryPercentage:
                          _settings.value.showBatteryPercentage,
                      onBatteryTap: () => _toggle(_Overlay.battery),
                      onPowerTap: () => _toggle(_Overlay.power),
                      now: _services.time.now,
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
                      listenable: Listenable.merge([
                        _windows,
                        _dock,
                        _settings,
                      ]),
                      builder: (context, _) {
                        final slots = dockLayout(
                          items: _dock.value,
                          apps: {for (final app in _entries) app.id: app},
                          windows: [
                            for (final w in _windows.windows)
                              _DockWindow(w, w.id == _windows.focusedId),
                          ],
                        ).apps;
                        return PsitoDock(
                          tiles: [
                            for (final slot in slots)
                              if (slot.app case final app?)
                                DockTile(
                                  key: slot.id,
                                  entry: app,
                                  windows: slot.windows.length,
                                ),
                          ],
                          onTap: (id, _) => _windows.activateApp(
                            registeredApps.firstWhere((app) => app.id == id),
                          ),
                          iconSize: _settings.value.dockIconSize,
                          magnification: _settings.value.dockMagnification,
                        );
                      },
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

                // Painéis da top bar e o Menu Psito, por cima de tudo menos
                // do seletor e do cursor
                ValueListenableBuilder(
                  valueListenable: _overlay,
                  builder: (context, overlay, _) {
                    final child = switch (overlay) {
                      null => null,
                      _Overlay.notifications => NotificationPanel(
                        center: _notifications,
                        onClose: _closeOverlay,
                        onTap: _openNotificationSource,
                      ),
                      _Overlay.network => NetworkPanel(
                        service: _services.network,
                        onClose: _closeOverlay,
                      ),
                      _Overlay.volume => VolumePanel(
                        state: _services.audio.state,
                        onVolume: _services.audio.setVolume,
                        onMuted: _services.audio.setMuted,
                        onClose: _closeOverlay,
                      ),
                      _Overlay.battery => BatteryPanel(
                        state: _services.battery.state,
                        onClose: _closeOverlay,
                      ),
                      _Overlay.power => PowerPanel(
                        capabilities: _services.session.capabilities,
                        onSuspend: () {
                          _closeOverlay();
                          _services.session.suspend();
                        },
                        onReboot: () => _askPower(_PowerAction.reboot),
                        onPowerOff: () => _askPower(_PowerAction.powerOff),
                        onClose: _closeOverlay,
                      ),
                      _Overlay.launcher => Launcher(
                        apps: _entries,
                        onLaunch: (entry) {
                          _closeOverlay();
                          _windows.open(_appFor(entry));
                        },
                        onClose: _closeOverlay,
                      ),
                    };
                    if (child == null) return const SizedBox.shrink();
                    return Positioned.fill(child: child);
                  },
                ),

                // Confirmação de desligar ou reiniciar
                ValueListenableBuilder(
                  valueListenable: _confirm,
                  builder: (context, action, _) {
                    if (action == null) return const SizedBox.shrink();
                    final powerOff = action == _PowerAction.powerOff;
                    return Positioned.fill(
                      child: PowerConfirmDialog(
                        key: ValueKey(action),
                        powerOff: powerOff,
                        onConfirm: () => _runPower(action),
                        onCancel: () => _confirm.value = null,
                      ),
                    );
                  },
                ),

                // Aviso de volume, acima da dock
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: _dockReserve + 16,
                  child: Center(
                    child: ListenableBuilder(
                      listenable: Listenable.merge([
                        _volumeOsd,
                        _services.audio.state,
                      ]),
                      builder: (context, _) => _volumeOsd.value
                          ? VolumeOsd(state: _services.audio.state.value)
                          : const SizedBox.shrink(),
                    ),
                  ),
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

/// Uma janela do laboratório como a dock a vê.
class _DockWindow implements DockWindow {
  final ShellWindow window;
  @override
  final bool focused;

  const _DockWindow(this.window, this.focused);

  @override
  String get appId => window.app.id;

  @override
  bool get minimized => window.minimized;
}

/// A mesa do laboratório: uma pasta de mentira, sem arquivos de verdade.
class _LabDesk extends StatefulWidget {
  final double iconSize;
  final EdgeInsets insets;

  const _LabDesk({required this.iconSize, required this.insets});

  @override
  State<_LabDesk> createState() => _LabDeskState();
}

class _LabDeskState extends State<_LabDesk> {
  static const _items = {
    'Projetos': Icons.folder_rounded,
    'notas.txt': Icons.description_outlined,
    'foto.png': Icons.image_outlined,
    'um arquivo com um nome bem comprido demais.pdf':
        Icons.picture_as_pdf_outlined,
  };

  final _selection = DeskSelection();

  @override
  Widget build(BuildContext context) {
    final grid = DeskGrid.fit(
      widget.insets.deflateSize(MediaQuery.sizeOf(context)),
      deskCellSize(widget.iconSize),
    );
    final cells = packDesk(_items.keys.toList(), grid);
    final keyboard = HardwareKeyboard.instance;
    return PsitoDesktopIcons(
      icons: [
        for (final MapEntry(key: name, value: icon) in _items.entries)
          DeskIcon(
            key: name,
            name: name,
            icon: (size) =>
                Icon(icon, size: size, color: context.palette.textSecondary),
          ),
      ],
      cells: cells,
      iconSize: widget.iconSize,
      insets: widget.insets,
      selected: _selection.keys,
      onPress: (key) => setState(
        () => _selection.press(
          key,
          cells,
          ctrl: keyboard.isControlPressed,
          shift: keyboard.isShiftPressed,
        ),
      ),
      onRelease: (key) => setState(
        () => _selection.release(
          key,
          ctrl: keyboard.isControlPressed,
          shift: keyboard.isShiftPressed,
        ),
      ),
      onRect: (keys) => setState(() => _selection.rect(keys)),
      onOpen: (name) => debugPrint('🦜 mesa: abrir $name'),
    );
  }
}
