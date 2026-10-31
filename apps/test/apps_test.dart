import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:psito_apps/main.dart';
import 'package:psito_runtime/psito_runtime.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/network_service.dart';
import 'package:psito_services/system_info_service.dart';
import 'package:psito_services/time_service.dart';
import 'package:flutter/foundation.dart';
import 'package:system_shell/shell/app_registry.dart';

void main() {
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
      final text = File(
        'desktop/org.psito.${app.id}.desktop',
      ).readAsStringSync();
      expect(text, contains('Name=${app.name}\n'));
      expect(text, contains('Exec=/opt/psito/apps/psito_apps ${app.id}\n'));
    }
  });

  test('appById acha os apps do registro', () {
    expect(appById('settings')?.canChangeSettings, isTrue);
    expect(appById('não existe'), isNull);
  });

  for (final app in registeredApps) {
    testWidgets('${app.id} cabe em 240x160', (tester) async {
      tester.view.physicalSize = minWindowSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final ctx = ProcessAppContext(
        app: app,
        settings: ValueNotifier(PsitoSettings.defaults),
        services: AppServices(
          systemInfo: FakeSystemInfoService(),
          network: FakeNetworkService(),
          time: FakeTimeService(),
        ),
        onUpdateSettings: (_) {},
        onNotify: (_) {},
        windowId: '${app.id}#1',
      );
      await tester.pumpWidget(PsitoAppHost(app: app, context: ctx));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  }
}
