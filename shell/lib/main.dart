// shell/lib/main.dart
//
// O shell do Psito como cliente layer-shell do labwc. O runner
// cria uma superfície por parte do shell; aqui cada uma ganha a sua view, com
// os widgets e os serviços do system_shell.
import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/widgets.dart';
import 'package:psito_fs/psito_fs.dart';
import 'package:psito_services/system_services.dart';
import 'package:system_shell/shell/settings_store.dart';

import 'bridge/bridge.dart';
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
  final state = ShellState(
    settings: settings,
    services: SystemServices.start(),
    toplevels: ToplevelList(),
    sandbox: ShellState.sandboxFor(Platform.environment),
  );
  final viewIds = await state.surfaces.viewIds();
  runWidget(ShellViews(state: state, viewIds: viewIds));

  unawaited(state.toplevels.start());
  unawaited(state.watchApps(Platform.environment));
  Bridge(settings).start();

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
  final env = Platform.environment;
  try {
    final launcherBus = DBusClient.session();
    await publishLauncher(
      launcherBus,
      LauncherBusObject(
        opener: Opener(
          env: env,
          mime: MimeDatabase.load(MimeDatabase.dirsFor(env)),
          sandbox: state.sandbox,
          apps: () => state.apps.value,
        ),
        callerOf: (sender) => senderAppId(launcherBus, sender),
        isConnected: launcherBus.nameHasOwner,
        launch: state.launchPlan,
        setDefault: (mime, appId) =>
            MimeApps.setDefault(MimeApps.userFile(env), mime, appId),
      ),
    );
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
