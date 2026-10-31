// apps/files/lib/src/tab.dart
//
// Uma aba do Files: onde ela está (uma pasta, a lixeira ou uma busca), o
// histórico de voltar e avançar, os itens, a seleção e o que os modos lista
// (as pastas abertas em árvore) e colunas (a cadeia de pastas) precisam.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:psito_fs/psito_fs.dart';

import 'env.dart';

sealed class FilesLocation {
  const FilesLocation();
}

class FolderLocation extends FilesLocation {
  final String path;

  const FolderLocation(this.path);

  @override
  bool operator ==(Object other) =>
      other is FolderLocation && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

class TrashLocation extends FilesLocation {
  const TrashLocation();

  @override
  bool operator ==(Object other) => other is TrashLocation;

  @override
  int get hashCode => 0;
}

class SearchLocation extends FilesLocation {
  /// A pasta em que a busca começou.
  final String root;
  final String query;

  const SearchLocation(this.root, this.query);

  @override
  bool operator ==(Object other) =>
      other is SearchLocation && other.root == root && other.query == query;

  @override
  int get hashCode => Object.hash(root, query);
}

class FilesTab extends ChangeNotifier {
  final FilesEnv env;
  final FilesConfig config;

  FilesLocation _location;
  final _back = <FilesLocation>[];
  final _forward = <FilesLocation>[];

  /// Os itens como vieram, antes de esconder os ocultos e ordenar.
  List<FsEntry> _all = const [];

  /// O que a aba mostra, na ordem.
  List<FsEntry> items = const [];

  /// Na lixeira, o item de cada caminho (de onde ele saiu).
  Map<String, TrashItem> trashItems = const {};
  bool loading = false;
  String? error;

  /// Buscando ainda (os resultados chegam aos poucos).
  bool searching = false;

  /// Os caminhos selecionados, na ordem em que entraram.
  final selection = <String>{};

  /// Onde as setas estão (o último clicado).
  String? cursor;
  String? _anchor;

  /// O item com o nome sendo editado.
  String? renaming;

  /// No modo colunas: a primeira coluna. As outras vão dela até a pasta
  /// atual.
  String columnBase;

  /// As listagens das outras pastas: as colunas e as pastas abertas em
  /// árvore no modo lista.
  final listings = <String, List<FsEntry>>{};

  /// As pastas abertas em árvore no modo lista.
  final expanded = <String>{};

  StreamSubscription<void>? _watch;
  StreamSubscription<List<FsEntry>>? _search;
  int _generation = 0;

  FilesTab(this.env, this.config, FilesLocation location)
    : _location = location,
      columnBase = location is FolderLocation ? location.path : env.home {
    config.addListener(_resort);
    unawaited(_load());
  }

  FilesLocation get location => _location;

  /// A pasta da aba (a da busca, na busca). Null na lixeira.
  String? get folder => switch (_location) {
    FolderLocation(:final path) => path,
    SearchLocation(:final root) => root,
    TrashLocation() => null,
  };

  bool get canGoBack => _back.isNotEmpty;
  bool get canGoForward => _forward.isNotEmpty;
  bool get canGoUp => switch (_location) {
    FolderLocation(:final path) => path != '/',
    _ => false,
  };

  ViewMode get mode {
    final loc = _location;
    if (loc is SearchLocation || loc is TrashLocation) {
      // A busca e a lixeira não têm colunas: a lista mostra de onde é cada um
      final mode = config.modeFor(loc is SearchLocation ? '?search' : '?trash');
      return mode == ViewMode.columns ? ViewMode.list : mode;
    }
    return config.modeFor((loc as FolderLocation).path);
  }

  void setMode(ViewMode mode) {
    final loc = _location;
    final key = switch (loc) {
      FolderLocation(:final path) => path,
      SearchLocation() => '?search',
      TrashLocation() => '?trash',
    };
    if (mode == ViewMode.columns && loc is FolderLocation) {
      columnBase = loc.path;
    }
    config.setMode(key, mode);
  }

  /// O nome da aba e da janela.
  String get title => switch (_location) {
    FolderLocation(:final path) => env.knownFolder(path)?.$2 ?? baseName(path),
    TrashLocation() => 'Lixeira',
    SearchLocation(:final query) => 'Buscando "$query"',
  };

  /// Vai para [location]. [record] guarda no voltar; os passos das colunas
  /// não guardam.
  void go(FilesLocation location, {bool record = true, String? select}) {
    if (location == _location && select == null) return;
    if (record && location != _location) {
      _back.add(_location);
      _forward.clear();
    }
    _enter(location, select: select);
  }

  void back() {
    if (_back.isEmpty) return;
    final previous = _location;
    _forward.add(previous);
    _enter(_back.removeLast(), select: _childOf(previous));
  }

