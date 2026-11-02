// examples/player/lib/src/library/library_search.dart
//
// A busca, que fica viva ao abrir um resultado e voltar. Só o último pedido vale.
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'library_controller.dart';
import 'library_store.dart';
import 'models.dart';

enum SearchFilter { all, tracks, albums, artists, folders }

class LibrarySearch extends ChangeNotifier {
  /// O bastante para não consultar a cada letra de quem digita rápido.
  static const debounce = Duration(milliseconds: 80);

  final LibraryStore store;

  LibrarySearch(this.store);

  String query = '';
  SearchFilter filter = SearchFilter.all;
  SearchResults results = const SearchResults();
  Timer? _timer;
  int _latest = 0;
  bool _disposed = false;

  void setFilter(SearchFilter value) {
    filter = value;
    notifyListeners();
  }

  void setQuery(String value) {
    query = value;
    _timer?.cancel();
    if (value.trim().isEmpty) {
      _latest++;
      results = const SearchResults();
      notifyListeners();
      return;
    }
    _timer = Timer(debounce, () => unawaited(refresh()));
  }

  /// Consulta de novo, como depois de a biblioteca mudar.
  Future<void> refresh() async {
    if (query.trim().isEmpty) return;
    final ticket = ++_latest;
    final found = await store.search(query);
    if (_disposed || ticket != _latest) return;
    results = found;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
