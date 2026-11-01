// packages/psito_desktop/lib/src/grid.dart
//
// A grade da mesa. As células contam do canto de cima à direita: a coluna 0
// é a da direita, e assim a posição não muda quando a tela muda de largura.
import 'dart:ui' show Offset, Size;

class DeskCell {
  /// Da direita para a esquerda.
  final int column;

  /// De cima para baixo.
  final int row;

  const DeskCell(this.column, this.row);

  @override
  bool operator ==(Object other) =>
      other is DeskCell && other.column == column && other.row == row;

  @override
  int get hashCode => Object.hash(column, row);

  @override
  String toString() => 'DeskCell($column, $row)';
}

class DeskGrid {
  final int columns;
  final int rows;

  const DeskGrid(this.columns, this.rows);

  /// Quantas células de [cell] cabem em [area]; ao menos uma.
  factory DeskGrid.fit(Size area, Size cell) => DeskGrid(
    (area.width / cell.width).floor().clamp(1, 1 << 16),
    (area.height / cell.height).floor().clamp(1, 1 << 16),
  );

  bool contains(DeskCell cell) =>
      cell.column >= 0 &&
      cell.row >= 0 &&
      cell.column < columns &&
      cell.row < rows;

  /// As células na ordem de ocupar: de cima para baixo, da direita para a
  /// esquerda.
  Iterable<DeskCell> get cells sync* {
    for (var column = 0; column < columns; column++) {
      for (var row = 0; row < rows; row++) {
        yield DeskCell(column, row);
      }
    }
  }

  /// A última célula: onde ficam, empilhados, os que não couberam.
  DeskCell get last => DeskCell(columns - 1, rows - 1);

  @override
  bool operator ==(Object other) =>
      other is DeskGrid && other.columns == columns && other.rows == rows;

  @override
  int get hashCode => Object.hash(columns, rows);
}

/// O lado de uma célula para ícones de [iconSize]: o ícone, duas linhas do
/// nome e a folga.
Size deskCellSize(double iconSize) => Size(iconSize + 56, iconSize + 56);

/// A célula de [grid] embaixo de [position] (nas coordenadas da área livre,
/// de largura [width]). Fora da grade, a mais perto.
DeskCell deskCellAt(
  Offset position,
  double width,
  DeskGrid grid,
  double iconSize,
) {
  final cell = deskCellSize(iconSize);
  return DeskCell(
    ((width - position.dx) / cell.width).floor().clamp(0, grid.columns - 1),
    (position.dy / cell.height).floor().clamp(0, grid.rows - 1),
  );
}

/// Onde cada item fica na tela.
class DeskArrangement {
  /// A célula de cada chave.
  final Map<String, DeskCell> cells;

  /// As chaves novas, com uma célula para guardar. Quem só não coube agora
  /// fica fora: a posição salva vale de novo quando a tela voltar a crescer.
  final Map<String, DeskCell> placed;

  const DeskArrangement(this.cells, this.placed);
}

/// Põe [keys] na grade. Quem tem uma célula em [saved] fica nela; quem tem
/// uma que não cabe vai para a livre mais perto; os novos vão para a primeira
/// livre, na ordem de [keys]. Sem célula livre, ficam todos na última.
DeskArrangement arrangeDesk(
  List<String> keys,
  Map<String, DeskCell> saved,
  DeskGrid grid,
) {
  final cells = <String, DeskCell>{};
  final taken = <DeskCell>{};
  final displaced = <String>[];
  final fresh = <String>[];
  for (final key in keys) {
    final cell = saved[key];
    if (cell == null) {
      fresh.add(key);
    } else if (grid.contains(cell) && taken.add(cell)) {
      cells[key] = cell;
    } else {
      displaced.add(key);
    }
  }
  for (final key in displaced) {
    final cell = nearestFreeCell(saved[key]!, grid, taken) ?? grid.last;
    taken.add(cell);
    cells[key] = cell;
  }
  final placed = <String, DeskCell>{};
  final free = grid.cells.where((cell) => !taken.contains(cell)).iterator;
  for (final key in fresh) {
    if (free.moveNext()) {
      cells[key] = placed[key] = free.current;
    } else {
      cells[key] = grid.last;
    }
  }
  return DeskArrangement(cells, placed);
}

/// A célula de [grid] fora de [taken] mais perto de [from]; pode ser ela.
DeskCell? nearestFreeCell(DeskCell from, DeskGrid grid, Set<DeskCell> taken) {
  DeskCell? best;
  int? bestDistance;
  for (final cell in grid.cells) {
    if (taken.contains(cell)) continue;
    final dx = cell.column - from.column, dy = cell.row - from.row;
    final distance = dx * dx + dy * dy;
    if (bestDistance == null || distance < bestDistance) {
      best = cell;
      bestDistance = distance;
    }
  }
  return best;
}

/// As células novas de [keys], arrastados de modo que [grabbed] caia em [to]:
/// andam juntos, com a mesma distância entre eles. Quem cairia fora da grade ou
/// sobre outro item vai para a livre mais perto, e sem nenhuma livre fica onde
/// está. Vazio se [grabbed] não saiu do lugar.
Map<String, DeskCell> moveDeskCells(
  Map<String, DeskCell> cells,
  List<String> keys,
  String grabbed,
  DeskCell to,
  DeskGrid grid,
) {
  final origin = cells[grabbed];
  if (origin == null || origin == to) return const {};
  final dx = to.column - origin.column, dy = to.row - origin.row;
  final moving = keys.toSet();
  final taken = {
    for (final MapEntry(:key, :value) in cells.entries)
      if (!moving.contains(key)) value,
  };
  final out = <String, DeskCell>{};
  for (final key in [grabbed, ...keys.where((key) => key != grabbed)]) {
    final from = cells[key];
    if (from == null) continue;
    final wanted = DeskCell(from.column + dx, from.row + dy);
    final free = grid.contains(wanted) && !taken.contains(wanted)
        ? wanted
        : nearestFreeCell(wanted, grid, taken) ?? from;
    taken.add(free);
    out[key] = free;
  }
  return out;
}

/// [keys] na ordem, sem buracos: o "Organizar por" e o organizar sozinha.
Map<String, DeskCell> packDesk(List<String> keys, DeskGrid grid) {
  final free = grid.cells.iterator;
  return {
    for (final key in keys) key: free.moveNext() ? free.current : grid.last,
  };
}
