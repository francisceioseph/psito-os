// Cada app do laboratório também roda sozinho, pelo psito_runtime, como na VM.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_runtime/psito_runtime.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/network_service.dart';
import 'package:psito_services/system_info_service.dart';
import 'package:psito_services/time_service.dart';
import 'package:system_shell/shell/app_registry.dart';

void main() {
  for (final app in registeredApps) {
    testWidgets('${app.id} cabe em 240x160 no runtime', (tester) async {
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
