import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/screens/desktop_screen.dart';
import 'package:system_shell/services/battery_service.dart';
import 'package:system_shell/services/session_service.dart';
import 'package:system_shell/services/system_services.dart';
import 'package:system_shell/widgets/battery_indicator.dart';
import 'package:system_shell/widgets/battery_panel.dart';
import 'package:system_shell/widgets/power_confirm_dialog.dart';
import 'package:system_shell/widgets/power_panel.dart';
import 'package:system_shell/widgets/volume_panel.dart';

import 'helpers.dart';

final _battery = find.byKey(const ValueKey('battery-indicator'));
final _powerButton = find.byKey(const ValueKey('power-button'));
final _panel = find.byType(PowerPanel);
final _dialog = find.byType(PowerConfirmDialog);

const _discharging = BatteryState(
  available: true,
  present: true,
  percentage: 57,
  timeToEmpty: Duration(hours: 3, minutes: 20),
);

Future<(FakeBatteryService, FakeSessionService)> _pump(
  WidgetTester tester, {
  BatteryState battery = FakeBatteryService.sample,
  SessionCapabilities capabilities = SessionCapabilities.all,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final batteryService = FakeBatteryService(battery);
  final session = FakeSessionService(capabilities);
  final services = SystemServices.fake(
    battery: batteryService,
    session: session,
  );
  addTearDown(services.dispose);
  await tester.pumpWidget(MaterialApp(home: DesktopScreen(services: services)));
  return (batteryService, session);
}

IconData? _batteryIcon(WidgetTester tester) => tester
    .widget<Icon>(find.descendant(of: _battery, matching: find.byType(Icon)))
    .icon;

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(_powerButton);
  await tester.pump();
}

void main() {
  test('formatDuration', () {
    expect(
      BatteryIndicator.formatDuration(const Duration(seconds: 45)),
      'menos de 1 min',
    );
    expect(
      BatteryIndicator.formatDuration(const Duration(minutes: 40)),
      '40 min',
    );
    expect(
      BatteryIndicator.formatDuration(const Duration(hours: 3, minutes: 20)),
      '3 h 20 min',
    );
    expect(BatteryIndicator.formatDuration(const Duration(hours: 2)), '2 h');
  });

  testWidgets('a bateria some sem bateria e segue o estado', (tester) async {
    final (battery, _) = await _pump(tester);
    expect(_battery, findsNothing);

    battery.set(_discharging);
    await tester.pump();
    expect(_batteryIcon(tester), Icons.battery_4_bar);
    expect(find.text('57%'), findsOneWidget);
    expect(find.byTooltip('Bateria: 57%'), findsOneWidget);

    battery.set(
      const BatteryState(
        available: true,
        present: true,
        percentage: 60,
        charging: true,
        timeToFull: Duration(minutes: 40),
      ),
    );
    await tester.pump();
    expect(_batteryIcon(tester), Icons.battery_charging_full);

    battery.set(
      const BatteryState(available: true, present: true, percentage: 8),
    );
    await tester.pump();
    expect(_batteryIcon(tester), Icons.battery_alert);
  });

  testWidgets('o painel da bateria mostra estado, tempo e fonte', (
    tester,
  ) async {
    final (battery, _) = await _pump(tester, battery: _discharging);
    await tester.tap(_battery);
    await tester.pump();

    final panel = find.byType(BatteryPanel);
    expect(panel, findsOneWidget);
    expect(find.descendant(of: panel, matching: find.text('57%')), findsOne);
    expect(find.text('Na bateria · 3 h 20 min restantes'), findsOneWidget);
    expect(find.text('Fonte de energia: Bateria'), findsOneWidget);

    battery.set(
      const BatteryState(
        available: true,
        present: true,
        percentage: 60,
        charging: true,
        timeToFull: Duration(minutes: 40),
      ),
    );
    await tester.pump();
    expect(find.text('Carregando · 40 min até completar'), findsOneWidget);
    expect(find.text('Fonte de energia: Adaptador'), findsOneWidget);
  });

  testWidgets('Configurações → Energia esconde a porcentagem', (tester) async {
    final services = SystemServices.fake(
      battery: FakeBatteryService(_discharging),
    );
    addTearDown(services.dispose);
    final store = await pumpOS(tester, services: services);
    final percentNextToIcon = find.descendant(
      of: _battery,
      matching: find.text('57%'),
    );
    expect(percentNextToIcon, findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_rounded).first);
    await tester.pump();
    await tester.tap(find.text('Energia'));
    await tester.pump();
    await tester.tap(find.text('Mostrar porcentagem da bateria'));
    await tester.pump();

    expect(store.value.showBatteryPercentage, isFalse);
    expect(percentNextToIcon, findsNothing);
    expect(_battery, findsOneWidget);
  });

  testWidgets('Suspender age na hora; sem permissão fica desabilitado', (
    tester,
  ) async {
    final (_, session) = await _pump(
      tester,
      capabilities: const SessionCapabilities(
        canPowerOff: true,
        canSuspend: true,
      ),
    );
    await _openMenu(tester);
    expect(_panel, findsOneWidget);

    final reboot = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Reiniciar'),
    );
    expect(reboot.enabled, isFalse);

    await tester.tap(find.text('Suspender'));
    await tester.pump();
    expect(session.calls, ['suspend']);
    expect(_panel, findsNothing);
    expect(_dialog, findsNothing);
  });

  testWidgets('Desligar pede confirmação; Esc cancela', (tester) async {
    final (_, session) = await _pump(tester);
    await _openMenu(tester);
    await tester.tap(find.text('Desligar'));
    await tester.pump();

    expect(_panel, findsNothing);
    expect(_dialog, findsOneWidget);
    expect(find.text('Desligar o Psito OS?'), findsOneWidget);
    expect(find.text('Desligando em 10 s…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Desligando em 7 s…'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_dialog, findsNothing);
    await tester.pump(const Duration(seconds: 10));
    expect(session.calls, isEmpty);
  });

  testWidgets('a contagem até o fim desliga', (tester) async {
    final (_, session) = await _pump(tester);
    await _openMenu(tester);
    await tester.tap(find.text('Desligar'));
    await tester.pump();

    await tester.pump(const Duration(seconds: 10));
    expect(session.calls, ['powerOff']);
    expect(_dialog, findsNothing);
  });

  testWidgets('Reiniciar agora não espera a contagem', (tester) async {
    final (_, session) = await _pump(tester);
    await _openMenu(tester);
    await tester.tap(find.text('Reiniciar'));
    await tester.pump();

    expect(find.text('Reiniciando em 10 s…'), findsOneWidget);
    await tester.tap(find.text('Reiniciar agora'));
    await tester.pump();
    expect(session.calls, ['reboot']);
    expect(_dialog, findsNothing);
  });

  testWidgets('energia e volume abrem um de cada vez', (tester) async {
    await _pump(tester);
    await _openMenu(tester);
    await tester.tap(find.byKey(const ValueKey('volume-indicator')));
    await tester.pump();
    expect(find.byType(VolumePanel), findsOneWidget);
    expect(_panel, findsNothing);

    await _openMenu(tester);
    expect(_panel, findsOneWidget);
    expect(find.byType(VolumePanel), findsNothing);
  });
}
