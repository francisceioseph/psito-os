// packages/psito_desktop/lib/src/selection.dart
//
// A seleção da mesa: clique, Ctrl, Shift, o retângulo e as setas. A ordem é a
// de ocupar a grade (de cima para baixo, da direita para a esquerda).
import 'grid.dart';

/// As chaves de [cells] na ordem da grade.
List<String> deskOrder(Map<String, DeskCell> cells) {
  int compare(String a, String b) {
    final ca = cells[a]!, cb = cells[b]!;
    if (ca.column != cb.column) return ca.column - cb.column;
    if (ca.row != cb.row) return ca.row - cb.row;
    return a.compareTo(b);
  }

  return cells.keys.toList()..sort(compare);
}

/// O vizinho de [from] na direção da tela ([dx] e [dy], -1, 0 ou 1): o mais
/// perto dentre os que estão daquele lado, preferindo a mesma linha ou coluna.
String? deskNeighbor(Map<String, DeskCell> cells, String from, int dx, int dy) {
  final origin = cells[from];
  if (origin == null) return null;
  String? best;
  int? bestScore;
  for (final key in deskOrder(cells)) {
    if (key == from) continue;
    final cell = cells[key]!;
    // A coluna conta da direita para a esquerda
    final right = origin.column - cell.column, down = cell.row - origin.row;
    final ahead = right * dx + down * dy;
    if (ahead <= 0) continue;
    final aside = dx != 0 ? down : right;
    final score = ahead * ahead + 4 * aside * aside;
    if (bestScore == null || score < bestScore) {
      best = key;
      bestScore = score;
    }
  }
  return best;
}

class DeskSelection {
  final Set<String> _keys = {};
  Set<String> _rectBase = const {};
  String? _anchor;

  /// O item em que o teclado está.
  String? cursor;

  Set<String> get keys => Set.unmodifiable(_keys);

  void clear() {
    _keys.clear();
    cursor = _anchor = null;
  }

  /// Só [key] fica selecionado.
  void only(String key) {
    _keys
      ..clear()
      ..add(key);
    cursor = _anchor = key;
  }

  /// O botão apertado num item, ou na mesa vazia ([key] null). Num item já
  /// selecionado a seleção fica (quem arrasta leva todos), e o [release]
  /// deixa só ele.
  void press(
    String? key,
    Map<String, DeskCell> cells, {
    bool ctrl = false,
    bool shift = false,
  }) {
    if (key == null) {
      if (!ctrl && !shift) clear();
      _rectBase = {..._keys};
    } else if (shift && _anchor != null) {
      _range(_anchor!, key, cells);
    } else if (ctrl) {
      if (!_keys.remove(key)) _keys.add(key);
      cursor = _anchor = key;
    } else if (_keys.contains(key)) {
      cursor = _anchor = key;
    } else {
      only(key);
    }
  }

  /// O botão solto em [key], sem arrastar.
  void release(String key, {bool ctrl = false, bool shift = false}) {
    if (!ctrl && !shift) only(key);
  }

  /// O retângulo: o que já estava selecionado no [press] mais [hits].
  void rect(Iterable<String> hits) {
    _keys
      ..clear()
      ..addAll(_rectBase)
      ..addAll(hits);
    if (hits.isNotEmpty) cursor = _anchor = hits.first;
  }

  void all(Map<String, DeskCell> cells) {
    final order = deskOrder(cells);
    _keys
      ..clear()
      ..addAll(order);
    cursor ??= order.firstOrNull;
    _anchor ??= cursor;
  }

  /// As setas: sem cursor, o primeiro item da grade. Sem vizinho naquele
  /// lado, o cursor fica.
  void arrow(
    Map<String, DeskCell> cells,
    int dx,
    int dy, {
    bool shift = false,
  }) {
    final from = cursor;
    if (from == null || !cells.containsKey(from)) {
      if (deskOrder(cells).firstOrNull case final first?) only(first);
      return;
    }
    final next = deskNeighbor(cells, from, dx, dy) ?? from;
    if (shift) {
      _range(_anchor ?? from, next, cells);
    } else {
      only(next);
    }
  }

  void _range(String anchor, String to, Map<String, DeskCell> cells) {
    final order = deskOrder(cells);
    final a = order.indexOf(anchor), b = order.indexOf(to);
    if (a < 0 || b < 0) return only(to);
    _keys
      ..clear()
      ..addAll(order.sublist(a < b ? a : b, (a < b ? b : a) + 1));
    cursor = to;
    _anchor = anchor;
  }

  /// Esquece quem não está mais na mesa.
  void retain(Set<String> existing) {
    _keys.removeWhere((key) => !existing.contains(key));
    if (!existing.contains(cursor)) cursor = null;
    if (!existing.contains(_anchor)) _anchor = null;
  }
}
