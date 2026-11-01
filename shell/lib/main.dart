// shell/lib/main.dart
//
// O shell do Psito como cliente layer-shell do labwc. O runner
// cria uma superfície por parte do shell; aqui cada uma ganha a sua view, com
// os widgets e os serviços do system_shell.
import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/widgets.dart';
import 'package:psito_desktop/psito_desktop.dart';
import 'package:psito_dock/psito_dock.dart';
import 'package:psito_fs/psito_fs.dart';
import 'package:psito_services/system_services.dart';
import 'package:system_shell/shell/settings_store.dart';

import 'autostart.dart';
import 'bridge/bridge.dart';
import 'desk.dart';
import 'launcher_bus.dart';
import 'notifications_server.dart';
import 'opener.dart';
import 'settings_bus.dart';
import 'shell_bus.dart';
import 'shell_state.dart';
import 'toplevels.dart';
import 'views.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No release o Flutter não imprime os erros; aqui eles vão para o journal
  FlutterError.onError = (details) =>
      debugPrint('🦜 erro: ${details.exceptionAsString()}\n${details.stack}');
  final settings = await SettingsStore.load(defaultSettingsFile());
  // Quem edita o arquivo à mão (ou um shell de outra sessão) também conta
  unawaited(settings.watch());
  final dock = await DockStore.load(
    defaultDockFile(),
    initial: ShellState.defaultDock,
  );
  unawaited(dock.watch());
  final state = ShellState(
    settings: settings,
    services: SystemServices.start(),
    toplevels: ToplevelList(),
    dock: dock,
    sandbox: ShellState.sandboxFor(Platform.environment),
    autostart: Autostart(Platform.environment),
  );
  state.clipboardKeeper.listen(state.clipboard);
  final viewIds = await state.surfaces.viewIds();
  state.applyDockSettings();
  runWidget(ShellViews(state: state, viewIds: viewIds));

  unawaited(state.toplevels.start());
  // O autostart precisa dos apps instalados, para abrir os do Psito no
  // sandbox
  unawaited(
    state.watchApps(Platform.environment).then((_) => state.runAutostart()),
  );
  Bridge(settings).start();

  final env = Platform.environment;
  final mime = MimeDatabase.load(MimeDatabase.dirsFor(env));
  final userDirs = loadUserDirs(env);
  state.dockUi.iconsFor = (item) => switch (item) {
    DockFolder(:final path) => [
      for (final MapEntry(key: dir, value: dirPath) in userDirs.entries)
        if (dirPath == path) dir.icon,
      if (path == env['HOME']) 'user-home',
      'folder',
    ],
    DockFile(:final path) => [
      ...mime.iconNames(mime.typeOf(path)),
      'text-x-generic',
    ],
  };
  final opener = Opener(
    env: env,
    mime: mime,
    sandbox: state.sandbox,
    apps: () => state.apps.value,
  );
  // Um app aceita o que ele abre: o tipo de cada arquivo está entre os dele
  state.dockUi.appAccepts = (appId, paths) => paths.every(
    (path) => opener.appsFor(mime.typeOf(path)).any((app) => app.id == appId),
  );
  state.appsForType = opener.appsFor;
  state.dockUi.trash = Trash.forEnv(env, now: state.services.time.now);
  unawaited(state.dockUi.watchTrash());
  final desk = DeskController(
    state,
    dir: userDirs[UserDir.desktop],
    home: env['HOME'] ?? '/',
    mime: mime,
    store: await DeskStore.load(defaultDeskFile()),
    userDirs: userDirs,
    env: env,
  );
  state.desk.value = desk;
  state.surfaces.onBackgroundFocus(desk.setKeyboard);
  unawaited(desk.start());

  try {
    await publishShell(ShellBusObject(onRun: state.run));
  } on Exception catch (e) {
    debugPrint('🦜 shell: sem o barramento da sessão ($e)');
    return;
  }
  // Uma conexão por nome: o filtro do sandbox decide por conexão
  try {
    final settingsBus = DBusClient.session();
    await publishSettings(
      settingsBus,
      SettingsBusObject(
        settings,
        mayUpdate: (sender) async =>
            state.maySetSettings(await senderAppId(settingsBus, sender)),
      ),
    );
  } on Exception catch (e) {
    debugPrint('🦜 shell: sem o org.psito.Settings ($e)');
  }
  try {
    final launcherBus = DBusClient.session();
    final launcher = LauncherBusObject(
      opener: opener,
      callerOf: (sender) => senderAppId(launcherBus, sender),
      isConnected: launcherBus.nameHasOwner,
      launch: state.launchPlan,
      setDefault: (mime, appId) =>
          MimeApps.setDefault(MimeApps.userFile(env), mime, appId),
    );
    state.openPaths = launcher.openPaths;
    state.previewPath = launcher.preview;
    await publishLauncher(launcherBus, launcher);
  } on Exception catch (e) {
    debugPrint('🦜 shell: sem o org.psito.Launcher ($e)');
  }
  final server = NotificationsServer(
    onNotify: state.notify,
    onClose: state.notifications.close,
  );
  state.onNotificationRemoved = (id, reason) {
    unawaited(server.notifyClosed(id, reason));
  };
  state.onNotificationTapped = (id) {
    unawaited(server.invokeDefault(id));
  };
  try {
    await publishNotifications(DBusClient.session(), server);
  } on Exception catch (e) {
    debugPrint('🦜 shell: sem o servidor de notificações ($e)');
  }
}
