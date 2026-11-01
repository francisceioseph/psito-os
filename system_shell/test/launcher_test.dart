import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/shell/app_entry.dart';
import 'package:system_shell/widgets/dock_menu.dart';
import 'package:system_shell/widgets/launcher.dart';

import 'helpers.dart';

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
    await pumpDesktop(tester);
    await _openByMenu(tester);

    expect(_launcher, findsOneWidget);
    final field = tester.widget<EditableText>(
      find.descendant(of: _search, matching: find.byType(EditableText)),
    );
    expect(field.focusNode.hasPrimaryFocus, isTrue);
  });

  testWidgets('digitar filtra e Enter abre o app', (tester) async {
    await pumpDesktop(tester);
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
    await pumpDesktop(tester);
    await _openByMenu(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await _submit(tester);
    expect(find.text('Clock'), findsOneWidget);
  });

  testWidgets('Esc fecha', (tester) async {
    await pumpDesktop(tester);
    await _openByMenu(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_launcher, findsNothing);
  });

  testWidgets('Super sozinho alterna; Super+↑ não abre', (tester) async {
    await pumpDesktop(tester);

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
    await pumpDesktop(tester);
    await tester.tap(find.byIcon(Icons.edit_note_rounded).first);
    await tester.pump();

    await _openByMenu(tester);
    await tester.enterText(_search, 'notepad');
    await _submit(tester);
    expect(find.text('Notepad'), findsNWidgets(2));
  });

  testWidgets('o clique direito abre o menu do app, e o Esc fecha só ele', (
    tester,
  ) async {
    var closed = false;
    final log = <String>[];
    final app = AppEntry(
      id: 'x',
      name: 'Meu app',
      color: Colors.grey,
      icon: (size) => SizedBox.square(dimension: size),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Launcher(
            apps: [app],
            onLaunch: (_) {},
            onClose: () => closed = true,
            menuFor: (app) => [
              DockMenuItem('Criar atalho', () => log.add(app.id)),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('launcher-x')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Criar atalho'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Criar atalho'), findsNothing);
    expect(closed, isFalse);

    await tester.tap(
      find.byKey(const ValueKey('launcher-x')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();
    await tester.tap(find.text('Criar atalho'));
    await tester.pump();
    expect(log, ['x']);
    expect(find.text('Criar atalho'), findsNothing);
  });
}