  void forward() {
    if (_forward.isEmpty) return;
    _back.add(_location);
    _enter(_forward.removeLast());
  }

  /// A pasta de cima, com a de agora selecionada.
  void up() {
    final path = folder;
    if (!canGoUp || path == null) return;
    go(FolderLocation(dirName(path)), select: path);
  }

  String? _childOf(FilesLocation location) =>
      location is FolderLocation ? location.path : null;

  void _enter(FilesLocation location, {String? select}) {
    _location = location;
    // Fora da cadeia das colunas, a pasta vira a primeira coluna
    if (location is FolderLocation && !isWithin(columnBase, location.path)) {
      columnBase = location.path;
    }
    // A pasta de antes some logo, para nada dela parecer da nova
    _all = const [];
    items = const [];
    trashItems = const {};
    selection.clear();
    cursor = null;
    _anchor = null;
    renaming = null;
    expanded.clear();
    if (select != null) {
      selection.add(select);
      cursor = select;
      _anchor = select;
    }
    unawaited(_load());
    notifyListeners();
  }

  Future<void> refresh() => _load(keepSelection: true);

  Future<void> _load({bool keepSelection = false}) async {
    final generation = ++_generation;
    await _watch?.cancel();
    await _search?.cancel();
    _watch = null;
    _search = null;
    loading = true;
    error = null;
    searching = false;
    notifyListeners();
    final location = _location;
    try {
      switch (location) {
        case FolderLocation(:final path):
          final entries = await listDirectory(path, env.mime);
          if (generation != _generation) return;
          _all = entries;
          trashItems = const {};
          _watch = watchDirectory(path)
              .listen((_) => unawaited(refresh()), onError: (Object _) {});
        case TrashLocation():
          final list = await env.trash.list();
          if (generation != _generation) return;
          trashItems = {for (final item in list) item.path: item};
          _all = [for (final item in list) ?FsEntry.stat(item.path, env.mime)];
          final infoDir = env.trash.infoDir;
          _watch = watchDirectory(infoDir)
              .listen((_) => unawaited(refresh()), onError: (Object _) {});
        case SearchLocation(:final root, :final query):
          _all = [];
          trashItems = const {};
          searching = true;
          _search = searchByName(root, query, env.mime).listen(
            (batch) {
              _all = [..._all, ...batch];
              _resort();
            },
            onDone: () {
              searching = false;
              notifyListeners();
            },
          );
      }
      loading = false;
    } on FileSystemException catch (e) {
      if (generation != _generation) return;
      _all = const [];
      loading = false;
      error = describeError(e);
    }
    if (!keepSelection) {
      // A seleção que veio com o go (a pasta de onde se subiu)
      selection.removeWhere((p) => !_all.any((e) => e.path == p));
    }
    _resort();
    unawaited(_refreshListings());
  }

  void _resort() {
    final visible = config.showHidden ? _all : _all.where((e) => !e.hidden);
    items = sortEntries(
      visible,
      config.sort,
      kindOf: (e) => env.describe(e.mimeType),
    );
    selection.removeWhere((p) => !items.any((e) => e.path == p));
    notifyListeners();
  }

  /// As listagens das pastas abertas em árvore e das colunas, de novo.
  Future<void> _refreshListings() async {
    for (final path in [...listings.keys]) {
      if (!expanded.contains(path) && !columnChain.contains(path)) {
        listings.remove(path);
      }
    }
    for (final path in [...expanded, ...columnChain]) {
      if (path == folder) continue;
      await ensureListing(path, force: true);
    }
  }

  /// A listagem de outra pasta (uma coluna ou um ramo da árvore), já sem os
  /// ocultos e na ordem.
  Future<void> ensureListing(String path, {bool force = false}) async {
    if (!force && listings.containsKey(path)) return;
    try {
      final entries = await listDirectory(path, env.mime);
      final visible = config.showHidden
          ? entries
          : entries.where((e) => !e.hidden);
      listings[path] = sortEntries(
        visible,
        config.sort,
        kindOf: (e) => env.describe(e.mimeType),
      );
    } on Exception {
      listings[path] = const [];
    }
    notifyListeners();
  }

  /// As pastas das colunas: da primeira até a atual.
  List<String> get columnChain {
    final path = folder;
    if (path == null || !isWithin(columnBase, path)) return [?path];
    final chain = <String>[path];
    var current = path;
    while (current != columnBase && current != '/') {
      current = dirName(current);
      chain.insert(0, current);
    }
    return chain;
  }

  void toggleExpanded(String path) {
    if (!expanded.remove(path)) {
      expanded.add(path);
      unawaited(ensureListing(path));
    }
    notifyListeners();
  }

