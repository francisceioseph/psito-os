// shell/lib/shell_state.dart
//
// O estado do shell, um só para todas as superfícies: as views da top bar,
// da dock e da sobreposição leem e mudam este mesmo objeto.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter/services.dart';
import 'package:psito_dock/psito_dock.dart';
import 'package:psito_files_ui/psito_files_ui.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/system_services.dart';
import 'package:system_shell/shell/app_entry.dart';
import 'package:system_shell/shell/clipboard_history.dart';
import 'package:system_shell/shell/notification_center.dart';
import 'package:system_shell/shell/settings_store.dart';
import 'package:system_shell/widgets/transfer_indicator.dart';
import 'package:system_shell/shell/shortcuts.dart';
import 'package:system_shell/shell/window_switcher.dart';

import 'app_icon.dart';
import 'l10n/shell_localizations.dart';
import 'autostart.dart';
import 'clipboard_keeper.dart';
import 'desk.dart';
import 'desktop_entries.dart';
import 'idle.dart';
import 'dock.dart';
import 'notifications_server.dart';
import 'opener.dart';
import 'polkit_agent.dart';
import 'surfaces.dart';
import 'toplevels.dart';

/// O que a sobreposição mostra; só uma coisa por vez, como no system_shell.
enum ShellOverlay {
  launcher,
  notifications,
  network,
  volume,
  battery,
  power,
  clipboard,
}

/// Ações de energia que pedem confirmação.
enum PowerAction { powerOff, reboot }

class ShellState {
  Locale get locale => resolvePsitoLocale(settings.value.language);

  /// Os textos do shell, para o que não tem um `BuildContext`.
  ShellLocalizations get l10n => lookupShellLocalizations(locale);

  FilesUiLocalizations get filesUi => lookupFilesUiLocalizations(locale);

  ShellState({
    required this.settings,
    required this.services,
    required this.toplevels,
    DockStore? dock,
    this.surfaces = const Surfaces(),
    this.osdDuration = const Duration(milliseconds: 1500),
    this.sandbox,
    this.autostart,
    this.clipboardKeeper = const ClipboardKeeper(),
  }) : dock = dock ?? DockStore.memory(defaultDock) {
    overlay.addListener(_syncOverlay);
    confirm.addListener(_syncOverlay);
    switcher.addListener(_syncOverlay);
    dockUi.drag.addListener(_syncOverlay);
    dockUi.menu.addListener(_syncOverlay);
    dockUi.stack.addListener(_syncOverlay);
    dockUi.askEmptyTrash.addListener(_syncOverlay);
    deskMenu.addListener(_syncOverlay);
    deskTrust.addListener(_syncOverlay);
    polkit.current.addListener(_syncOverlay);
    // O que segura a dock na tela, com o ocultar sozinha
    for (final listenable in [
      dockUi.hovered,
      dockUi.drag,
      dockUi.menu,
      dockUi.stack,
      dockUi.askEmptyTrash,
    ]) {
      listenable.addListener(dockUi.syncAutoHide);
    }
    settings.addListener(_dockSettingsChanged);
    _language = settings.value.language;
    DesktopEntry.language = _language;
    settings.addListener(_languageChanged);
    // A faixa de dentro entra e sai da região de input com o ponteiro
    dockUi.hovered.addListener(() {
      if (dockUi.surface.isEmpty || !dockUi.revealed.value) return;
      unawaited(
        surfaces.resize(
          Surface.dock,
          dockUi.surface,
          input: dockUi.inputInsets,
        ),
      );
    });
    notifications.addListener(_syncToasts);
    toplevels.addListener(_windowsChanged);
    osd.addListener(() => _setShown(Surface.osd, osd.value));
  }

  final SettingsStore settings;
  final SystemServices services;
  final ToplevelList toplevels;

  final ClipboardKeeper clipboardKeeper;

  /// As últimas cópias de qualquer app.
  late final clipboard = ClipboardHistory(
    now: services.time.now,
    offer: (formats) => unawaited(clipboardKeeper.offer(formats)),
    clearSystem: () => unawaited(clipboardKeeper.clear()),
  );

  /// O item que um atalho acabou de copiar de novo, no lugar do volume no OSD.
  final osdClip = ValueNotifier<ClipEntry?>(null);

  /// Os itens fixados na dock (o dock.json).
  final DockStore dock;

  /// O arrastar e o menu da dock.
  late final dockUi = DockController(this);

  /// A mesa. Null até o main carregar os tipos MIME, depois do primeiro
  /// quadro.
  final desk = ValueNotifier<DeskController?>(null);

  /// O que a mesa está copiando ou movendo, que a top bar desenha.
  final deskTransfer = ValueNotifier<TransferStatus?>(null);

