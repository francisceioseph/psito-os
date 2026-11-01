import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/network_service.dart';
import 'package:psito_services/system_services.dart';
import 'package:system_shell/l10n/l10n.dart';
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
  group('Wi-Fi no painel', wifiPanelTests);

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
    expect(find.text('Wired connection 1'), findsOneWidget);
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
      find.text('Conectado · Wired connection 1 · 10.0.2.15/24'),
      findsOneWidget,
    );
  });
}

void wifiPanelTests() {
  Future<FakeNetworkService> open(WidgetTester tester) async {
    final network = await _pump(tester);
    await tester.tap(_indicator);
    await tester.pump();
    return network;
  }

  Finder row(String ssid) => find.byKey(ValueKey('wifi-$ssid'));
  final password = find.byKey(const ValueKey('wifi-password'));
  final connect = find.byKey(const ValueKey('wifi-connect'));

  testWidgets('só a rede com portal mostra o botão de login', (tester) async {
    var opened = 0;
    final button = find.byKey(const ValueKey('network-portal'));
    await _pumpPanel(
      tester,
      const PsitoNetworkState(
        available: true,
        connectivity: PsitoConnectivity.portal,
        checkUrl: 'http://portal.test/nm',
      ),
      () => opened++,
    );
    await tester.tap(button);
    expect(opened, 1);

    await _pumpPanel(
      tester,
      const PsitoNetworkState(
        available: true,
        connectivity: PsitoConnectivity.full,
        checkUrl: 'http://portal.test/nm',
      ),
      () => opened++,
    );
    expect(button, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a VPN liga pelo painel, e o ícone mostra', (tester) async {
    final network = await open(tester);
    final vpn = find.byKey(const ValueKey('vpn-trabalho'));
    final badge = find.byKey(const ValueKey('network-vpn'));
    await tester.ensureVisible(vpn);
    await tester.pump();
    expect(badge, findsNothing);
    await tester.tap(vpn);
    await tester.pump();
    expect(network.state.value.vpns.single.active, isTrue);
    expect(badge, findsOneWidget);
    await _closePanelAndSettle(tester);
  });

  testWidgets('uma VPN que falha avisa, e cancelar não é falha', (
    tester,
  ) async {
    const busy = PsitoVpn(uuid: 'v', name: 'Longe', busy: true);
    final network = _SlowVpn(
      const PsitoNetworkState(available: true, vpns: [busy]),
    );
    addTearDown(network.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: psitoTheme(PsitoSettings.defaults.accent),
        localizationsDelegates: psitoLocalizationsDelegates(const [
          SystemLocalizations.delegate,
        ]),
        supportedLocales: psitoLocales,
        home: Scaffold(
          body: NetworkPanel(service: network, onClose: () {}),
        ),
      ),
    );
    await tester.pump();
    final tile = find.byKey(const ValueKey('vpn-v'));
    // Ligando, o interruptor aparece ligado e o toque pede para desligar
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    await tester.tap(tile);
    await tester.pump();
    expect(network.asked, [false]);

    network.answer = false;
    await tester.tap(tile);
    await tester.pump();
    expect(find.text('Não foi possível ligar Longe.'), findsNothing);

    network.set(
      const PsitoNetworkState(
        available: true,
        vpns: [PsitoVpn(uuid: 'v', name: 'Longe')],
      ),
    );
    await tester.pump();
    await tester.tap(tile);
    await tester.pump();
    expect(network.asked.last, isTrue);
    expect(find.text('Não foi possível ligar Longe.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('abrir procura redes e lista pelo sinal', (tester) async {
    final network = await open(tester);
    expect(network.scans, 1);
    final ys = [
      for (final ssid in ['Casa', 'Cafeteria', 'Vizinho'])
        tester.getTopLeft(row(ssid)).dy,
    ];
    expect(ys, orderedEquals([...ys]..sort()));
    await _closePanelAndSettle(tester);
  });

  testWidgets('rede aberta conecta com um clique', (tester) async {
    final network = await open(tester);
    await tester.tap(row('Cafeteria'));
    await tester.pump();
    expect(password, findsNothing);
    final active = network.state.value.wifi!.networks.first;
    expect((active.ssid, active.active), ('Cafeteria', true));
    expect(find.byKey(const ValueKey('wifi-disconnect')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wifi-disconnect')));
    await tester.pump();
    expect(network.state.value.wifi!.networks.any((n) => n.active), isFalse);
    await _closePanelAndSettle(tester);
  });

  testWidgets('senha errada avisa e mantém o que foi digitado', (tester) async {
    final network = await open(tester);
    await tester.tap(row('Vizinho'));
    await tester.pump();
    await tester.pump();
    // O foco já vai para o campo, sem precisar clicar nele
    expect(tester.widget<TextField>(password).focusNode!.hasFocus, isTrue);
    await tester.enterText(password, 'errada');
    await tester.tap(connect);
    await tester.pump();
    expect(find.text('Senha incorreta'), findsOneWidget);
    expect(tester.widget<TextField>(password).controller!.text, 'errada');

    await tester.enterText(password, FakeNetworkService.wifiPassword);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(password, findsNothing);
    expect(network.state.value.wifi!.networks.first.ssid, 'Vizinho');
    await _closePanelAndSettle(tester);
  });

  testWidgets('rede guardada não pede senha, e a corporativa não abre', (
    tester,
  ) async {
    final network = await open(tester);
    await tester.tap(row('Firma'));
    await tester.pump();
    expect(password, findsNothing);
    expect(network.state.value.wifi!.networks.any((n) => n.active), isFalse);

    await tester.tap(row('Casa'));
    await tester.pump();
    expect(password, findsNothing);
    expect(network.state.value.wifi!.networks.first.active, isTrue);
    await _closePanelAndSettle(tester);
  });

  testWidgets('outra rede pede o nome e a senha', (tester) async {
    final network = await open(tester);
    await tester.tap(find.byKey(const ValueKey('wifi-other')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('wifi-name')), 'Sumida');
    await tester.enterText(password, FakeNetworkService.wifiPassword);
    await tester.tap(connect);
    await tester.pump();
    final first = network.state.value.wifi!.networks.first;
    expect((first.ssid, first.active), ('Sumida', true));
    await _closePanelAndSettle(tester);
  });

  testWidgets('desligar o Wi-Fi esconde a lista', (tester) async {
    await open(tester);
    expect(row('Casa'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wifi-switch')));
    await tester.pump();
    expect(row('Casa'), findsNothing);
    await _closePanelAndSettle(tester);
  });

  testWidgets('sem adaptador não há nada de Wi-Fi', (tester) async {
    await _pump(
      tester,
      const PsitoNetworkState(
        available: true,
        connectivity: PsitoConnectivity.full,
        primary: FakeNetworkService.ethernet,
        devices: [FakeNetworkService.ethernet],
      ),
    );
    await tester.tap(_indicator);
    await tester.pump();
    expect(find.byKey(const ValueKey('wifi-switch')), findsNothing);
    await _closePanelAndSettle(tester);
  });
}

/// Responde o que o teste mandar e guarda o que pediram.
class _SlowVpn extends FakeNetworkService {
  _SlowVpn(super.initial);

  bool answer = true;
  final asked = <bool>[];

  @override
  Future<bool> setVpnActive(String uuid, bool active) async {
    asked.add(active);
    return answer;
  }
}

Future<void> _pumpPanel(
  WidgetTester tester,
  PsitoNetworkState state,
  VoidCallback onOpenPortal,
) async {
  final network = FakeNetworkService(state);
  addTearDown(network.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: psitoTheme(PsitoSettings.defaults.accent),
      localizationsDelegates: psitoLocalizationsDelegates(const [
        SystemLocalizations.delegate,
      ]),
      supportedLocales: psitoLocales,
      home: Scaffold(
        body: NetworkPanel(
          service: network,
          onClose: () {},
          onOpenPortal: onOpenPortal,
        ),
      ),
    ),
  );
  await tester.pump();
}

// Os timers do painel só somem com ele fechado
Future<void> _closePanelAndSettle(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pump();
}
