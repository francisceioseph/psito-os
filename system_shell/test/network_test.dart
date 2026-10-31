import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/services/network_service.dart';
import 'package:system_shell/services/system_services.dart';
import 'package:system_shell/widgets/launcher.dart';
import 'package:system_shell/widgets/network_panel.dart';
import 'package:system_shell/widgets/notification_panel.dart';

import 'helpers.dart';

final _indicator = find.byKey(const ValueKey('network-indicator'));
final _panel = find.byType(NetworkPanel);

Future<FakeNetworkService> _pump(
  WidgetTester tester, [
  PsitoNetworkState initial = FakeNetworkService.sample,
]) async {
  final network = FakeNetworkService(initial);
  final services = SystemServices.fake(network: network);
  addTearDown(services.dispose);
  await pumpDesktop(tester, services: services);
  return network;
}

IconData? _icon(WidgetTester tester) => tester
    .widget<Icon>(find.descendant(of: _indicator, matching: find.byType(Icon)))
    .icon;

PsitoNetworkState _wifi(int strength) => PsitoNetworkState(
  available: true,
  connectivity: PsitoConnectivity.full,
  primary: PsitoNetworkDevice(
    interface: 'wlan0',
    kind: PsitoNetworkKind.wifi,
    state: PsitoDeviceState.connected,
    connection: 'Calopsita',
    wifiStrength: strength,
  ),
);

void main() {
  testWidgets('o ícone acompanha o estado da rede', (tester) async {
    final network = await _pump(tester);
    expect(_icon(tester), Icons.lan);

    final expectations = {
      const PsitoNetworkState(available: true): Icons.link_off,
      const PsitoNetworkState(available: true, enabled: false):
          Icons.signal_wifi_off,
      const PsitoNetworkState(available: true, connecting: true): Icons.sync,
      _wifi(90): Icons.wifi,
      _wifi(50): Icons.wifi_2_bar,
      _wifi(10): Icons.wifi_1_bar,
    };
    for (final MapEntry(key: state, value: icon) in expectations.entries) {
      network.set(state);
      await tester.pump();
      expect(_icon(tester), icon, reason: '$state');
    }

    network.set(PsitoNetworkState.unavailable);
    await tester.pump();
    expect(_indicator, findsNothing);
  });

  testWidgets('sem internet avisa no tooltip', (tester) async {
    await _pump(
      tester,
      const PsitoNetworkState(
        available: true,
        connectivity: PsitoConnectivity.limited,
        primary: FakeNetworkService.ethernet,
      ),
    );
    expect(find.byTooltip('Conectado, sem internet'), findsOneWidget);
  });

  testWidgets('o painel mostra a conexão e desliga a rede', (tester) async {
    final network = await _pump(tester);
    await tester.tap(_indicator);
    await tester.pump();

    expect(_panel, findsOneWidget);
    expect(find.text('Conexão cabeada 1'), findsOneWidget);
    expect(find.text('Cabo · Internet'), findsOneWidget);
    expect(find.text('IPv4  10.0.2.15/24'), findsOneWidget);

    await tester.tap(find.text('Rede'));
    await tester.pump();
    expect(network.state.value.enabled, isFalse);
    expect(_icon(tester), Icons.signal_wifi_off);
    expect(find.text('Rede desativada'), findsOneWidget);

    await tester.tap(find.text('Rede'));
    await tester.pump();
    expect(network.state.value, FakeNetworkService.sample);
  });

  testWidgets('só uma camada da top bar fica aberta', (tester) async {
    await _pump(tester);
    await tester.tap(_indicator);
    await tester.pump();
    expect(_panel, findsOneWidget);

    await tester.tap(find.text('Menu'));
    await tester.pump();
    expect(find.byType(Launcher), findsOneWidget);
    expect(_panel, findsNothing);

    // O launcher cobre a tela toda; Esc fecha
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(Launcher), findsNothing);

    // Entre os painéis, clicar em outro ícone da top bar troca de painel
    await tester.tap(_indicator);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('notifications-bell')));
    await tester.pump();
    expect(find.byType(NotificationPanel), findsOneWidget);
    expect(_panel, findsNothing);

    await tester.tap(_indicator);
    await tester.pump();
    expect(_panel, findsOneWidget);
    expect(find.byType(NotificationPanel), findsNothing);

    // Clicar de novo no ícone fecha
    await tester.tap(_indicator);
    await tester.pump();
    expect(_panel, findsNothing);
  });

  testWidgets('Configurações lista os dispositivos de rede', (tester) async {
    await pumpOS(tester);
    await tester.tap(find.byIcon(Icons.settings_rounded).first);
    await tester.pump();
    await tester.tap(find.text('Rede').first);
    await tester.pump();

    expect(find.text('ens3'), findsOneWidget);
    expect(
      find.text('Conectado · Conexão cabeada 1 · 10.0.2.15/24'),
      findsOneWidget,
    );
  });
}