  /// O menu da mesa, que a sobreposição desenha.
  final deskMenu = ValueNotifier<DeskMenuRequest?>(null);

  /// A pergunta de um atalho não confiável.
  final deskTrust = ValueNotifier<DeskTrustRequest?>(null);

  /// O agente do polkit: os pedidos de senha de administrador.
  final polkit = PolkitAgent();

  /// O autostart do XDG. Null: sem o "Abrir ao iniciar a sessão" (testes).
  final Autostart? autostart;

  /// Abre arquivos no app padrão, ou em [withApp] (o do
  /// `org.psito.Launcher`).
  Future<void> Function(List<String> paths, {String? withApp})? openPaths;

  /// Abre o caminho no Quick Look do Files.
  Future<void> Function(String path)? previewPath;

  /// Os apps que abrem o tipo, o padrão primeiro; com `''`, todos os que
  /// recebem arquivos.
  List<DesktopEntry> Function(String mimeType)? appsForType;
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

  /// O idioma dos `.desktop`: o `LANG` diz a variante (`pt_BR`), se for o do
  /// idioma em uso.
  String get entriesLocale {
    final code = locale.languageCode;
    final lang = Platform.environment['LANG'];
    return lang?.startsWith(code) ?? false ? lang! : code;
  }

  Future<void> loadApps(Map<String, String> env) async {
    apps.value = await loadDesktopEntries(
      desktopEntryDirs(env),
      locale: entriesLocale,
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

  (PsitoDockPosition, int)? _dockPlacement;

  /// A borda e a reserva da dock seguem as configurações. O main chama na
  /// subida; depois, a cada mudança.
  void applyDockSettings() {
    final placement = (settings.value.dockPosition, dockUi.exclusiveZone);
    if (placement != _dockPlacement) {
      _dockPlacement = placement;
      unawaited(surfaces.dock(placement.$1, placement.$2));
    }
    dockUi.syncAutoHide();
  }

  void _dockSettingsChanged() => applyDockSettings();

  /// Sobe a tela de bloqueio, e só volta com a tela já bloqueada (o `READY=1`
  /// da unidade). Com ela de pé, não faz nada.
  @visibleForTesting
  Future<void> Function() startLock = _startLockUnit;

  Future<void> lockSession() async {
    closeOverlay();
    polkit.cancelAll();
    await startLock();
  }

  static Future<void> _startLockUnit() async {
    try {
      // Depois de muitas quedas seguidas o systemd recusaria o start
      await Process.run('systemctl', [
        '--user',
        'reset-failed',
        'psito-lock.service',
      ]);
      final result = await Process.run('systemctl', [
        '--user',
        'start',
        'psito-lock.service',
      ]);
      if (result.exitCode != 0) {
        debugPrint('🦜 bloqueio não subiu: ${result.stderr}');
      }
    } on ProcessException catch (e) {
      debugPrint('🦜 bloqueio não subiu: $e');
    }
  }

  /// O bloqueio por inatividade e o de antes de suspender.
  void watchLocking() {
    idle.onIdle = () => unawaited(lockSession());
    unawaited(idle.setMinutes(settings.value.lockAfterMinutes));
    settings.addListener(
      () => unawaited(idle.setMinutes(settings.value.lockAfterMinutes)),
    );
    services.session.watchLock(
      beforeSleep: lockSession,
      onLock: () => unawaited(lockSession()),
    );
  }

  final idle = IdleWatcher();

  String _language = '';

  /// Os nomes dos apps vêm dos `.desktop`, já no idioma.
  void _languageChanged() {
    final language = settings.value.language;
    if (language == _language) return;
    _language = language;
    DesktopEntry.language = language;
    unawaited(loadApps(Platform.environment));
  }

  /// Abrir uma camada fecha a que estiver aberta; abrir a mesma fecha.
  void toggle(ShellOverlay value) {
    dockUi.closePopups();
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
    exists: (path) =>
        FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound,
  );

  void tapDock(DockSlot slot) {
    switch (tapAction(slot)) {
      case LaunchApp(:final app):
        launchFromDock(app);
      case ActivateWindow(:final window):
        unawaited(toplevels.activate(window.id));
      case MinimizeWindow(:final window):
        unawaited(toplevels.minimize(window.id));
      case ShowWindows(:final windows):
        showWindows(windows);
      case null:
        break;
    }
  }

  /// Abre pela dock, com o ícone pulando até a janela aparecer. [command]
  /// é o de uma ação do `.desktop`.
  void launchFromDock(DesktopEntry app, {List<String>? command}) {
    dockUi.startBounce(app.id);
    unawaited(app.launch(sandbox: sandbox, command: command));
  }

  /// O seletor só com [windows] (as de um app): fica aberto até um clique,
  /// o Enter ou o Esc, sem modificador segurado.
  void showWindows(List<Toplevel> windows) {
    closeOverlay();
    dockUi.closePopups();
    switcher.start(
      [
        for (final w in windows)
          SwitcherEntry(
            id: '${w.id}',
            title: w.title,
            minimized: w.minimized,
            app: appFor(w.appId),
          ),
      ],
      holdKeys: const {},
      focusedId: switch (toplevels.activated) {
        final w? => '${w.id}',
        null => null,
      },
    );
  }

  /// Uma janela nova pode encerrar o pulo, e o app que veio para frente lê
  /// as notificações dele.
  void _windowsChanged() {
    dockUi.windowsChanged();
    _forgetHiddenWindows();
    if (toplevels.activated case final window?) {
      notifications.markRead(appFor(window.appId).id);
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
      case ShellAction.clipboard:
        switcher.cancel();
        toggle(ShellOverlay.clipboard);
      case ShellAction.clipboard1 ||
          ShellAction.clipboard2 ||
          ShellAction.clipboard3 ||
          ShellAction.clipboard4 ||
          ShellAction.clipboard5:
        recopy(clipboardSlots.indexOf(action));
      case ShellAction.showDesktop:
        toggleDesktop();
      case ShellAction.lock:
        unawaited(lockSession());
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

  // Mostrar a área de trabalho

  /// O que o "Mostrar a área de trabalho" minimizou, na ordem do foco.
  List<int>? _hiddenWindows;

  /// As que ainda não avisaram que minimizaram.
  final _hiding = <int>{};

  /// Minimiza as janelas, e da próxima vez traz de volta as mesmas: as que já
  /// estavam minimizadas ficam.
  void toggleDesktop() {
    closeOverlay();
    switcher.cancel();
    final hidden = _hiddenWindows;
    if (hidden != null) {
      _hiddenWindows = null;
      _hiding.clear();
      final open = {for (final window in toplevels.windows) window.id};
      // A última a ativar é a que tinha o foco, e fica por cima
      for (final id in hidden.where(open.contains)) {
        unawaited(toplevels.activate(id));
      }
      return;
    }
    final visible = [
      for (final window in toplevels.windows)
        if (!window.minimized) window.id,
    ];
    if (visible.isEmpty) return;
    _hiddenWindows = visible;
    _hiding.addAll(visible);
    for (final id in visible) {
      unawaited(toplevels.minimize(id));
    }
  }

  // Uma janela aberta ou ativada nesse meio: a lista não vale mais
  void _forgetHiddenWindows() {
    if (_hiddenWindows == null) return;
    final windows = toplevels.windows;
    final open = {for (final window in windows) window.id};
    _hiding.removeWhere((id) => !open.contains(id));
    for (final window in windows) {
      if (window.minimized) {
        _hiding.remove(window.id);
      } else if (!_hiding.contains(window.id)) {
        _hiddenWindows = null;
        _hiding.clear();
        return;
      }
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
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      commitSwitcher();
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

  /// Copia de novo o item [index] do histórico, com o aviso na tela.
  void recopy(int index) {
    final entry = clipboard.recopy(index);
    if (entry == null) return;
    osdClip.value = entry;
    osd.value = true;
    _osdTimer?.cancel();
    _osdTimer = Timer(osdDuration, () {
      osd.value = false;
      osdClip.value = null;
    });
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
    osdClip.value = null;
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
    final name = n.appName.isEmpty ? l10n.notification : n.appName;
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
    if (polkit.current.value != null ||
        confirm.value != null ||
        dockUi.askEmptyTrash.value ||
        deskTrust.value != null ||
        overlay.value == ShellOverlay.launcher ||
        // Com o teclado, os números escolhem; fechando, o foco volta para a
        // janela em que se vai colar
        overlay.value == ShellOverlay.clipboard ||
        switcher.isOpen ||
        drag?.source == DockDragSource.launcher) {
      unawaited(surfaces.showOverlay(OverlayKeyboard.exclusive));
    } else if (overlay.value != null ||
        dockUi.menu.value != null ||
        dockUi.stack.value != null) {
      unawaited(surfaces.showOverlay(OverlayKeyboard.onDemand));
    } else if (deskMenu.value != null) {
      unawaited(surfaces.showOverlay(OverlayKeyboard.pointer));
    } else if (drag != null) {
      unawaited(surfaces.showOverlay(OverlayKeyboard.passive));
    } else {
      unawaited(surfaces.hideOverlay());
    }
  }
}
