import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_desktop/psito_desktop.dart';
import 'package:system_shell/widgets/psito_desktop_icons.dart';

const _long =
    'um nome muito comprido que não cabe em duas linhas de jeito nenhum';

void main() {
  late List<String?> selected;
  late List<String> opened;

  setUp(() {
    selected = [];
    opened = [];
  });

  Future<void> pump(
    WidgetTester tester, {
    String? current,
    EdgeInsets insets = EdgeInsets.zero,
  }) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: PsitoDesktopIcons(
          icons: [
            for (final name in ['a', 'b', _long])
              DeskIcon(
                key: name,
                name: name,
                icon: (size) => SizedBox.square(dimension: size),
              ),
          ],
          cells: const {
            'a': DeskCell(0, 0),
            'b': DeskCell(1, 2),
            _long: DeskCell(2, 0),
          },
          iconSize: 48,
          insets: insets,
          selected: current,
          onSelect: selected.add,
          onOpen: opened.add,
        ),
      ),
    );
  }

  test('a célula tem o ícone, o nome e a folga', () {
    expect(deskCellSize(48), const Size(104, 104));
  });

  testWidgets('as células contam do canto de cima à direita, dentro da área', (
    tester,
  ) async {
    await pump(tester, insets: const EdgeInsets.only(top: 40, right: 100));
    final a = tester.getTopLeft(find.byKey(const ValueKey('desk-a')));
    expect(a, const Offset(1000 - 100 - 104, 40));
    final b = tester.getTopLeft(find.byKey(const ValueKey('desk-b')));
    expect(b, const Offset(1000 - 100 - 2 * 104, 40 + 2 * 104));
  });

  testWidgets('apertar seleciona na hora, e na mesa vazia limpa', (
    tester,
  ) async {
    await pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.text('a')));
    expect(selected, ['a']);
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    await tester.tapAt(const Offset(100, 700));
    expect(selected, ['a', null]);
  });

  testWidgets('o duplo clique abre', (tester) async {
    await pump(tester);
    await tester.tap(find.text('b'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('b'));
    await tester.pump(const Duration(seconds: 1));
    expect(opened, ['b']);
  });

  testWidgets('o nome fica em duas linhas, e inteiro quando selecionado', (
    tester,
  ) async {
    await pump(tester);
    expect(tester.widget<Text>(find.text(_long)).maxLines, 2);
    await pump(tester, current: _long);
    expect(tester.widget<Text>(find.text(_long)).maxLines, isNull);
    expect(tester.takeException(), isNull);
  });
}
