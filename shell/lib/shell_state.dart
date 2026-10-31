// shell/lib/shell_state.dart
//
// O estado do shell, um só para todas as superfícies: as views da top bar,
// da dock e da sobreposição leem e mudam este mesmo objeto.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:psito_dock/psito_dock.dart';
import 'package:psito_services/system_services.dart';
import 'package:system_shell/shell/app_entry.dart';
import 'package:system_shell/shell/notification_center.dart';
import 'package:system_shell/shell/settings_store.dart';
import 'package:system_shell/shell/shortcuts.dart';
import 'package:system_shell/shell/window_switcher.dart';

import 'app_icon.dart';
import 'autostart.dart';
import 'desktop_entries.dart';
import 'dock.dart';
import 'notifications_server.dart';
import 'opener.dart';
import 'surfaces.dart';
import 'toplevels.dart';

/// O que a sobreposição mostra; só uma coisa por vez, como no system_shell.
enum ShellOverlay { launcher, notifications, network, volume, battery, power }

/// Ações de energia que pedem confirmação.
enum PowerAction { powerOff, reboot }

class ShellState {
  ShellState({
    required this.settings,
    required this.services,
    required this.toplevels,
    DockStore? dock,
    this.surfaces = const Surfaces(),
    this.osdDuration = const Duration(milliseconds: 1500),
    this.sandbox,
    this.autostart,
  }) : dock = dock ?? DockStore.memory(defaultDock) {
    overlay.addListener(_syncOverlay);
    confirm.addListener(_syncOverlay);
    switcher.addListener(_syncOverlay);
    dockUi.drag.addListener(_syncOverlay);
    dockUi.menu.addListener(_syncOverlay);
    notifications.addListener(_syncToasts);
    osd.addListener(() => _setShown(Surface.osd, osd.value));
  }

  final SettingsStore settings;
  final SystemServices services;
  final ToplevelList toplevels;

  /// Os itens fixados na dock (o dock.json).
  final DockStore dock;

  /// O arrastar e o menu da dock.
  late final dockUi = DockController(this);

  /// O autostart do XDG. Null: sem o "Abrir ao iniciar a sessão" (testes).
  final Autostart? autostart;

  /// Abre arquivos no app padrão (o do `org.psito.Launcher`).
  Future<void> Function(List<String> paths)? openPaths;
  final Surfaces surfaces;

  /// O `psito-sandbox` em que os apps do Psito abrem. Null abre sem sandbox.
  final String? sandbox;

  static const sandboxPath = '/usr/bin/psito-sandbox';

  /// O sandbox, se estiver instalado e o `PSITO_SANDBOX` não for `0` (para
  /// medir sem ele).
  static String? sandboxFor(Map<String, String> env) =>
      env['PSITO_SANDBOX'] != '0' && File(sandboxPath).existsSync()
      ? sandboxPath
      : null;

  /// Se o app pode gravar as configurações: os do Psito só com a permissão
  /// `settings` no manifesto. Quem não é um app do Psito instalado (o shell,
  /// um terminal, um app de fora) pode.
  bool maySetSettings(String? appId) {
    if (appId == null) return true;
    for (final app in apps.value) {
      if (app.id == appId && app.psitoApp != null) {
        return app.permissions.contains('settings');
      }
    }
    return true;
  }

  late final notifications = NotificationCenter(
    silent: () => settings.value.doNotDisturb,
    onRemoved: (id, reason) => onNotificationRemoved?.call(id, reason),
  );

  /// O servidor de notificações avisa quem notificou.
  void Function(int id, NotificationRemoval reason)? onNotificationRemoved;
  void Function(int id)? onNotificationTapped;

  /// O Alt+Tab do Psito, sobre as janelas do compositor.
  final switcher = WindowSwitcher();

  /// O aviso de volume, acima da dock.
  final osd = ValueNotifier<bool>(false);
  final Duration osdDuration;
  Timer? _osdTimer;

  static const _volumeStep = 0.05;

  /// Os apps de fora, dos `.desktop`.
  final apps = ValueNotifier<List<DesktopEntry>>(const []);

  /// A dock da primeira vez, por id do `.desktop`. Os que não estão
  /// instalados não aparecem.
  static const defaultDock = [
    DockApp('firefox-esr'),
    DockApp('foot'),
    DockApp('org.psito.files'),
    DockApp('org.psito.notepad'),
    DockApp('org.psito.calculator'),
    DockApp('org.psito.clock'),
    DockApp('org.psito.settings'),
  ];

  final overlay = ValueNotifier<ShellOverlay?>(null);
  final confirm = ValueNotifier<PowerAction?>(null);

  Future<void> loadApps(Map<String, String> env) async {
    apps.value = await loadDesktopEntries(
      desktopEntryDirs(env),
      locale: env['LANG'],
    );
  }

