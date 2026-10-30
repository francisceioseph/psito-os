import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/screens/desktop_screen.dart';
import 'package:system_shell/widgets/launcher.dart';

Future<void> _pumpDesktop(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: DesktopScreen()));
}

Future<void> _openByMenu(WidgetTester tester) async {
  await tester.tap(find.text('Menu'));
  await tester.pump();
}

final _launcher = find.byType(Launcher);
final _search = find.descendant(
  of: _launcher,
  matching: find.byType(TextField),
);

Future<void> _submit(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  testWidgets('o botão Menu abre com a busca em foco', (tester) async {
    await _pumpDesktop(tester);
    await _openByMenu(tester);

    expect(_launcher, findsOneWidget);
    final field = tester.widget<EditableText>(
      find.descendant(of: _search, matching: find.byType(EditableText)),
    );
    expect(field.focusNode.hasPrimaryFocus, isTrue);
  });

  testWidgets('digitar filtra e Enter abre o app', (tester) async {
    await _pumpDesktop(tester);
    await _openByMenu(tester);

    await tester.enterText(_search, 'NÓTE');
    await tester.pump();
    expect(find.byKey(const ValueKey('launcher-notepad')), findsOneWidget);
    expect(find.byKey(const ValueKey('launcher-calculator')), findsNothing);

    await _submit(tester);
    expect(_launcher, findsNothing);
    expect(find.text('Notepad'), findsOneWidget);
  });

  testWidgets('a seta escolhe outro app', (tester) async {
    await _pumpDesktop(tester);
    await _openByMenu(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await _submit(tester);
    expect(find.text('Calculator'), findsOneWidget);
  });

  testWidgets('Esc fecha', (tester) async {
    await _pumpDesktop(tester);
    await _openByMenu(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_launcher, findsNothing);
  });

  testWidgets('Super sozinho alterna; Super+↑ não abre', (tester) async {
    await _pumpDesktop(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(_launcher, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(_launcher, findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(_launcher, findsNothing);
  });

  testWidgets('o launcher abre uma segunda janela do mesmo app', (
    tester,
  ) async {
    await _pumpDesktop(tester);
    await tester.tap(find.byIcon(Icons.edit_note_rounded).first);
    await tester.pump();

    await _openByMenu(tester);
    await tester.enterText(_search, 'notepad');
    await _submit(tester);
    expect(find.text('Notepad'), findsNWidgets(2));
  });
}
