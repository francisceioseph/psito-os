// packages/psito_runtime/lib/src/run.dart
//
// runPsitoApp: o main de um app do Psito. O runner do app (o modelo do
// Flutter Linux) define o app_id org.psito.<id> pelo APPLICATION_ID, e o
// plugin deste pacote cuida da janela.
import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/network_service.dart';
import 'package:psito_services/settings_client.dart';
import 'package:psito_services/system_info_service.dart';
import 'package:psito_services/time_service.dart';

import 'app_context.dart';
import 'notifier.dart';
import 'window.dart';

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

Future<void> runPsitoApp(PsitoApp app) async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) =>
      debugPrint('🦜 erro: ${details.exceptionAsString()}\n${details.stack}');
  final session = DBusClient.session();
  final settings = SettingsClient(session);
  const window = AppWindow();
  final notifier = Notifier(
    session,
    appName: app.name,
    desktopEntry: await window.applicationId() ?? 'org.psito.${app.id}',
  );
  final context = ProcessAppContext(
    app: app,
    settings: settings,
    services: startServices(Platform.environment),
    onUpdateSettings: (s) => unawaited(settings.update(s)),
    onNotify: (n) => unawaited(notifier.notify(n)),
    window: window,
    windowId: '${app.id}#$pid',
  );
  await context.window.setTitle(app.name);
  await context.window.setSize(app.defaultSize);
  runApp(PsitoAppHost(app: app, context: context));
  app.onOpen(context);
  unawaited(logFirstFrame());
}

/// Registra no journal quando o primeiro quadro chega à tela, em
/// milissegundos de época: o tools/measure-apps.sh mede o tempo de abrir a
/// partir daí. É medição, não hora mostrada, então o DateTime.now() serve (a
/// época não depende do fuso).
Future<void> logFirstFrame() async {
  await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
  debugPrint('🦜 primeiro quadro: ${DateTime.now().millisecondsSinceEpoch}');
}

/// O app com o tema do Psito, que acompanha a cor de destaque.
class PsitoAppHost extends StatelessWidget {
  final PsitoApp app;
  final PsitoAppContext context;

  const PsitoAppHost({super.key, required this.app, required this.context});

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