  /// Carrega os apps e recarrega quando um pacote põe ou tira um `.desktop`:
  /// um app instalado com o apt aparece sem reiniciar o shell. Os eventos de
  /// uma instalação vêm em rajada, então espera [appsReloadDelay].
  Future<void> watchApps(Map<String, String> env) async {
    final dirs = desktopEntryDirs(env);
    // A pasta do usuário pode ainda não existir, e o watch precisa dela
    await Directory(dirs.first).create(recursive: true);
    Timer? pending;
    for (final path in dirs) {
      final dir = Directory(path);
      if (!await dir.exists()) continue;
      dir.watch().listen((_) {
        pending?.cancel();
        pending = Timer(appsReloadDelay, () => unawaited(loadApps(env)));
      }, onError: (Object e) => debugPrint('🦜 shell: sem vigiar $path ($e)'));
    }
    await loadApps(env);
  }

  static const appsReloadDelay = Duration(milliseconds: 500);

  /// Abrir uma camada fecha a que estiver aberta; abrir a mesma fecha.
  void toggle(ShellOverlay value) {
    dockUi.closeMenu();
    overlay.value = overlay.value == value ? null : value;
    if (overlay.value == ShellOverlay.notifications) {
      notifications.markAllRead();
    }
  }

  void closeOverlay() => overlay.value = null;

  void askPower(PowerAction action) {
    closeOverlay();
    confirm.value = action;
  }

  void runPower(PowerAction action) {
    confirm.value = null;
    switch (action) {
      case PowerAction.powerOff:
        services.session.powerOff();
      case PowerAction.reboot:
        services.session.reboot();
    }
  }

  DockLayout<DesktopEntry, Toplevel> get dockSections => dockLayout(
    items: dock.value,
    apps: {for (final app in apps.value) app.id: app},
    windows: toplevels.windows,
  );

  void tapDock(DockSlot slot) {
    switch (tapAction(slot)) {
      case LaunchApp(:final app):
        unawaited(app.launch(sandbox: sandbox));
      case ActivateWindow(:final window):
        unawaited(toplevels.activate(window.id));
      case MinimizeWindow(:final window):
        unawaited(toplevels.minimize(window.id));
      case null:
        break;
    }
  }

  /// Abre o autostart, uma vez por sessão.
  Future<void> runAutostart() async {
    final ran = await autostart?.runOnce(
      (entry) => (installed(entry.id) ?? entry).launch(sandbox: sandbox),
    );
    if (ran != null && ran.isNotEmpty) {
      debugPrint('🦜 shell: autostart ${ran.join(', ')}');
    }
  }

  void launch(DesktopEntry entry) {
    closeOverlay();
    unawaited(entry.launch(sandbox: sandbox));
  }

  /// Abre um app com os arquivos (o plano do [Opener]). Cada instância só
  /// recebe montados os arquivos que ela abre.
  Future<void> launchPlan(OpenPlan plan) async {
    for (final command in plan.commands) {
      await plan.app.launch(
        sandbox: sandbox,
        command: command,
        files: [
          for (final file in plan.files)
            if (command.any((arg) => arg.contains(file.$2))) file,
        ],
      );
    }
  }

  /// Uma ação pedida pelo compositor (os atalhos que a ponte gerou).
  void run(ShellAction action) {
    switch (action) {
      case ShellAction.launcher:
        switcher.cancel();
        toggle(ShellOverlay.launcher);
      case ShellAction.switchNext:
        _switch(reverse: false);
      case ShellAction.switchPrev:
        _switch(reverse: true);
      case ShellAction.volumeUp:
        _stepVolume(1);
      case ShellAction.volumeDown:
        _stepVolume(-1);
      case ShellAction.volumeMute:
        final audio = services.audio;
        if (!audio.state.value.available) return;
        audio.setMuted(!audio.state.value.muted);
        _showOsd();
      case ShellAction.closeWindow ||
          ShellAction.maximize ||
          ShellAction.snapLeft ||
          ShellAction.snapRight ||
          ShellAction.minimize:
        // São do compositor; a ponte não manda para o shell
        break;
    }
  }

  // Seletor de janelas

  /// O primeiro atalho abre; os seguintes, com o modificador ainda
  /// segurado, avançam. O compositor consome o Tab, então cada um chega
  /// aqui como um `Run`.
  void _switch({required bool reverse}) {
    if (switcher.isOpen) {
      switcher.step(reverse: reverse);
      return;
    }
    closeOverlay();
    confirm.value = null;
    switcher.start(
      [
        for (final w in toplevels.windows)
          SwitcherEntry(
            id: '${w.id}',
            title: w.title,
            minimized: w.minimized,
            app: appFor(w.appId),
          ),
      ],
      // Não dá para saber qual modificador veio com o Tab: soltar Ctrl ou
      // Alt confirma
      holdKeys: {
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.controlRight,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.altRight,
      },
      focusedId: switch (toplevels.activated) {
        final w? => '${w.id}',
        null => null,
      },
      reverse: reverse,
    );
  }

