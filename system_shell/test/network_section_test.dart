import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/network_connections.dart';
import 'package:psito_services/network_service.dart';
import 'package:psito_settings/l10n/settings_localizations.dart';
import 'package:psito_settings/network_section.dart';

ValueKey<String> _key(String name) => ValueKey(name);

void main() {
  late FakeNetworkConnections connections;
  String? picked;
  List<String>? pickedWith;

  setUp(() {
    connections = FakeNetworkConnections();
    picked = null;
    pickedWith = null;
  });

  Future<void> pump(WidgetTester tester, {PsitoNetworkState? network}) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: psitoTheme(PsitoSettings.defaults.accent),
        localizationsDelegates: psitoLocalizationsDelegates(const [
          SettingsLocalizations.delegate,
        ]),
        supportedLocales: psitoLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: NetworkSection(
              network: network ?? FakeNetworkService.sample,
              connections: connections,
              pickFile: ({required title, patterns = const []}) async {
                pickedWith = patterns;
                return picked;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> open(WidgetTester tester, String uuid) async {
    await tester.tap(find.byKey(_key('connection-$uuid')));
    await tester.pump();
  }

  test('os endereços que o formulário aceita', () {
    expect(isValidIpv4Cidr('192.168.0.10/24'), isTrue);
    expect(isValidIpv4Cidr('192.168.0.10'), isFalse);
    expect(isValidIpv4Cidr('192.168.0.10/33'), isFalse);
    expect(isValidIpv4Cidr('999.1.1.1/24'), isFalse);
    expect(isValidIpv4('::1'), isFalse);
    expect(splitDns('1.1.1.1, 8.8.8.8  9.9.9.9'), [
      '1.1.1.1',
      '8.8.8.8',
      '9.9.9.9',
    ]);
    expect(splitDns('  '), isEmpty);
  });

  testWidgets('os detalhes abrem no dispositivo', (tester) async {
    const device = PsitoNetworkDevice(
      interface: 'wlan0',
      kind: PsitoNetworkKind.wifi,
      state: PsitoDeviceState.connected,
      ipv4: '10.0.0.5/24',
      ipv6: '2001:db8::5/64',
      gateway: '10.0.0.1',
      dns: ['10.0.0.1', '1.1.1.1'],
      mac: 'AA:BB:CC:DD:EE:FF',
    );
    await pump(
      tester,
      network: const PsitoNetworkState(available: true, devices: [device]),
    );
    expect(find.text('AA:BB:CC:DD:EE:FF'), findsNothing);
    await tester.tap(find.byKey(_key('device-wlan0')));
    await tester.pump();
    expect(find.text('AA:BB:CC:DD:EE:FF'), findsOneWidget);
    expect(find.text('10.0.0.1'), findsOneWidget);
    expect(find.text('10.0.0.1, 1.1.1.1'), findsOneWidget);
    expect(find.text('2001:db8::5/64'), findsOneWidget);
  });

  testWidgets('salvar grava o que mudou', (tester) async {
    await pump(tester);
    await open(tester, 'casa');
    await tester.tap(find.byKey(_key('connection-autoconnect')));
    await tester.enterText(find.byKey(_key('connection-priority')), '5');
    await tester.enterText(
      find.byKey(_key('connection-dns')),
      '1.1.1.1, 8.8.8.8',
    );
    await tester.tap(find.byKey(_key('connection-save')));
    await tester.pump();
    final saved = connections.connections.value.first;
    expect(saved.autoconnect, isFalse);
    expect(saved.priority, 5);
    expect(saved.dns, ['1.1.1.1', '8.8.8.8']);
    expect(find.text('Só quando você pedir'), findsOneWidget);
    expect(find.text('Salvo.'), findsOneWidget);
  });

  testWidgets('endereço manual inválido não vai', (tester) async {
    await pump(tester);
    await open(tester, 'casa');
    expect(find.byKey(_key('connection-address')), findsNothing);
    await tester.tap(find.byKey(_key('connection-method')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manual').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(_key('connection-address')), '10.0.0.5');
    await tester.tap(find.byKey(_key('connection-save')));
    await tester.pump();
    expect(find.text('Use um endereço como 192.168.0.10/24.'), findsOneWidget);
    expect(connections.connections.value.first.ipv4Method, PsitoIpMethod.auto);

    await tester.enterText(
      find.byKey(_key('connection-address')),
      '10.0.0.5/24',
    );
    await tester.tap(find.byKey(_key('connection-save')));
    await tester.pump();
    final saved = connections.connections.value.first;
    expect(saved.ipv4Method, PsitoIpMethod.manual);
    expect(saved.address, '10.0.0.5/24');
  });

  testWidgets('senha cancelada avisa e mantém o digitado', (tester) async {
    connections.answer = false;
    await pump(tester);
    await open(tester, 'casa');
    await tester.enterText(find.byKey(_key('connection-priority')), '9');
    await tester.tap(find.byKey(_key('connection-save')));
    await tester.pump();
    expect(find.text('Não deu certo, ou foi cancelado.'), findsOneWidget);
    expect(find.widgetWithText(TextField, '9'), findsOneWidget);
  });

  testWidgets('esquecer pede confirmação, e o cabo não tem', (tester) async {
    await pump(tester);
    await open(tester, 'cabo');
    expect(find.byKey(_key('connection-forget')), findsNothing);
    await tester.tap(find.byKey(_key('connection-cabo')));
    await tester.pump();

    await open(tester, 'casa');
    await tester.tap(find.byKey(_key('connection-forget')));
    await tester.pump();
    expect(connections.connections.value, hasLength(2));
    expect(find.text('Esquecer Casa?'), findsOneWidget);
    await tester.tap(find.byKey(_key('connection-forget-yes')));
    await tester.pump();
    expect(connections.connections.value.map((c) => c.uuid), ['cabo']);
  });

  group('VPN', () {
    Finder import() => find.byKey(_key('vpn-import'));

    testWidgets('importar guarda o arquivo escolhido e avisa', (tester) async {
      picked = '/home/ana/casa.conf';
      await pump(tester);
      await tester.tap(import());
      await tester.pump();
      expect(pickedWith, ['*.conf', '*.ovpn']);
      expect(connections.imported, ['/home/ana/casa.conf']);
      expect(find.text('casa'), findsOneWidget);
      expect(find.textContaining('VPN guardada'), findsOneWidget);
    });

    testWidgets('cancelar o seletor não faz nada', (tester) async {
      await pump(tester);
      await tester.tap(import());
      await tester.pump();
      expect(connections.imported, isEmpty);
      expect(find.textContaining('VPN guardada'), findsNothing);
    });

    testWidgets('arquivo recusado avisa', (tester) async {
      picked = '/home/ana/ruim.conf';
      connections.answer = false;
      await pump(tester);
      await tester.tap(import());
      await tester.pump();
      expect(
        find.text('Não foi possível importar este arquivo.'),
        findsOneWidget,
      );
    });

    testWidgets('o formulário dela só tem o que vale para uma VPN', (
      tester,
    ) async {
      picked = '/home/ana/casa.conf';
      await pump(tester);
      await tester.tap(import());
      await tester.pump();
      await open(tester, 'vpn-1');
      expect(find.byKey(_key('connection-priority')), findsNothing);
      expect(find.byKey(_key('connection-dns')), findsNothing);
      expect(find.byKey(_key('connection-forget')), findsOneWidget);
      await tester.tap(find.byKey(_key('connection-autoconnect')));
      await tester.tap(find.byKey(_key('connection-save')));
      await tester.pump();
      expect(connections.connections.value.last.autoconnect, isTrue);
    });
  });
}
