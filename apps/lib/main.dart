// apps/lib/main.dart
//
// O host dos apps do Psito: `psito_apps <id>` roda um PsitoApp do
// system_shell numa janela comum do compositor, com o app_id
// org.psito.<id> (o runner) e o .desktop de apps/desktop/. Cada app é um
// processo: cair um não afeta o shell nem os outros.
import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/app.dart';
import 'package:system_shell/services/network_service.dart';
import 'package:system_shell/services/system_info_service.dart';
import 'package:system_shell/services/time_service.dart';
import 'package:system_shell/shell/app_registry.dart';
import 'package:system_shell/shell/settings_store.dart';

import 'app_context.dart';
import 'notifier.dart';

/// O app do registro com esse id, ou null.
PsitoApp? appById(String id) {
  for (final app in registeredApps) {
    if (app.id == id) return app;
  }
  return null;
}

/// Os serviços reais pelo barramento de sistema, ou os falsos com
/// PSITO_SERVICES=fake (como no shell).
AppServices startServices(Map<String, String> env) {
  if (env['PSITO_SERVICES'] == 'fake') {
    return AppServices(
      systemInfo: FakeSystemInfoService(),
      network: FakeNetworkService(),
      time: FakeTimeService(),
    );
  }
  final bus = DBusClient.system();
  return AppServices(
    systemInfo: HostnamedSystemInfoService(bus),
    network: NetworkManagerService(bus),
    time: TimedatedTimeService(bus),
  );
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) =>
      debugPrint('🦜 erro: ${details.exceptionAsString()}\n${details.stack}');
  final app = args.isEmpty ? null : appById(args.first);
  if (app == null) {
    stderr.writeln(
      'Uso: psito_apps <id>, com id: '
      '${registeredApps.map((a) => a.id).join(', ')}',
    );
    exit(2);
  }

  final store = await SettingsStore.load(defaultSettingsFile());
  unawaited(store.watch());
  final notifier = Notifier(
    DBusClient.session(),
    appName: app.name,
    desktopEntry: 'org.psito.${app.id}',
  );
  final context = ProcessAppContext(
    app: app,
    store: store,
    services: startServices(Platform.environment),
    onNotify: (n) => unawaited(notifier.notify(n)),
    windowId: '${app.id}#$pid',
  );
  await context.window.setTitle(app.name);
  await context.window.setSize(app.defaultSize);
  runApp(AppHost(app: app, context: context));
  app.onOpen(context);
}

/// O app com o tema do Psito, que acompanha a cor de destaque.
class AppHost extends StatelessWidget {
  final PsitoApp app;
  final ProcessAppContext context;

  const AppHost({super.key, required this.app, required this.context});

  @override
  Widget build(BuildContext _) => ValueListenableBuilder(
    valueListenable: context.settings,
    builder: (_, settings, _) => MaterialApp(
      title: app.name,
      debugShowCheckedModeBanner: false,
      theme: psitoTheme(settings.accent),
      home: Scaffold(body: app.build(context)),
    ),
  );
}