  /// O teclado com o seletor aberto (a sobreposição tem o teclado todo).
  /// Se o compositor deixar o Tab passar, ele avança aqui.
  bool handleKey(KeyEvent event, {bool shift = false}) {
    if (!switcher.isOpen) return false;
    if (event is KeyUpEvent) {
      if (switcher.releases(event.logicalKey)) commitSwitcher();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      switcher.cancel();
    } else if (event.logicalKey == LogicalKeyboardKey.tab) {
      switcher.step(reverse: shift);
    }
    return true;
  }

  void commitSwitcher() {
    if (switcher.commit() case final id?) {
      unawaited(toplevels.activate(int.parse(id)));
    }
  }

  void pickSwitcher(String id) {
    switcher.cancel();
    unawaited(toplevels.activate(int.parse(id)));
  }

  // Volume

  void _stepVolume(int direction) {
    final audio = services.audio;
    final s = audio.state.value;
    if (!s.available) return;
    audio.setVolume((s.volume + direction * _volumeStep).clamp(0.0, 1.0));
    _showOsd();
  }

  void _showOsd() {
    osd.value = true;
    _osdTimer?.cancel();
    _osdTimer = Timer(osdDuration, () => osd.value = false);
  }

  // Notificações

  /// O app de uma janela ou de uma notificação, com o ícone do `.desktop`.
  AppEntry appFor(String id, {String? name, String? icon}) {
    final desktop = _desktopEntry(id);
    return appEntry(
      desktop?.id ?? id,
      desktop?.name ?? name ?? id,
      desktop,
      settings.value.accent,
      icon: icon,
    );
  }

  /// O app instalado com o id do `.desktop`.
  DesktopEntry? installed(String id) {
    for (final app in apps.value) {
      if (app.id == id) return app;
    }
    return null;
  }

  DesktopEntry? _desktopEntry(String idOrName) {
    final lower = idOrName.toLowerCase();
    for (final app in apps.value) {
      if (app.id == idOrName) return app;
    }
    for (final app in apps.value) {
      if (app.id.toLowerCase() == lower || app.name.toLowerCase() == lower) {
        return app;
      }
    }
    return null;
  }

  /// O `Notify` do D-Bus. Devolve o id no centro.
  int notify(IncomingNotification n) {
    final name = n.appName.isEmpty ? 'Notificação' : n.appName;
    return notifications.add(
      app: appFor(
        n.desktopEntry ?? name,
        name: name,
        icon: n.appIcon.isEmpty ? null : _iconName(n.appIcon),
      ),
      title: n.summary,
      body: n.body.isEmpty ? null : n.body,
      replaces: n.replaces,
    );
  }

  /// O `app_icon` pode vir como `file://`.
  static String _iconName(String icon) =>
      icon.startsWith('file://') ? Uri.parse(icon).toFilePath() : icon;

  /// Clique no toast ou no painel: traz o app para frente, ou abre.
  void openNotification(ShellNotification n) {
    closeOverlay();
    onNotificationTapped?.call(n.id);
    final windows = [
      for (final w in toplevels.windows)
        if (w.appId == n.appId) w,
    ];
    if (windows.isNotEmpty) {
      unawaited(toplevels.activate(windows.last.id));
    } else if (_desktopEntry(n.appId) case final entry?) {
      unawaited(entry.launch(sandbox: sandbox));
    }
  }

  // Superfícies

  final _shown = <Surface, bool>{};

  void _setShown(Surface surface, bool shown) {
    if (_shown[surface] == shown) return;
    _shown[surface] = shown;
    unawaited(shown ? surfaces.show(surface) : surfaces.hide(surface));
  }

  void _syncToasts() =>
      _setShown(Surface.toasts, notifications.toasts.isNotEmpty);

  /// A superfície da sobreposição existe só enquanto tem algo aberto.
  // O ícone arrastado do launcher continua com o ponteiro da sobreposição;
  // o da dock só é desenhado nela
  void _syncOverlay() {
    final drag = dockUi.drag.value;
    if (confirm.value != null ||
        overlay.value == ShellOverlay.launcher ||
        switcher.isOpen ||
        drag?.source == DockDragSource.launcher) {
      unawaited(surfaces.showOverlay(OverlayKeyboard.exclusive));
    } else if (overlay.value != null || dockUi.menu.value != null) {
      unawaited(surfaces.showOverlay(OverlayKeyboard.onDemand));
    } else if (drag != null) {
      unawaited(surfaces.showOverlay(OverlayKeyboard.passive));
    } else {
      unawaited(surfaces.hideOverlay());
    }
  }
}
