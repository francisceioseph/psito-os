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
import 'package:psito_runtime/psito_runtime.dart';
import 'package:psito_services/system_services.dart';
import 'package:system_shell/shell/settings_store.dart';

import 'autostart.dart';
import 'bridge/bridge.dart';
import 'desk.dart';
import 'displays.dart';
import 'displays_bus.dart';
import 'launcher_bus.dart';
import 'volumes_bus.dart';
import 'notifications_server.dart';
import 'opener.dart';
import 'polkit_agent.dart';
import 'settings_bus.dart';
import 'storage_bus.dart';
import 'media_keys.dart';
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
    mediaKeys: MediaKeys(DBusClient.session()),
  );
  state.clipboardKeeper.listen(state.clipboard);
  final viewIds = await state.surfaces.viewIds();
  await state.surfaces.start();
  final displays = Displays(
    surfaces: state.surfaces,
    store: await MonitorStore.load(defaultMonitorsFile()),
    confirm: state.displaysConfirm,
  );
  await displays.start();
  state.applyDockSettings();
  runWidget(ShellViews(state: state, viewIds: viewIds));

  unawaited(state.toplevels.start());
  // O autostart precisa dos apps instalados, para abrir os do Psito no
  // sandbox
  unawaited(
    state.watchApps(Platform.environment).then((_) => state.runAutostart()),
  );
  Bridge(settings).start();
  state.watchLocking();

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
  state.dockUi.appAccepts = opener.accepts;
  state.appsForType = opener.appsFor;
  state.dockUi.trash = Trash.forEnv(env, now: state.services.time.now)
    ..mounts = () => [
      for (final volume in state.services.disks.volumes.value)
        ?volume.mountPoint,
    ];
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
    await publishShell(
      ShellBusObject(onRun: state.run),
    );
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
    PsitoDnd.instance.onOffer = launcher.offerDrag;
    await publishLauncher(launcherBus, launcher);
  } on Exception catch (e) {
    debugPrint('🦜 shell: sem o org.psito.Launcher ($e)');
  }
  try {
    await publishVolumes(
      DBusClient.session(),
      VolumesBusObject(state.services.disks),
    );
  } on Exception catch (e) {
    debugPrint('🦜 shell: sem o org.psito.Volumes ($e)');
  }
  try {
    final storageBus = DBusClient.session();
    await publishStorage(
      storageBus,
      StorageBusObject(
        state.storage,
        mayChange: (sender) async =>
            state.maySetSettings(await senderAppId(storageBus, sender)),
      ),
    );
  } on Exception catch (e) {
    debugPrint('🦜 shell: sem o org.psito.Storage ($e)');
  }
  try {
    final displaysBus = DBusClient.session();
    await publishDisplays(
      displaysBus,
      DisplaysBusObject(
        displays,
        mayChange: (sender) async =>
            state.maySetSettings(await senderAppId(displaysBus, sender)),
      ),
    );
  } on Exception catch (e) {
    debugPrint('🦜 shell: sem o org.psito.Displays ($e)');
  }
  state.watchDiskSpace();
  unawaited(_publishPolkit(state, settings));
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

/// O agente do polkit. Sem ele as ações que pedem senha só são recusadas, e o
/// resto do shell não muda.
Future<void> _publishPolkit(ShellState state, SettingsStore settings) async {
  String locale() =>
      polkitLocale(settings.value.language, Platform.environment['LANG'] ?? '');
  try {
    final registration = await PolkitRegistration.publish(
      DBusClient.system(),
      state.polkit,
      locale(),
    );
    settings.addListener(() {
      unawaited(
        registration.setLocale(locale()).catchError((Object e) {
          debugPrint('🦜 polkit: sem trocar o idioma ($e)');
        }),
      );
    });
    debugPrint('🦜 polkit: agente registrado');
  } on Exception catch (e) {
    debugPrint('🦜 polkit: sem o agente ($e)');
  }
}
