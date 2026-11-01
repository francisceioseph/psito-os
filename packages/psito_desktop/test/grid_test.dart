import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:psito_desktop/psito_desktop.dart';

const _grid = DeskGrid(3, 2);

void main() {
  test('a grade é o que cabe, com ao menos uma célula', () {
    expect(
      DeskGrid.fit(const Size(1000, 500), const Size(100, 100)),
      const DeskGrid(10, 5),
    );
    expect(
      DeskGrid.fit(const Size(50, 50), const Size(100, 100)),
      const DeskGrid(1, 1),
    );
  });

  test('os novos ocupam de cima para baixo, da direita para a esquerda', () {
    final result = arrangeDesk(['a', 'b', 'c'], const {}, _grid);
    expect(result.cells['a'], const DeskCell(0, 0));
    expect(result.cells['b'], const DeskCell(0, 1));
    expect(result.cells['c'], const DeskCell(1, 0));
    expect(result.placed.keys, ['a', 'b', 'c']);
  });

  test('quem tem célula fica nela, e o novo pega a livre', () {
    final result = arrangeDesk(
      ['novo', 'salvo'],
      const {'salvo': DeskCell(0, 0)},
      _grid,
    );
    expect(result.cells['salvo'], const DeskCell(0, 0));
    expect(result.cells['novo'], const DeskCell(0, 1));
    expect(result.placed.keys, ['novo']);
  });

  test('quem não cabe vai para a livre mais perto, sem perder a salva', () {
    final result = arrangeDesk(
      ['longe', 'a'],
      const {'longe': DeskCell(9, 1), 'a': DeskCell(2, 1)},
      _grid,
    );
    expect(result.cells['a'], const DeskCell(2, 1));
    expect(result.cells['longe'], const DeskCell(2, 0));
    expect(result.placed, isEmpty);
  });

  test('sem célula livre, os que sobram ficam na última', () {
    final keys = [for (var i = 0; i < 8; i++) '$i'];
    final result = arrangeDesk(keys, const {}, _grid);
    expect(result.cells['5'], _grid.last);
    expect(result.cells['6'], _grid.last);
    expect(result.cells['7'], _grid.last);
    // Quem sobrou não guarda a célula: ela é de quem coube
    expect(result.placed.containsKey('6'), isFalse);
  });

  test('duas chaves na mesma célula: a segunda sai', () {
    final result = arrangeDesk(
      ['a', 'b'],
      const {'a': DeskCell(1, 1), 'b': DeskCell(1, 1)},
      _grid,
    );
    expect(result.cells['a'], const DeskCell(1, 1));
    expect(result.cells['b'], isNot(const DeskCell(1, 1)));
  });

  test('o organizar segue a ordem, sem buracos', () {
    final cells = packDesk(['a', 'b', 'c'], _grid);
    expect(cells['c'], const DeskCell(1, 0));
  });
}
