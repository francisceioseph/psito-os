import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/shell/app_entry.dart';
import 'package:system_shell/widgets/dock_menu.dart';
import 'package:system_shell/widgets/dock_stack.dart';

import 'helpers.dart';

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
        localizationsDelegates: testL10nDelegates,
        supportedLocales: psitoLocales,

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
    await expectAllLabeled(tester);
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
    await expectAllLabeled(tester);
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
        localizationsDelegates: testL10nDelegates,
        supportedLocales: psitoLocales,

        home: DockMenu(
          anchor: const Rect.fromLTWH(380, 540, 52, 52),
          title: 'App',
          items: [DockMenuItem('Abrir', () {})],
          onClose: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await expectAllLabeled(tester);
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

  group('as opções do menu', () {
    Future<List<String>> menu(
      WidgetTester tester, {
      Offset? at,
      bool keepsOpen = false,
    }) async {
      final log = <String>[];
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: testL10nDelegates,
          supportedLocales: psitoLocales,

          home: Scaffold(
            body: DockMenu(
              at: at,
              anchor: const Rect.fromLTWH(380, 520, 40, 40),
              title: 'Menu',
              onClose: () => log.add('fechou'),
              items: [
                DockMenuItem('Viva', () => log.add('viva')),
                DockMenuItem('Morta', () => log.add('morta'), enabled: false),
                DockMenuItem('Fica', () => log.add('fica'), keepsOpen: true),
              ],
            ),
          ),
        ),
      );
      return log;
    }

    testWidgets('a apagada não responde, e a que fica não fecha', (
      tester,
    ) async {
      final log = await menu(tester);
      await tester.tap(find.text('Morta'));
      await tester.tap(find.text('Fica'));
      expect(log, ['fica']);
      await tester.tap(find.text('Viva'));
      expect(log, ['fica', 'fechou', 'viva']);
    });

    testWidgets('no ponteiro, abre para baixo, e para cima sem espaço', (
      tester,
    ) async {
      await menu(tester, at: const Offset(100, 50));
      final panel = find.ancestor(
        of: find.text('Menu'),
        matching: find.byType(Material),
      );
      expect(tester.getTopLeft(panel.first), const Offset(100, 50));
      await menu(tester, at: const Offset(790, 590));
      final rect = tester.getRect(panel.first);
      expect(rect.right, lessThanOrEqualTo(800));
      expect(rect.bottom, lessThanOrEqualTo(590));
    });

    testWidgets('muitas opções rolam, sem estourar', (tester) async {
      tester.view.physicalSize = const Size(400, 200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: testL10nDelegates,
          supportedLocales: psitoLocales,

          home: DockMenu(
            at: Offset.zero,
            title: 'Menu',
            onClose: () {},
            items: [
              for (var i = 0; i < 30; i++) DockMenuItem('Item $i', () {}),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
