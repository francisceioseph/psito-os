// Aceitação da fase 2: os ícones da top bar refletem os serviços do sistema
// e reagem quando eles mudam.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/audio_service.dart';
import 'package:psito_services/battery_service.dart';
import 'package:psito_services/network_service.dart';
import 'package:psito_services/session_service.dart';
import 'package:psito_services/system_info_service.dart';
import 'package:psito_services/system_services.dart';
import 'package:psito_services/time_service.dart';

import 'helpers.dart';

ValueKey<String> _key(String name) => ValueKey(name);

IconData? _iconOf(WidgetTester tester, String key) => tester
    .widget<Icon>(
      find.descendant(of: find.byKey(_key(key)), matching: find.byType(Icon)),
    )
    .icon;

void main() {
  testWidgets('cada ícone segue o seu serviço', (tester) async {
    final systemInfo = FakeSystemInfoService();
    final network = FakeNetworkService();
    final audio = FakeAudioService();
    final battery = FakeBatteryService();
    var clock = DateTime(2026, 10, 30, 16, 41);
    final time = FakeTimeService(clock: () => clock);
    final services = SystemServices.fake(
      systemInfo: systemInfo,
      network: network,
      audio: audio,
      battery: battery,
      time: time,
    );
    addTearDown(services.dispose);
    await pumpOS(tester, services: services);
    await tester.pump(const Duration(seconds: 1));

    // Estado da VM: cabo, 40%, sem bateria, Fortaleza
    expect(_iconOf(tester, 'network-indicator'), Icons.lan);
    expect(_iconOf(tester, 'volume-indicator'), Icons.volume_down);
    expect(find.byKey(_key('battery-indicator')), findsNothing);
    expect(find.text('Sex, 30 de out, 16:41'), findsOneWidget);

    network.set(const PsitoNetworkState(available: true));
    await tester.pump();
    expect(_iconOf(tester, 'network-indicator'), Icons.link_off);

    audio.set(const AudioState(available: true, volume: 0.4, muted: true));
    await tester.pump();
    expect(_iconOf(tester, 'volume-indicator'), Icons.volume_off);

    battery.set(
      const BatteryState(available: true, present: true, percentage: 8),
    );
    await tester.pump();
    expect(_iconOf(tester, 'battery-indicator'), Icons.battery_alert);
    expect(find.text('8%'), findsOneWidget);

    // Troca de fuso: o relógio do sistema passa a dar a hora de Tóquio
    await time.setTimezone('Asia/Tokyo');
    clock = DateTime(2026, 10, 31, 4, 41);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Sáb, 31 de out, 04:41'), findsOneWidget);

    systemInfo.set(
      const PsitoSystemInfo(
        available: true,
        hostname: 'calopsita',
        osName: 'Debian',
        kernel: '6.12',
      ),
    );
    await tester.tap(find.byIcon(Icons.settings_rounded).first);
    await tester.pump();
    await tester.tap(find.text('Sobre'));
    await tester.pump();
    expect(find.text('calopsita'), findsOneWidget);
  });

  testWidgets('sem serviços a top bar fica só com o essencial', (tester) async {
    final services = SystemServices.fake(
      network: FakeNetworkService(PsitoNetworkState.unavailable),
      audio: FakeAudioService(AudioState.unavailable),
      battery: FakeBatteryService(BatteryState.unavailable),
      session: FakeSessionService(SessionCapabilities.none),
    );
    addTearDown(services.dispose);
    await pumpOS(tester, services: services);

    for (final key in [
      'network-indicator',
      'volume-indicator',
      'battery-indicator',
    ]) {
      expect(find.byKey(_key(key)), findsNothing, reason: key);
    }
    expect(find.text('Menu'), findsOneWidget);
    expect(find.byKey(_key('notifications-bell')), findsOneWidget);
    expect(find.byKey(_key('power-button')), findsOneWidget);

    await tester.tap(find.byKey(_key('power-button')));
    await tester.pump();
    for (final label in ['Suspender', 'Reiniciar', 'Desligar']) {
      final tile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, label),
      );
      expect(tile.enabled, isFalse, reason: label);
    }
  });
}
