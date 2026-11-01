import 'dart:ui' show Offset, Size;

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

  group('a célula do ponteiro', () {
    const grid = DeskGrid(3, 2);

    test('conta da direita, e o de fora fica na mais perto', () {
      // Células de 104, numa área de 1000 de largura
      expect(
        deskCellAt(const Offset(990, 5), 1000, grid, 48),
        const DeskCell(0, 0),
      );
      expect(
        deskCellAt(const Offset(800, 110), 1000, grid, 48),
        const DeskCell(1, 1),
      );
      expect(
        deskCellAt(const Offset(10, 900), 1000, grid, 48),
        const DeskCell(2, 1),
      );
      expect(
        deskCellAt(const Offset(1200, -9), 1000, grid, 48),
        const DeskCell(0, 0),
      );
    });

    test('a livre mais perto pode ser ela mesma', () {
      const from = DeskCell(1, 0);
      expect(nearestFreeCell(from, grid, const {}), from);
      expect(
        nearestFreeCell(from, grid, {from}),
        anyOf(const DeskCell(0, 0), const DeskCell(2, 0), const DeskCell(1, 1)),
      );
      expect(
        nearestFreeCell(from, const DeskGrid(1, 1), {const DeskCell(0, 0)}),
        isNull,
      );
    });
  });

  group('o nome do atalho', () {
    test('troca o Name, tira os traduzidos e não mexe nas ações', () {
      const text = '''
[Desktop Entry]
Name=Velho
Name[pt_BR]=Antigo
Exec=x

[Desktop Action nova]
Name=Nova janela
''';
      expect(renamedDeskShortcut(text, 'Novo'), '''
[Desktop Entry]
Name=Novo
Exec=x

[Desktop Action nova]
Name=Nova janela
''');
    });

    test('sem Name, ganha um', () {
      expect(
        renamedDeskShortcut('[Desktop Entry]\nExec=x\n[Outro]\nA=b', 'N'),
        '[Desktop Entry]\nExec=x\nName=N\n[Outro]\nA=b',
      );
      expect(
        renamedDeskShortcut('[Desktop Entry]\nExec=x', 'N'),
        '[Desktop Entry]\nExec=x\nName=N',
      );
    });
  });

  group('moveDeskCells', () {
    const grid = DeskGrid(4, 4);
    const cells = {
      'a': DeskCell(0, 0),
      'b': DeskCell(0, 1),
      'c': DeskCell(2, 2),
    };

    test('um item vai para a célula', () {
      expect(moveDeskCells(cells, ['a'], 'a', const DeskCell(3, 3), grid), {
        'a': const DeskCell(3, 3),
      });
    });

    test('sem sair do lugar, nada muda', () {
      expect(moveDeskCells(cells, ['a'], 'a', const DeskCell(0, 0), grid), {});
    });

    test('vários andam juntos, com a mesma distância', () {
      expect(
        moveDeskCells(cells, ['a', 'b'], 'a', const DeskCell(1, 0), grid),
        {'a': const DeskCell(1, 0), 'b': const DeskCell(1, 1)},
      );
    });

    test('um grupo pode cair sobre as próprias células', () {
      expect(
        moveDeskCells(cells, ['a', 'b'], 'a', const DeskCell(0, 1), grid),
        {'a': const DeskCell(0, 1), 'b': const DeskCell(0, 2)},
      );
    });

    test('sobre outro item, vai para a livre mais perto', () {
      final moved = moveDeskCells(
        cells,
        ['a'],
        'a',
        const DeskCell(2, 2),
        grid,
      );
      expect(moved['a'], isNot(const DeskCell(2, 2)));
      final dx = moved['a']!.column - 2, dy = moved['a']!.row - 2;
      expect(dx * dx + dy * dy, 1);
    });

    test('quem cairia fora da grade fica dentro dela', () {
      final moved = moveDeskCells(
        cells,
        ['a', 'b'],
        'b',
        const DeskCell(0, 0),
        grid,
      );
      expect(moved['b'], const DeskCell(0, 0));
      expect(grid.contains(moved['a']!), isTrue);
      expect(moved['a'], isNot(const DeskCell(0, 0)));
    });

    test('sem célula livre, fica onde está', () {
      const full = DeskGrid(1, 2);
      expect(
        moveDeskCells(
          const {'a': DeskCell(0, 0), 'b': DeskCell(0, 1)},
          ['a'],
          'a',
          const DeskCell(0, 1),
          full,
        ),
        {'a': const DeskCell(0, 0)},
      );
    });
  });
}
