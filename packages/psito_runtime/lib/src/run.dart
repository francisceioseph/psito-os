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
import 'package:psito_services/file_chooser_client.dart';
import 'package:psito_services/launcher_client.dart';
import 'package:psito_services/network_connections.dart';
import 'package:psito_services/network_service.dart';
import 'package:psito_services/settings_client.dart';
import 'package:psito_services/accounts_service.dart';
import 'package:psito_services/system_info_service.dart';
import 'package:psito_services/time_service.dart';

import 'app_context.dart';
import 'dnd.dart';
import 'notifier.dart';
import 'window.dart';

/// Os serviços reais pelo barramento de sistema, ou os falsos com
/// PSITO_SERVICES=fake (como no shell).
AppServices startServices(Map<String, String> env, {LauncherClient? launcher}) {
  if (env['PSITO_SERVICES'] == 'fake') {
    return AppServices(
      systemInfo: FakeSystemInfoService(),
      network: FakeNetworkService(),
      time: FakeTimeService(),
      accounts: FakeAccountsService.new,
      networkConnections: FakeNetworkConnections.new,
    );
  }
  final bus = DBusClient.system();
  return AppServices(
    systemInfo: HostnamedSystemInfoService(bus),
    network: NetworkManagerService(bus),
    time: TimedatedTimeService(bus),
    accounts: () => AccountsdService(bus),
    networkConnections: () =>
        NetworkManagerConnections(bus, importer: launcher?.importVpn),
  );
}

/// [args] são os argumentos do `main` (os arquivos com que o app abriu, pelo
/// `Exec` do `.desktop`). As URLs `file://` (`%u`) viram caminhos.
Future<void> runPsitoApp(PsitoApp app, {List<String> args = const []}) async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) =>
      debugPrint('🦜 erro: ${details.exceptionAsString()}\n${details.stack}');
  final session = DBusClient.session();
  final settings = SettingsClient(session);
  const window = AppWindow();
  final notifier = Notifier(
    session,
    appName: app.localizedName(resolvePsitoLocale(settings.value.language)),
    desktopEntry: await window.applicationId() ?? 'org.psito.${app.id}',
  );
  final launcher = LauncherClient(session);
  PsitoDnd.instance.onOffer = (paths) => unawaited(launcher.offerDrag(paths));
  final context = ProcessAppContext(
    app: app,
    settings: settings,
    services: startServices(Platform.environment, launcher: launcher),
    onUpdateSettings: (s) => unawaited(settings.update(s)),
    onNotify: (n) => unawaited(notifier.notify(n)),
    window: window,
    windowId: '${app.id}#$pid',
    launcher: launcher,
    fileChooser: FileChooserClient(session),
    openedPaths: openedPaths(args),
    // Só um app de instância única recebe os arquivos depois de aberto
    openRequests: app.singleInstance
        ? launcher.openRequests().asBroadcastStream()
        : const Stream.empty(),
  );
  // O título acompanha o idioma
  var title = app.localizedName(context.locale);
  await context.window.setTitle(title);
  context.settings.addListener(() {
    final next = app.localizedName(context.locale);
    if (next == title) return;
    title = next;
    unawaited(context.window.setTitle(title));
  });
  await context.window.setSize(app.defaultSize);
  runApp(PsitoAppHost(app: app, context: context));
  app.onOpen(context);
  unawaited(logFirstFrame());
}

/// Os caminhos dos argumentos: os absolutos, as URLs `file://` e os com as
/// marcas [psitoQuickLookPrefix] e [psitoSettingsSectionPrefix]. As opções
/// (`-x`) e o resto ficam de fora.
List<String> openedPaths(List<String> args) => [
  for (final arg in args)
    if (arg.startsWith('/') ||
        arg.startsWith(psitoQuickLookPrefix) ||
        arg.startsWith(psitoSettingsSectionPrefix))
      arg
    else if (arg.startsWith('file://'))
      Uri.parse(arg).toFilePath(),
];

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
      onGenerateTitle: (_) => app.localizedName(context.locale),
      debugShowCheckedModeBanner: false,
      theme: psitoTheme(settings.accent),
      locale: resolvePsitoLocale(settings.language, app.supportedLocales),
      localizationsDelegates: psitoLocalizationsDelegates(
        app.localizationsDelegates,
      ),
      supportedLocales: app.supportedLocales,
      home: Scaffold(body: app.build(context)),
    ),
  );
}
