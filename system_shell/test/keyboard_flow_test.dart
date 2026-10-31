// Aceitação da fase 1: usar o desktop só com o teclado (combinações da VM).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/shell/window_manager.dart';
import 'package:system_shell/widgets/launcher.dart';
import 'package:system_shell/widgets/psito_window.dart';

import 'helpers.dart';

const _ctrl = LogicalKeyboardKey.controlLeft;
const _alt = LogicalKeyboardKey.altLeft;
const _shift = LogicalKeyboardKey.shiftLeft;

/// Ctrl+Espaço, busca e Enter.
Future<void> _launch(WidgetTester tester, String query) async {
  await pressCombo(tester, [_ctrl], LogicalKeyboardKey.space);
  await tester.enterText(
    find.descendant(
      of: find.byType(Launcher),
      matching: find.byType(TextField),
    ),
    query,
  );
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

WindowManager _manager(WidgetTester tester) => tester
    .widget<PsitoWindow>(find.byType(PsitoWindow, skipOffstage: false).first)
    .manager;

void main() {
  testWidgets('abrir, alternar, organizar e fechar só com o teclado', (
    tester,
  ) async {
    await pumpOS(tester);

    await _launch(tester, 'calc');
    await _launch(tester, 'clock');
    final wm = _manager(tester);
    expect(wm.windows.map((w) => w.app.id), ['calculator', 'clock']);
    expect(wm.focused!.app.id, 'clock');

    await pressCombo(tester, [_ctrl], LogicalKeyboardKey.tab);
    final calculator = wm.focused!;
    expect(calculator.app.id, 'calculator');

    await pressCombo(tester, [_alt, _shift], LogicalKeyboardKey.arrowLeft);
    expect(calculator.snap, SnapMode.left);

    await pressCombo(tester, [_alt, _shift], LogicalKeyboardKey.arrowDown);
    expect(calculator.minimized, isTrue);
    expect(wm.focused!.app.id, 'clock');

    await pressCombo(tester, [_ctrl], LogicalKeyboardKey.tab);
    expect(wm.focused, calculator);
    expect(calculator.minimized, isFalse);

    await pressCombo(tester, [_ctrl, _alt], LogicalKeyboardKey.keyW);
    await pressCombo(tester, [_ctrl, _alt], LogicalKeyboardKey.keyW);
    expect(wm.windows, isEmpty);
    expect(find.byType(PsitoWindow, skipOffstage: false), findsNothing);
  });
}
