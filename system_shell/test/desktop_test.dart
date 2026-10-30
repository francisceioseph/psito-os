import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/screens/desktop_screen.dart';

Future<void> _pumpDesktop(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: DesktopScreen()));
}

final _notepadDock = find.byIcon(Icons.edit_note_rounded).first;
final _notepadTitle = find.text('Notepad');

void main() {
  testWidgets('a dock abre e a janela fecha um app', (tester) async {
    await _pumpDesktop(tester);

    await tester.tap(_notepadDock);
    await tester.pump();
    expect(_notepadTitle, findsOneWidget);
    expect(find.byKey(const ValueKey('running-notepad')), findsOneWidget);

    await tester.tap(find.byTooltip('Fechar'));
    await tester.pump();
    expect(_notepadTitle, findsNothing);
    expect(find.byKey(const ValueKey('running-notepad')), findsNothing);
  });

  testWidgets('minimizar esconde e a dock restaura', (tester) async {
    await _pumpDesktop(tester);
    await tester.tap(_notepadDock);
    await tester.pump();

    await tester.tap(find.byTooltip('Minimizar'));
    await tester.pump();
    expect(_notepadTitle, findsNothing);

    await tester.tap(_notepadDock);
    await tester.pump();
    expect(_notepadTitle, findsOneWidget);
  });

  testWidgets('arrastar a barra move e duplo clique maximiza', (tester) async {
    await _pumpDesktop(tester);
    await tester.tap(_notepadDock);
    await tester.pump();

    final before = tester.getTopLeft(_notepadTitle);
    await tester.drag(_notepadTitle, const Offset(60, 40));
    await tester.pump();
    expect(tester.getTopLeft(_notepadTitle), before + const Offset(60, 40));

    await tester.tap(_notepadTitle);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(_notepadTitle);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Restaurar'), findsOneWidget);
  });
}
