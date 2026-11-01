import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_desktop/psito_desktop.dart';
import 'package:system_shell/widgets/psito_desktop_icons.dart';

const _long =
    'um nome muito comprido que não cabe em duas linhas de jeito nenhum';

void main() {
  late List<String?> pressed;
  late List<String> released;
  late List<Set<String>> rects;
  late List<String> opened;
  late List<(String?, Offset)> menus;

  setUp(() {
    pressed = [];
    released = [];
    rects = [];
    opened = [];
    menus = [];
  });

  Future<void> pump(
    WidgetTester tester, {
    Set<String> current = const {},
    EdgeInsets insets = EdgeInsets.zero,
    Widget? editor,
    bool keyboard = true,
    KeyEventResult Function(KeyEvent)? onKey,
    bool popup = false,
    bool dimmed = false,
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
                editor: name == 'a' ? editor : null,
                dimmed: dimmed,
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
          onPress: pressed.add,
          onRelease: released.add,
          onRect: rects.add,
          onOpen: opened.add,
          keyboard: keyboard,
          onKey: onKey,
          onMenu: (key, position) => menus.add((key, position)),
          popup: popup,
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
    expect(pressed, ['a']);
    await gesture.up();
    expect(released, ['a']);
    await tester.pump(const Duration(seconds: 1));
    await tester.tapAt(const Offset(100, 700));
    expect(pressed, ['a', null]);
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
    await pump(tester, current: {_long});
    expect(tester.widget<Text>(find.text(_long)).maxLines, isNull);
    // Com vários selecionados, os nomes se cobririam
    await pump(tester, current: {_long, 'a'});
    expect(tester.widget<Text>(find.text(_long)).maxLines, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('o retângulo pega o que toca, só quando muda', (tester) async {
    await pump(tester);
    // 'a' é a célula de cima à direita: x de 896 a 1000, y de 0 a 104
    final gesture = await tester.startGesture(const Offset(900, 300));
    expect(pressed, [null]);
    await gesture.moveTo(const Offset(905, 320));
    await tester.pump();
    expect(rects, isEmpty);
    expect(find.byKey(const ValueKey('desk-band')), findsOneWidget);
    await gesture.moveTo(const Offset(990, 50));
    await tester.pump();
    await gesture.moveTo(const Offset(995, 40));
    await tester.pump();
    expect(rects, [
      {'a'},
    ]);
    await gesture.up();
    await tester.pump();
    expect(find.byKey(const ValueKey('desk-band')), findsNothing);
  });

  testWidgets('o teclado chega depois de um clique, e fora dele não', (
    tester,
  ) async {
    final keys = <KeyEvent>[];
    KeyEventResult onKey(KeyEvent event) {
      keys.add(event);
      return KeyEventResult.handled;
    }

    await pump(tester, onKey: onKey);
    await tester.tapAt(const Offset(100, 700));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    expect(keys.whereType<KeyDownEvent>(), hasLength(1));
    // A superfície perdeu o teclado
    await pump(tester, onKey: onKey, keyboard: false);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    expect(keys.whereType<KeyDownEvent>(), hasLength(1));
  });

  testWidgets('com o campo aberto, os cliques no item são dele', (
    tester,
  ) async {
    await pump(tester, editor: const SizedBox(width: 90, height: 20));
    expect(find.text('a'), findsNothing);
    final center = tester.getCenter(find.byKey(const ValueKey('desk-a')));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pump(const Duration(seconds: 1));
    expect(pressed, isEmpty);
    expect(opened, isEmpty);
  });

  testWidgets('o clique direito pede o menu do item ou da mesa', (
    tester,
  ) async {
    await pump(tester);
    final center = tester.getCenter(find.text('a'));
    await tester.tapAt(center, buttons: kSecondaryMouseButton);
    await tester.pump();
    expect(menus, [('a', center)]);
    // O botão direito não seleciona nem começa o retângulo: quem decide é o
    // menu
    expect(pressed, isEmpty);
    await tester.tapAt(const Offset(100, 700), buttons: kSecondaryMouseButton);
    await tester.pump();
    expect(menus.last, (null, const Offset(100, 700)));
    expect(pressed, isEmpty);
  });

  testWidgets('fechando o menu, a mesa pega o teclado de volta', (tester) async {
    final keys = <KeyEvent>[];
    KeyEventResult onKey(KeyEvent event) {
      keys.add(event);
      return KeyEventResult.handled;
    }

    await pump(tester, onKey: onKey);
    await tester.tapAt(const Offset(100, 700));
    await tester.pump();
    final other = FocusNode();
    addTearDown(other.dispose);
    await pump(tester, onKey: onKey, popup: true);
    other.requestFocus();
    await tester.pump();
    await pump(tester, onKey: onKey);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    expect(keys.whereType<KeyDownEvent>(), hasLength(1));
  });

  testWidgets('um recortado fica apagado', (tester) async {
    await pump(tester, dimmed: true);
    expect(
      tester.widgetList<Opacity>(find.byType(Opacity)).first.opacity,
      lessThan(1),
    );
  });
}
