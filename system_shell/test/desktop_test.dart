import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/screens/desktop_screen.dart';

void main() {
  testWidgets('a dock abre e a janela fecha um app', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: DesktopScreen()));

    await tester.tap(find.byIcon(Icons.edit_note_rounded));
    await tester.pump();
    expect(find.text('Notepad'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.text('Notepad'), findsNothing);
  });
}