  /// O que a lista mostra: os itens e, embaixo de cada pasta aberta, os dela,
  /// com a profundidade.
  List<(FsEntry, int)> get treeRows {
    final rows = <(FsEntry, int)>[];
    void add(List<FsEntry> entries, int depth) {
      for (final e in entries) {
        rows.add((e, depth));
        if (e.isDirectory && expanded.contains(e.path)) {
          add(listings[e.path] ?? const [], depth + 1);
        }
      }
    }

    add(items, 0);
    return rows;
  }

  /// Os itens na ordem em que as setas andam (com os ramos abertos da
  /// árvore, no modo lista).
  List<FsEntry> get navigationOrder =>
      mode == ViewMode.list && expanded.isNotEmpty
      ? [for (final (e, _) in treeRows) e]
      : items;

  FsEntry? entryAt(String path) {
    for (final e in navigationOrder) {
      if (e.path == path) return e;
    }
    for (final list in listings.values) {
      for (final e in list) {
        if (e.path == path) return e;
      }
    }
    return null;
  }

  List<FsEntry> get selectedEntries => [
    for (final path in selection) ?entryAt(path),
  ];

  // Seleção

  /// Um clique: só ele; com o Ctrl, entra ou sai; com o Shift, do último
  /// até ele.
  void tap(String path, {bool toggle = false, bool extend = false}) {
    renaming = null;
    if (extend && _anchor != null) {
      _selectRange(_anchor!, path);
    } else if (toggle) {
      if (!selection.remove(path)) selection.add(path);
      _anchor = path;
    } else {
      selection
        ..clear()
        ..add(path);
      _anchor = path;
    }
    cursor = path;
    notifyListeners();
  }

  void _selectRange(String from, String to) {
    final order = navigationOrder.map((e) => e.path).toList();
    final a = order.indexOf(from), b = order.indexOf(to);
    if (a < 0 || b < 0) return;
    selection
      ..clear()
      ..addAll(order.sublist(a < b ? a : b, (a < b ? b : a) + 1));
  }

  void selectAll() {
    selection
      ..clear()
      ..addAll(navigationOrder.map((e) => e.path));
    notifyListeners();
  }

  void clearSelection() {
    if (selection.isEmpty && renaming == null) return;
    selection.clear();
    renaming = null;
    notifyListeners();
  }

  /// O retângulo de seleção: [paths] são os que ele cobre; com [additive]
  /// (o Ctrl), somam aos que já estavam.
  void selectPaths(Iterable<String> paths, {Set<String> base = const {}}) {
    selection
      ..clear()
      ..addAll(base)
      ..addAll(paths);
    if (paths.isNotEmpty) cursor = paths.last;
    notifyListeners();
  }

  /// As setas: [delta] itens para frente ou para trás (no modo ícones, uma
  /// linha é o número de colunas). Com o Shift, a seleção vai junto.
  void moveCursor(int delta, {bool extend = false}) {
    final order = navigationOrder;
    if (order.isEmpty) return;
    final at = cursor == null ? -1 : order.indexWhere((e) => e.path == cursor);
    final next = at < 0
        ? (delta > 0 ? 0 : order.length - 1)
        : (at + delta).clamp(0, order.length - 1);
    final path = order[next].path;
    if (extend) {
      _anchor ??= cursor ?? path;
      _selectRange(_anchor!, path);
      cursor = path;
      notifyListeners();
    } else {
      tap(path);
    }
  }

  String _typed = '';
  Timer? _typedTimer;

  /// Digitar o começo do nome seleciona o primeiro que começa assim.
  void typeAhead(String text) {
    _typedTimer?.cancel();
    _typedTimer = Timer(const Duration(seconds: 1), () => _typed = '');
    _typed += foldName(text);
    for (final e in navigationOrder) {
      if (foldName(e.name).startsWith(_typed)) {
        tap(e.path);
        return;
      }
    }
  }

  void startRename(String path) {
    selection
      ..clear()
      ..add(path);
    cursor = path;
    renaming = path;
    notifyListeners();
  }

  void stopRename() {
    if (renaming == null) return;
    renaming = null;
    notifyListeners();
  }

  bool _disposed = false;

  /// O que chega depois de fechar a aba (uma listagem no meio) não avisa
  /// ninguém.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    config.removeListener(_resort);
    _typedTimer?.cancel();
    unawaited(_watch?.cancel());
    unawaited(_search?.cancel());
    super.dispose();
  }
}

/// A mensagem de um erro de arquivo para quem usa, pelo errno.
String describeError(FileSystemException e) => switch (e.osError?.errorCode) {
  2 => 'A pasta não existe mais.',
  13 || 1 => 'Sem permissão para abrir.',
  20 => 'Não é uma pasta.',
  _ => e.osError?.message ?? e.message,
};
