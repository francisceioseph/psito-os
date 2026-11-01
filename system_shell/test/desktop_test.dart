import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/shell/app_registry.dart';
import 'package:system_shell/shell/window_manager.dart';
import 'package:system_shell/widgets/psito_window.dart';

import 'helpers.dart';

final _notepadDock = find.byIcon(Icons.edit_note_rounded).first;
final _notepadTitle = find.text('Bloco de notas');

void main() {
  testWidgets('a dock abre e a janela fecha um app', (tester) async {
    await pumpDesktop(tester);

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
    await pumpDesktop(tester);
    await tester.tap(_notepadDock);
    await tester.pump();

    await tester.tap(find.byTooltip('Minimizar'));
    await tester.pump();
    expect(_notepadTitle, findsNothing);

    await tester.tap(_notepadDock);
    await tester.pump();
    expect(_notepadTitle, findsOneWidget);
  });

  testWidgets('o canto da moldura redimensiona até o tamanho mínimo', (
    tester,
  ) async {
    await pumpDesktop(tester);
    await tester.tap(_notepadDock);
    await tester.pump();

    final window = find.byType(PsitoWindow);
    final before = tester.getRect(window);
    final corner = before.bottomRight - const Offset(3, 3);
    await tester.dragFrom(corner, const Offset(120, 80));
    await tester.pump();
    final grown = tester.getRect(window);
    expect(grown.topLeft, before.topLeft);
    expect(grown.width, greaterThan(before.width + 80));
    expect(grown.height, greaterThan(before.height + 40));

    await tester.dragFrom(
      grown.bottomRight - const Offset(3, 3),
      const Offset(-2000, -2000),
    );
    await tester.pump();
    expect(tester.getSize(window), WindowManager.minSize);
  });

  // Um overflow vira erro e falha o teste
  for (final app in registeredApps) {
    testWidgets('${app.name} cabe no tamanho mínimo', (tester) async {
      await pumpDesktop(tester);
      await tester.tap(find.byIcon(app.icon).first);
      await tester.pump();
      final wm = tester.widget<PsitoWindow>(find.byType(PsitoWindow)).manager;
      wm.resize(
        wm.focusedId!,
        ResizeEdge.bottomRight,
        const Offset(-2000, -2000),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(PsitoWindow)), WindowManager.minSize);
    });
  }

  testWidgets('arrastar a barra move e duplo clique maximiza', (tester) async {
    await pumpDesktop(tester);
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
