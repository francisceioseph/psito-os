// examples/player/lib/src/library/library_controller.dart
//
// A biblioteca para as telas: o que está no banco, e a leitura em andamento.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'library_store.dart';
import 'models.dart';
import 'scanner.dart';

/// As consultas ficam aqui, longe dos objetos da tela: a função vai para outro
/// isolate, e só pode levar dados.
extension LibraryQueries on LibraryStore {
  Future<LibraryTotals> totals() => run((db) => db.totals());
  Future<List<Album>> albums() => run((db) => db.albums());
  Future<List<Album>> recentAlbums(int limit) =>
      run((db) => db.recentAlbums(limit));
  Future<List<Track>> albumTracks(int id) => run((db) => db.albumTracks(id));
  Future<List<Track>> mostPlayed(int limit) =>
      run((db) => db.mostPlayed(limit));
  Future<List<Track>> randomTracks(int limit) =>
      run((db) => db.randomTracks(limit));
  Future<Map<String, Track>> tracksAt(List<String> paths) =>
      run((db) => db.tracksAt(paths));
  Future<List<MusicFolder>> folders() => run((db) => db.folders());
  Future<int> addFolder(String path) => run((db) => db.addFolder(path));
  Future<void> removeFolder(int id) => run((db) => db.removeFolder(id));
  Future<void> recordPlay(int id, int at) => run((db) => db.recordPlay(id, at));
  Future<String?> setting(String key) => run((db) => db.setting(key));
  Future<void> setSetting(String key, String value) =>
      run((db) => db.setSetting(key, value));
}

/// Quantas faixas o "Tudo em aleatório" leva para a fila.
const shuffleAllLimit = 500;

/// Onde a pasta nova fica em relação às que já existem.
enum AddFolderResult { added, alreadyInLibrary, notVisible }

class LibraryController extends ChangeNotifier {
  static const _recent = 12;
  static const _top = 6;
  static const _reloadEvery = Duration(seconds: 1);
  static const _etaMinFiles = 10;

  final LibraryStore store;
  final LibraryScanner scanner;

  LibraryController({required this.store, required this.scanner});

  bool loaded = false;
  LibraryTotals totals = const LibraryTotals();
  List<Album> albums = const [];
  List<Album> recent = const [];
  List<Track> mostPlayed = const [];
  List<MusicFolder> folders = const [];

  /// As pastas que não estão lá, por caminho. Um disco desligado, por exemplo.
  Set<String> missing = const {};

  /// A leitura em andamento, ou null.
  ScanProgress? scan;
  ScanSession? _session;
  final _pending = <MusicFolder>[];
  DateTime _lastReload = DateTime.fromMillisecondsSinceEpoch(0);
  final _scanClock = Stopwatch();
  bool _disposed = false;

  bool get empty => loaded && folders.isEmpty;

  /// O que falta da leitura, se já dá para estimar. Parado não conta.
  Duration? get scanRemaining {
    final s = scan;
    if (s == null || s.done < _etaMinFiles || s.paused) return null;
    return _scanClock.elapsed * (s.total - s.done) ~/ s.done;
  }

  Future<void> reload() async {
    final (newTotals, newAlbums, newRecent, top, newFolders) = await (
      store.totals(),
      store.albums(),
      store.recentAlbums(_recent),
      store.mostPlayed(_top),
      store.folders(),
    ).wait;
    if (_disposed) return;
    totals = newTotals;
    albums = newAlbums;
    recent = newRecent;
    mostPlayed = top;
    folders = newFolders;
    missing = {
      for (final folder in newFolders)
        if (!Directory(folder.path).existsSync()) folder.path,
    };
    loaded = true;
    notifyListeners();
  }

  /// Adiciona a pasta e já lê. Uma pasta dentro de outra da biblioteca não entra
  /// de novo, porque as faixas já estão lá.
  Future<AddFolderResult> addFolder(String path) async {
    if (!Directory(path).existsSync()) return AddFolderResult.notVisible;
    for (final folder in folders) {
      if (folder.path == path || p.isWithin(folder.path, path)) {
        return AddFolderResult.alreadyInLibrary;
      }
    }
    await store.addFolder(path);
    await reload();
    final added = folders.firstWhere((folder) => folder.path == path);
    startScan([added]);
    return AddFolderResult.added;
  }

  Future<void> removeFolder(MusicFolder folder) async {
    await store.removeFolder(folder.id);
    await reload();
  }

  /// Lê as pastas, ou todas. Com uma leitura em andamento, entram na fila.
  void startScan([List<MusicFolder>? which]) {
    final list = which ?? folders;
    if (list.isEmpty) return;
    if (_session != null) {
      _pending.addAll(list.where((f) => !_pending.any((o) => o.id == f.id)));
      return;
    }
    final session = scanner.start(list);
    _session = session;
    scan = const ScanProgress();
    _scanClock
      ..reset()
      ..start();
    notifyListeners();
    session.progress.listen(_onProgress, onDone: _onScanDone);
  }

  void _onProgress(ScanProgress progress) {
    if (_disposed) return;
    final paused = scan?.paused ?? false;
    scan = progress.copyWith(paused: paused);
    notifyListeners();
    if (DateTime.now().difference(_lastReload) > _reloadEvery) {
      _lastReload = DateTime.now();
      unawaited(reload());
    }
  }

  void _onScanDone() {
    if (_disposed) return;
    _session = null;
    scan = null;
    unawaited(reload());
    if (_pending.isNotEmpty) {
      final next = List.of(_pending);
      _pending.clear();
      startScan(next);
    }
  }

  void pauseScan() {
    _session?.pause();
    _scanClock.stop();
    scan = scan?.copyWith(paused: true);
    notifyListeners();
  }

  void resumeScan() {
    _session?.resume();
    _scanClock.start();
    scan = scan?.copyWith(paused: false);
    notifyListeners();
  }

  void cancelScan() {
    _pending.clear();
    _session?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    _session?.cancel();
    super.dispose();
  }
}

/// A pasta de música da pessoa: a do `user-dirs.dirs`, ou `~/Music`. Null se não
/// houver nem uma nem outra.
String? userMusicDir(Map<String, String> env) {
  final home = env['HOME'];
  if (home == null) return null;
  final config = env['XDG_CONFIG_HOME'] ?? p.join(home, '.config');
  final dirs = File(p.join(config, 'user-dirs.dirs'));
  final candidates = <String>[];
  if (dirs.existsSync()) {
    final match = RegExp(
      r'^XDG_MUSIC_DIR="(.*)"$',
      multiLine: true,
    ).firstMatch(dirs.readAsStringSync());
    if (match != null) candidates.add(match[1]!.replaceFirst(r'$HOME', home));
  }
  candidates.add(p.join(home, 'Music'));
  for (final candidate in candidates) {
    if (Directory(candidate).existsSync()) return candidate;
  }
  return null;
}

/// Mostra `~` no lugar do home.
String prettyPath(String path, String? home) {
  if (home != null && (path == home || p.isWithin(home, path))) {
    return '~${path.substring(home.length)}';
  }
  return path;
}
