import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_apps/app_context.dart';
import 'package:psito_apps/main.dart';
import 'package:psito_apps/window.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/services/network_service.dart';
import 'package:system_shell/services/system_info_service.dart';
import 'package:system_shell/services/time_service.dart';
import 'package:system_shell/shell/app_registry.dart';
import 'package:system_shell/shell/settings_store.dart';

const _window = MethodChannel('test/window');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> windowCalls;
  late List<PsitoNotification> sent;

  setUp(() {
    windowCalls = [];
    sent = [];
    messenger.setMockMethodCallHandler(_window, (call) async {
      windowCalls.add(call);
      return null;
    });
  });

  ProcessAppContext contextFor(PsitoApp app, SettingsStore store) =>
      ProcessAppContext(
        app: app,
        store: store,
        services: AppServices(
          systemInfo: FakeSystemInfoService(),
          network: FakeNetworkService(),
          time: FakeTimeService(),
        ),
        onNotify: sent.add,
        window: const AppWindow(_window),
        windowId: '${app.id}#1',
      );

  test('todo app do registro tem o seu .desktop, e só eles', () {
    final files = Directory('desktop')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toSet();
    expect(files, {
      for (final app in registeredApps) 'org.psito.${app.id}.desktop',
    });
    for (final app in registeredApps) {
      final text = File('desktop/org.psito.${app.id}.desktop')
          .readAsStringSync();
      expect(text, contains('Name=${app.name}\n'));
      expect(text, contains('Exec=/opt/psito/apps/psito_apps ${app.id}\n'));
    }
  });

  test('appById acha os apps do registro', () {
    expect(appById('settings')?.canChangeSettings, isTrue);
    expect(appById('não existe'), isNull);
  });

  test('o contexto: título, fechar, notificar e configurações', () async {
    final notepad = appById('notepad')!;
    final store = SettingsStore.memory();
    final ctx = contextFor(notepad, store);

    ctx.setTitle('nota.txt');
    ctx.notify(const PsitoNotification(title: 'salvo'));
    ctx.updateSettings(store.value.copyWith(use24h: false));
    ctx.close();
    await Future<void>.delayed(Duration.zero);

    expect(windowCalls.map((c) => c.method), ['setTitle', 'close']);
    expect(windowCalls.first.arguments, 'nota.txt');
    expect(sent.single.title, 'salvo');
    // O bloco de notas não pode mudar as configurações
    expect(store.value.use24h, isTrue);

    final settings = contextFor(appById('settings')!, store);
    settings.updateSettings(store.value.copyWith(use24h: false));
    expect(store.value.use24h, isFalse);
  });

  test('o tamanho da janela nunca fica abaixo do mínimo', () async {
    await const AppWindow(_window).setSize(const Size(100, 500));
    expect(windowCalls.single.arguments, [240, 500]);
  });

  for (final app in registeredApps) {
    testWidgets('${app.id} cabe em 240x160', (tester) async {
      tester.view.physicalSize = minWindowSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final ctx = contextFor(app, SettingsStore.memory());
      await tester.pumpWidget(AppHost(app: app, context: ctx));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  }
}
