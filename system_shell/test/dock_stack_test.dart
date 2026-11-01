import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/shell/app_entry.dart';
import 'package:system_shell/widgets/dock_menu.dart';
import 'package:system_shell/widgets/dock_stack.dart';

DockStackEntry _entry(String name) => DockStackEntry(
  '/p/$name',
  AppEntry(
    id: name,
    name: name,
    color: Colors.grey,
    icon: (size) => SizedBox.square(dimension: size),
  ),
);

void main() {
  Future<List<String>> pump(WidgetTester tester, int count) async {
    final log = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: DockStack(
          anchor: const Rect.fromLTWH(380, 540, 52, 52),
          title: 'Downloads',
          entries: [for (var i = 0; i < count; i++) _entry('f$i')],
          onOpen: (key) => log.add('open $key'),
          onOpenFolder: () => log.add('folder'),
          onClose: () => log.add('close'),
        ),
      ),
    );
    return log;
  }

  testWidgets('com poucos itens é um leque, o mais novo embaixo', (
    tester,
  ) async {
    final log = await pump(tester, 3);
    expect(find.byType(GridView), findsNothing);
    final newest = tester.getCenter(find.byKey(const ValueKey('stack-/p/f0')));
    final oldest = tester.getCenter(find.byKey(const ValueKey('stack-/p/f2')));
    expect(newest.dy, greaterThan(oldest.dy));
    expect(newest.dy, lessThan(540));
    await tester.tap(find.text('f1'));
    expect(log, ['close', 'open /p/f1']);
  });

  testWidgets('com muitos itens é uma grade, com o Abrir no Files', (
    tester,
  ) async {
    final log = await pump(tester, DockStack.fanLimit + 1);
    expect(find.byType(GridView), findsOneWidget);
    await tester.tap(find.text('Abrir no Files'));
    expect(log, ['close', 'folder']);
  });

  testWidgets('a pasta vazia diz que está vazia', (tester) async {
    await pump(tester, 0);
    expect(find.text('A pasta está vazia.'), findsOneWidget);
  });

  testWidgets('o menu e a pilha aguentam a tela minúscula do primeiro quadro', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1, 1);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, DockStack.fanLimit + 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: DockMenu(
          anchor: const Rect.fromLTWH(380, 540, 52, 52),
          title: 'App',
          items: [DockMenuItem('Abrir', () {})],
          onClose: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('o painel abre do lado de dentro e fica na tela', () {
    const screen = Size(1000, 800);
    const child = Size(260, 300);
    const anchor = Rect.fromLTWH(20, 380, 52, 52);
    Offset at(PsitoDockPosition position, [Rect a = anchor]) =>
        DockPopupLayout(a, position, 260).getPositionForChild(screen, child);
    expect(at(PsitoDockPosition.left), const Offset(80, 256));
    expect(
      at(PsitoDockPosition.right, const Rect.fromLTWH(940, 380, 52, 52)),
      const Offset(672, 256),
    );
    // Embaixo, acima do ícone, sem passar da borda esquerda
    expect(
      at(PsitoDockPosition.bottom, const Rect.fromLTWH(10, 740, 52, 52)),
      const Offset(8, 432),
    );
  });
}
