import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/widgets/launcher.dart';
import 'package:system_shell/widgets/notification_panel.dart';

import 'helpers.dart';

/// Abre o Clock e deixa o timer de 10 s terminar.
Future<void> _finishClockTimer(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.access_time_rounded).first);
  await tester.pump();
  await tester.tap(find.text('Iniciar timer'));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

final _bell = find.byKey(const ValueKey('notifications-bell'));
final _title = find.text('Timer concluído');
final _panel = find.byType(NotificationPanel);

void main() {
  testWidgets('o timer do Clock mostra um toast que some sozinho', (
    tester,
  ) async {
    await pumpDesktop(tester);
    await _finishClockTimer(tester);

    expect(_title, findsOneWidget);
    expect(
      find.descendant(of: _bell, matching: find.text('1')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(_title, findsNothing);
  });

  testWidgets('o painel lista, zera o badge e dispensa', (tester) async {
    await pumpDesktop(tester);
    await _finishClockTimer(tester);
    await tester.pump(const Duration(seconds: 6));

    await tester.tap(_bell);
    await tester.pump();
    expect(_panel, findsOneWidget);
    expect(_title, findsOneWidget);
    expect(find.descendant(of: _bell, matching: find.text('1')), findsNothing);

    await tester.tap(
      find.descendant(of: _panel, matching: find.byTooltip('Dispensar')),
    );
    await tester.pump();
    expect(find.text('Nenhuma notificação'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_panel, findsNothing);
  });

  testWidgets('Limpar tudo esvazia o painel', (tester) async {
    await pumpDesktop(tester);
    await _finishClockTimer(tester);
    await tester.tap(find.text('Iniciar timer'));
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    await tester.tap(_bell);
    await tester.pump();
    expect(_title, findsNWidgets(2));

    await tester.tap(find.text('Limpar tudo'));
    await tester.pump();
    expect(find.text('Nenhuma notificação'), findsOneWidget);
  });

  testWidgets('clicar no painel restaura a janela minimizada', (tester) async {
    await pumpDesktop(tester);
    await _finishClockTimer(tester);
    await tester.pump(const Duration(seconds: 6));

    await tester.tap(find.byTooltip('Minimizar'));
    await tester.pump();
    expect(find.text('Clock'), findsNothing);

    await tester.tap(_bell);
    await tester.pump();
    await tester.tap(find.descendant(of: _panel, matching: _title));
    await tester.pump();
    expect(_panel, findsNothing);
    expect(find.text('Clock'), findsOneWidget);
  });

  testWidgets('clicar no painel reabre o app se a janela fechou', (
    tester,
  ) async {
    await pumpDesktop(tester);
    await _finishClockTimer(tester);
    await tester.pump(const Duration(seconds: 6));

    await tester.tap(find.byTooltip('Fechar'));
    await tester.pump();
    expect(find.text('Clock'), findsNothing);

    await tester.tap(_bell);
    await tester.pump();
    await tester.tap(find.descendant(of: _panel, matching: _title));
    await tester.pump();
    expect(find.text('Clock'), findsOneWidget);
  });

  testWidgets('abrir o launcher fecha o painel', (tester) async {
    await pumpDesktop(tester);
    await tester.tap(_bell);
    await tester.pump();
    expect(_panel, findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(_panel, findsNothing);
    expect(find.byType(Launcher), findsOneWidget);
  });
}
