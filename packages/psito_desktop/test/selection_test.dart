import 'package:flutter_test/flutter_test.dart';
import 'package:psito_desktop/psito_desktop.dart';

void main() {
  // Na tela (a coluna 0 é a da direita):  c  a
  //                                       d  b
  const cells = {
    'a': DeskCell(0, 0),
    'b': DeskCell(0, 1),
    'c': DeskCell(1, 0),
    'd': DeskCell(1, 1),
  };

  test('a ordem é a de ocupar a grade', () {
    expect(deskOrder(cells), ['a', 'b', 'c', 'd']);
  });

  group('o vizinho', () {
    test('a esquerda é a coluna maior', () {
      expect(deskNeighbor(cells, 'a', -1, 0), 'c');
      expect(deskNeighbor(cells, 'c', 1, 0), 'a');
      expect(deskNeighbor(cells, 'a', 1, 0), isNull);
    });

    test('para baixo fica na coluna', () {
      expect(deskNeighbor(cells, 'a', 0, 1), 'b');
      expect(deskNeighbor(cells, 'b', 0, 1), isNull);
    });

    test('pula os buracos, preferindo a mesma linha', () {
      const sparse = {
        'a': DeskCell(0, 0),
        'perto': DeskCell(1, 3),
        'longe': DeskCell(4, 0),
      };
      expect(deskNeighbor(sparse, 'a', -1, 0), 'longe');
    });
  });

  group('a seleção', () {
    late DeskSelection selection;
    setUp(() => selection = DeskSelection());

    test('o clique deixa só um, e na mesa vazia limpa', () {
      selection.press('a', cells);
      selection.press('b', cells);
      expect(selection.keys, {'b'});
      selection.press(null, cells);
      expect(selection.keys, isEmpty);
    });

    test('o Ctrl alterna, e o Ctrl na mesa vazia não limpa', () {
      selection.press('a', cells);
      selection.press('c', cells, ctrl: true);
      expect(selection.keys, {'a', 'c'});
      selection.press('a', cells, ctrl: true);
      expect(selection.keys, {'c'});
      selection.press(null, cells, ctrl: true);
      expect(selection.keys, {'c'});
    });

    test('o Shift vai da âncora até o item, na ordem da grade', () {
      selection.press('a', cells);
      selection.press('c', cells, shift: true);
      expect(selection.keys, {'a', 'b', 'c'});
      selection.press('b', cells, shift: true);
      expect(selection.keys, {'a', 'b'});
    });

    test('apertar num selecionado mantém, e soltar deixa só ele', () {
      selection.press('a', cells);
      selection.press('b', cells, ctrl: true);
      selection.press('a', cells);
      expect(selection.keys, {'a', 'b'});
      selection.release('a');
      expect(selection.keys, {'a'});
    });

    test('soltar com o Ctrl não desfaz o que ele fez', () {
      selection.press('a', cells);
      selection.press('b', cells, ctrl: true);
      selection.release('b', ctrl: true);
      expect(selection.keys, {'a', 'b'});
    });

    test('o retângulo soma ao que estava, só com o Ctrl', () {
      selection.press('a', cells);
      selection.press(null, cells, ctrl: true);
      selection.rect(['c']);
      selection.rect(['c', 'd']);
      expect(selection.keys, {'a', 'c', 'd'});
      selection.rect(const []);
      expect(selection.keys, {'a'});
      selection.press(null, cells);
      selection.rect(['b']);
      expect(selection.keys, {'b'});
    });

    test('as setas andam, e sem cursor começam do primeiro', () {
      selection.arrow(cells, 0, 1);
      expect(selection.keys, {'a'});
      selection.arrow(cells, -1, 0);
      expect(selection.keys, {'c'});
      // Sem vizinho, fica
      selection.arrow(cells, -1, 0);
      expect(selection.keys, {'c'});
    });

    test('o Shift com as setas estende a partir da âncora', () {
      selection.press('a', cells);
      selection.arrow(cells, 0, 1, shift: true);
      expect(selection.keys, {'a', 'b'});
      expect(selection.cursor, 'b');
      selection.arrow(cells, 0, -1, shift: true);
      expect(selection.keys, {'a'});
    });

    test('o Ctrl+A pega todos, e o que sumiu sai', () {
      selection.all(cells);
      expect(selection.keys, {'a', 'b', 'c', 'd'});
      selection.retain({'b'});
      expect(selection.keys, {'b'});
      expect(selection.cursor, isNull);
    });
  });
}
