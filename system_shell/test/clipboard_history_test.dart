import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/shell/clipboard_history.dart';
import 'package:system_shell/widgets/clipboard_panel.dart';

import 'helpers.dart';

import 'package:psito_sdk/psito_sdk.dart';

Map<String, Uint8List> _text(String text) => {
  'text/plain;charset=utf-8': utf8.encode(text),
  'UTF8_STRING': utf8.encode(text),
};

void main() {
  late DateTime time;
  late List<Map<String, Uint8List>> offered;
  late int cleared;
  late ClipboardHistory history;

  List<String> previews() => [for (final e in history.entries) e.preview];

  setUp(() {
    time = DateTime(2026, 11, 1, 10);
    offered = [];
    cleared = 0;
    history = ClipboardHistory(
      now: () => time,
      offer: offered.add,
      clearSystem: () => cleared++,
    );
  });
  tearDown(() => history.dispose());

  group('o que aparece', () {
    ClipEntry? entry(Map<String, Uint8List> formats) =>
        ClipEntry.from(formats, time);

    test('texto em uma linha, cortado', () {
      expect(entry(_text('  um\n\n  dois\t três '))!.preview, 'um dois três');
      expect(
        entry(_text('x' * 500))!.preview,
        '${'x' * ClipEntry.previewLength}…',
      );
      expect(entry(_text('a'))!.kind, ClipKind.text);
    });

    test('texto em branco não é uma cópia', () {
      expect(entry(_text('  \n ')), isNull);
      expect(entry(_text('')), isNull);
      expect(entry({}), isNull);
    });

    test('arquivos pelo nome, antes do texto que vem junto', () {
      final one = entry({
        'x-special/gnome-copied-files': utf8.encode('copy\nfile:///a/b.txt'),
        'text/plain;charset=utf-8': utf8.encode('/a/b.txt'),
      })!;
      expect(one.kind, ClipKind.files);
      expect(one.preview, 'b.txt');
      final many = entry({
        'text/uri-list': utf8.encode('file:///a\r\nfile:///b\r\nfile:///c\r\n'),
      })!;
      expect(many.text(testL10n), '3 arquivos: a, b, c');
    });

    test('imagem com os bytes, e o resto pelo tipo', () {
      final image = entry({
        'image/png': Uint8List.fromList([1, 2]),
      })!;
      expect(image.kind, ClipKind.image);
      expect(image.image, [1, 2]);
      final other = entry({
        'application/x-coisa': Uint8List.fromList([1]),
      })!;
      expect(other.kind, ClipKind.other);
      expect(other.preview, 'application/x-coisa');
    });
  });

  group('o histórico', () {
    test('só as cinco últimas, a mais nova primeiro', () {
      for (var i = 1; i <= 7; i++) {
        history.copied(_text('$i'));
      }
      expect(previews(), ['7', '6', '5', '4', '3']);
    });

    test('copiar de novo o mesmo conteúdo não repete', () {
      history.copied(_text('a'));
      history.copied(_text('b'));
      history.copied(_text('a'));
      expect(previews(), ['a', 'b']);
    });

    testWidgets('some depois de quinze minutos', (tester) async {
      history.copied(_text('velho'));
      time = time.add(const Duration(minutes: 10));
      history.copied(_text('novo'));
      await tester.pump(const Duration(minutes: 4));
      time = time.add(const Duration(minutes: 4));
      expect(previews(), ['novo', 'velho']);
      time = time.add(const Duration(minutes: 1, seconds: 1));
      await tester.pump(const Duration(minutes: 1, seconds: 1));
      expect(previews(), ['novo']);
      time = time.add(const Duration(minutes: 10));
      await tester.pump(const Duration(minutes: 10));
      expect(previews(), isEmpty);
    });

    testWidgets('um item vencido não copia, mesmo sem o relógio ter batido', (
      tester,
    ) async {
      history.copied(_text('velho'));
      time = time.add(const Duration(minutes: 16));
      expect(history.recopy(0), isNull);
      expect(offered, isEmpty);
      history.clear();
    });

    testWidgets('copiar de novo oferece, sobe e renova o prazo', (
      tester,
    ) async {
      history.copied(_text('a'));
      time = time.add(const Duration(minutes: 10));
      history.copied(_text('b'));
      final entry = history.recopy(1)!;
      expect(entry.preview, 'a');
      expect(offered.single, _text('a'));
      expect(previews(), ['a', 'b']);
      time = time.add(const Duration(minutes: 6));
      await tester.pump(const Duration(minutes: 6));
      expect(previews(), ['a', 'b']);
      expect(history.recopy(4), isNull);
      history.clear();
    });

    test('o dono fechou: a última cópia volta a ser oferecida', () {
      history.copied(_text('a'));
      history.lost();
      expect(offered.single, _text('a'));
    });

    test('o que não dá para guardar não traz a cópia de antes de volta', () {
      history.copied(_text('a'));
      history.skipped();
      history.lost();
      expect(offered, isEmpty);
      expect(previews(), ['a']);
    });

    test('um texto vazio vale como cópia, mas fica fora da lista', () {
      history.copied(_text('a'));
      history.copied(_text(''));
      expect(previews(), ['a']);
      history.lost();
      expect(offered.single, _text(''));
    });

    test('limpar esquece tudo, também no sistema', () {
      history.copied(_text('a'));
      history.clear();
      expect(previews(), isEmpty);
      expect(cleared, 1);
      history.lost();
      expect(offered, isEmpty);
    });
  });

  group('o painel', () {
    late List<int> picked;
    late int closed;

    Future<void> pump(WidgetTester tester) async {
      picked = [];
      closed = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: testL10nDelegates,
          supportedLocales: psitoLocales,

          home: Scaffold(
            body: ClipboardPanel(
              history: history,
              onPick: picked.add,
              onClose: () => closed++,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('mostra o preview, a idade e o atalho de cada posição', (
      tester,
    ) async {
      history.copied(_text('primeiro'));
      time = time.add(const Duration(minutes: 3));
      history.copied(_text('segundo'));
      await pump(tester);
      expect(find.text('segundo'), findsOneWidget);
      expect(find.text('agora'), findsOneWidget);
      expect(find.text('há 3 min'), findsOneWidget);
      expect(find.text('Alt+Shift+1'), findsOneWidget);
      expect(find.text('Alt+Shift+2'), findsOneWidget);
      expect(find.text('Alt+Shift+3'), findsNothing);
      history.clear();
    });

    testWidgets('sem nada, diz por quê', (tester) async {
      await pump(tester);
      expect(find.textContaining('Nada copiado'), findsOneWidget);
      expect(find.text('Limpar'), findsNothing);
    });

    testWidgets('um clique ou um número escolhem, e o Esc fecha', (
      tester,
    ) async {
      history.copied(_text('a'));
      history.copied(_text('b'));
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('clipboard-item-1')));
      expect(picked, [1]);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      expect(picked, [1, 0]);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      expect(picked, [1, 0]);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(closed, 1);
      history.clear();
    });

    testWidgets('o Limpar esvazia na hora', (tester) async {
      history.copied(_text('a'));
      await pump(tester);
      await tester.tap(find.text('Limpar'));
      await tester.pump();
      expect(find.text('a'), findsNothing);
      expect(find.textContaining('Nada copiado'), findsOneWidget);
    });

    testWidgets('um texto enorme cabe, em duas linhas', (tester) async {
      history.copied(_text('palavra ' * 200));
      await pump(tester);
      expect(tester.takeException(), isNull);
      history.clear();
    });
  });
}
