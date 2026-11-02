// examples/player/lib/src/library/library_controller.dart
//
// A biblioteca para as telas: o que está no banco, e a leitura em andamento.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'folder_watcher.dart';
import 'library_db.dart';
import 'library_store.dart';
import 'm3u.dart';
import 'models.dart';
import 'scanner.dart';

/// As consultas ficam aqui, longe dos objetos da tela: a função vai para outro
/// isolate, e só pode levar dados.
extension LibraryQueries on LibraryStore {
  Future<LibraryTotals> totals() => run((db) => db.totals());
  Future<List<Album>> albums([AlbumSort sort = AlbumSort.title]) =>
      run((db) => db.albums(sort));
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
  Future<List<Track>> tracks(TrackQuery query) => run((db) => db.tracks(query));
  Future<List<String>> formats() => run((db) => db.formats());
  Future<List<Artist>> artists() => run((db) => db.artists());
  Future<List<Album>> artistAlbums(int id) => run((db) => db.artistAlbums(id));
  Future<List<Genre>> genres() => run((db) => db.genres());
  Future<List<MusicDir>> dirs() => run((db) => db.dirs());
  Future<void> setFavorite(int id, bool favorite) =>
      run((db) => db.setFavorite(id, favorite));
  Future<SearchResults> search(String query) => run((db) => db.search(query));
  Future<List<Playlist>> playlists() => run((db) => db.playlists());
  Future<List<Playlist>> autoPlaylists() => run((db) => db.autoPlaylists());
  Future<List<Track>> playlistTracks(int id) =>
      run((db) => db.playlistTracks(id));
  Future<List<Track>> favoriteTracks() => run((db) => db.favorites());
  Future<List<Track>> topTracks() =>
      run((db) => db.mostPlayed(LibraryDb.mostPlayedSize));
  Future<List<Track>> newestTracks() =>
      run((db) => db.recentlyAdded(LibraryDb.recentlyAddedSize));
  Future<int> createPlaylist(String name, int now, [List<String>? paths]) =>
      run((db) => db.createPlaylist(name, now, paths ?? const []));
  Future<void> renamePlaylist(int id, String name, int now) =>
      run((db) => db.renamePlaylist(id, name, now));
  Future<void> deletePlaylist(int id) => run((db) => db.deletePlaylist(id));
  Future<void> addToPlaylist(int id, List<String> paths, int now) =>
      run((db) => db.addToPlaylist(id, paths, now));
  Future<void> removeFromPlaylist(int id, int index, int now) =>
      run((db) => db.removeFromPlaylist(id, index, now));
  Future<void> movePlaylistTrack(int id, int from, int to, int now) =>
      run((db) => db.movePlaylistTrack(id, from, to, now));
  Future<TrackDetails?> trackDetails(String path) =>
      run((db) => db.trackDetails(path));
  Future<int> lyricsOffset(String path) => run((db) => db.lyricsOffset(path));
  Future<void> setLyricsOffset(String path, int offsetMs) =>
      run((db) => db.setLyricsOffset(path, offsetMs));
  Future<String?> setting(String key) => run((db) => db.setting(key));
  Future<void> setSetting(String key, String value) =>
      run((db) => db.setSetting(key, value));
}

/// O máximo de faixas numa fila. A lista de músicas pode ter dezenas de milhares,
/// e cada uma delas vira um item no mpv.
const queueLimit = 500;

/// As seções da Biblioteca, na ordem dos filtros.
enum LibrarySection { albums, artists, tracks, folders, playlists, genres }

enum ArtistSort { name, tracks }

enum GenreSort { tracks, name }

enum PlaylistFilter { all, mine, automatic }

/// O que a importação achou.
class PlaylistImport {
  final int id;
  final int tracks;
  final int remote;

  const PlaylistImport(this.id, this.tracks, this.remote);
}

/// Onde a pasta nova fica em relação às que já existem.
enum AddFolderResult { added, alreadyInLibrary, notVisible }

class LibraryController extends ChangeNotifier {
  static const _recent = 12;
  static const _top = 6;
  static const _reloadEvery = Duration(seconds: 1);
  static const _etaMinFiles = 10;
  static const _watchDebounce = Duration(seconds: 2);
  static const _pollEvery = Duration(seconds: 15);
  static const _browseKey = 'browse';
  static const _watchKey = 'watchFolders';

  final LibraryStore store;
  final LibraryScanner scanner;
  final FolderWatcher? watcher;
  final int Function() _now;

  LibraryController({
    required this.store,
    required this.scanner,
    this.watcher,
    int Function()? now,
  }) : _now = now ?? _clock {
    _poll = Timer.periodic(_pollEvery, (_) => unawaited(pollFolders()));
  }

  static int _clock() => DateTime.now().millisecondsSinceEpoch;

  bool loaded = false;
  LibraryTotals totals = const LibraryTotals();
  List<Album> albums = const [];
  List<Album> recent = const [];
  List<Track> mostPlayed = const [];
  List<MusicFolder> folders = const [];

  List<Artist> artists = const [];
  List<Genre> genres = const [];
  List<MusicDir> dirs = const [];
  List<String> formats = const [];
  List<Playlist> playlists = const [];
  List<Playlist> autoPlaylists = const [];

  /// Sobe a cada recarga, para as telas com consulta própria saberem.
  int revision = 0;

  /// As pastas que não estão lá, por caminho. Um disco desligado, por exemplo.
  Set<String> missing = const {};

  /// As pastas que a conferência disse que estão vazias, sem estar.
  Set<String> _emptied = const {};

  /// O que mudou em cada pasta e ainda não foi lido, por id.
  Map<int, int> pending = const {};

  /// Observar as pastas. Vem ligado, como no esboço.
  bool watching = true;

  // O que a Biblioteca mostra, e que volta ao reabrir
  LibrarySection section = LibrarySection.albums;
  AlbumSort albumSort = AlbumSort.title;
  ArtistSort artistSort = ArtistSort.name;
  GenreSort genreSort = GenreSort.tracks;
  bool albumsAsList = false;
  TrackQuery songQuery = const TrackQuery();
  List<Track> songs = const [];

  // Durante a sessão, para voltar de uma playlist como estava
  PlaylistFilter playlistFilter = PlaylistFilter.all;
  bool playlistSortByName = false;

  /// A leitura em andamento, ou null.
  ScanProgress? scan;
  ScanSession? _session;
  final _pending = <MusicFolder>[];
  DateTime _lastReload = DateTime.fromMillisecondsSinceEpoch(0);
  final _scanClock = Stopwatch();
  bool _disposed = false;
  bool _quiet = false;
  bool _cancelled = false;
  bool _browseLoaded = false;
  late final Timer _poll;
  Timer? _changedTimer;
  final _changed = <String>{};

  /// A leitura que a pessoa pediu, para mostrar. A que vem de observar as pastas
  /// corre em silêncio.
  ScanProgress? get visibleScan => _quiet ? null : scan;

  /// O arquivo está numa pasta que não está lá agora.
  bool isMissing(String path) =>
      missing.any((folder) => p.isWithin(folder, path));

  bool get empty => loaded && folders.isEmpty;

  /// O que falta da leitura, se já dá para estimar. Parado não conta.
  Duration? get scanRemaining {
    final s = scan;
    if (s == null || s.done < _etaMinFiles || s.paused) return null;
    return _scanClock.elapsed * (s.total - s.done) ~/ s.done;
  }

  Future<void> _loadBrowse() async {
    if (_browseLoaded) return;
    _browseLoaded = true;
    final (browse, watch) = await (
      store.setting(_browseKey),
      store.setting(_watchKey),
    ).wait;
    watching = watch != 'off';
    if (browse == null) return;
    try {
      final saved = jsonDecode(browse) as Map<String, Object?>;
      section = LibrarySection.values.asNameMap()[saved['section']] ?? section;
      albumSort = AlbumSort.values.asNameMap()[saved['albumSort']] ?? albumSort;
      artistSort =
          ArtistSort.values.asNameMap()[saved['artistSort']] ?? artistSort;
      genreSort = GenreSort.values.asNameMap()[saved['genreSort']] ?? genreSort;
      albumsAsList = saved['albumsAsList'] == true;
      songQuery = TrackQuery(
        sort:
            TrackSort.values.asNameMap()[saved['songSort']] ?? TrackSort.title,
        ascending: saved['songAscending'] != false,
      );
    } on FormatException catch (e) {
      debugPrint('🎵 preferências ilegíveis: $e');
    }
  }

  void _saveBrowse() => unawaited(
    store.setSetting(
      _browseKey,
      jsonEncode({
        'section': section.name,
        'albumSort': albumSort.name,
        'artistSort': artistSort.name,
        'genreSort': genreSort.name,
        'albumsAsList': albumsAsList,
        'songSort': songQuery.sort.name,
        'songAscending': songQuery.ascending,
      }),
    ),
  );

  Future<void> reload() async {
    await _loadBrowse();
    final (newTotals, newAlbums, newRecent, top, newFolders) = await (
      store.totals(),
      store.albums(albumSort),
      store.recentAlbums(_recent),
      store.mostPlayed(_top),
      store.folders(),
    ).wait;
    final (newArtists, newGenres, newDirs, newFormats) = await (
      store.artists(),
      store.genres(),
      store.dirs(),
      store.formats(),
    ).wait;
    final (manual, automatic) = await (
      store.playlists(),
      store.autoPlaylists(),
    ).wait;
    // A lista inteira de músicas só quando alguém está olhando
    final newSongs = section == LibrarySection.tracks
        ? await store.tracks(songQuery)
        : songs;
    final newMissing = await _missingOf(newFolders);
    if (_disposed) return;
    totals = newTotals;
    albums = newAlbums;
    recent = newRecent;
    mostPlayed = top;
    folders = newFolders;
    artists = newArtists;
    genres = newGenres;
    dirs = newDirs;
    formats = newFormats;
    playlists = manual;
    autoPlaylists = automatic;
    songs = newSongs;
    missing = newMissing;
    revision++;
    loaded = true;
    _syncWatcher();
    notifyListeners();
  }

  Future<Set<String>> _missingOf(List<MusicFolder> list) async {
    final found = <String>{};
    for (final folder in list) {
      if (_emptied.contains(folder.path) ||
          !await scanner.folderExists(folder.path)) {
        found.add(folder.path);
      }
    }
    return found;
  }

  void _syncWatcher() => watcher?.watch(
    watching
        ? {
            for (final folder in folders)
              if (!missing.contains(folder.path)) folder.path,
          }
        : const {},
    _onFolderChanged,
  );

  void _onFolderChanged(String folder) {
    _changed.add(folder);
    // Copiar um álbum dá centenas de avisos seguidos
    _changedTimer?.cancel();
    _changedTimer = Timer(_watchDebounce, () {
      final list = folders.where((f) => _changed.contains(f.path)).toList();
      _changed.clear();
      if (list.isNotEmpty) unawaited(checkFolders(list));
    });
  }

  /// Um disco ligado ou desligado não avisa ninguém: olha de tempos em tempos.
  @visibleForTesting
  Future<void> pollFolders() async {
    if (_disposed || folders.isEmpty) return;
    final list = folders;
    final absent = <String>{
      for (final folder in list)
        if (!await scanner.folderExists(folder.path)) folder.path,
    };
    if (_disposed) return;
    // A pasta que voltou pode estar vazia: quem diz é a conferência
    final back = [
      for (final folder in list)
        if (missing.contains(folder.path) && !absent.contains(folder.path))
          folder,
    ];
    if (back.isNotEmpty) await checkFolders(back);
    if (_disposed || absent.difference(missing).isEmpty) return;
    await reload();
  }

  /// Vê o que mudou nas pastas, sem ler tags. Observando, já lê o que mudou.
  Future<void> checkFolders([List<MusicFolder>? which]) async {
    final list = which ?? folders;
    if (list.isEmpty) return;
    final found = await scanner.check(list);
    if (_disposed) return;
    pending = {
      ...pending,
      for (final e in found.entries) e.key: e.value.changes,
    };
    final emptied = {..._emptied};
    for (final folder in list) {
      final check = found[folder.id];
      if (check == null) continue;
      check.unavailable
          ? emptied.add(folder.path)
          : emptied.remove(folder.path);
    }
    final changedEmptied = !setEquals(emptied, _emptied);
    _emptied = emptied;
    if (changedEmptied) {
      await reload();
    } else {
      notifyListeners();
    }
    if (_disposed || !watching || _cancelled) return;
    final stale = list.where((f) => (pending[f.id] ?? 0) > 0).toList();
    if (stale.isNotEmpty) _startScan(stale, quiet: true);
  }

  Future<void> setWatching(bool value) async {
    watching = value;
    _cancelled = false;
    await store.setSetting(_watchKey, value ? 'on' : 'off');
    _syncWatcher();
    notifyListeners();
    if (value) await checkFolders();
  }

  void setSection(LibrarySection value) {
    section = value;
    _saveBrowse();
    notifyListeners();
    if (value == LibrarySection.tracks) unawaited(_reloadSongs());
  }

  Future<void> _reloadSongs() async {
    final query = songQuery;
    final found = await store.tracks(query);
    if (_disposed || !identical(query, songQuery)) return;
    songs = found;
    notifyListeners();
  }

  void setSongQuery(TrackQuery query) {
    songQuery = query;
    _saveBrowse();
    unawaited(_reloadSongs());
  }

  Future<void> setAlbumSort(AlbumSort value) async {
    albumSort = value;
    _saveBrowse();
    final found = await store.albums(value);
    if (_disposed || value != albumSort) return;
    albums = found;
    notifyListeners();
  }

  void setAlbumsAsList(bool value) {
    albumsAsList = value;
    _saveBrowse();
    notifyListeners();
  }

  void setArtistSort(ArtistSort value) {
    artistSort = value;
    _saveBrowse();
    notifyListeners();
  }

  void setPlaylistFilter(PlaylistFilter value) {
    playlistFilter = value;
    notifyListeners();
  }

  void setPlaylistSortByName(bool value) {
    playlistSortByName = value;
    notifyListeners();
  }

  void setGenreSort(GenreSort value) {
    genreSort = value;
    _saveBrowse();
    notifyListeners();
  }

  /// Os artistas na ordem escolhida. A consulta já vem por nome.
  List<Artist> get sortedArtists => artistSort == ArtistSort.name
      ? artists
      : (List.of(artists)..sort((a, b) => b.tracks - a.tracks));

  /// Os gêneros na ordem escolhida. A consulta já vem por quantidade.
  List<Genre> get sortedGenres => genreSort == GenreSort.tracks
      ? genres
      : (List.of(genres)..sort((a, b) {
          if (a.name.isEmpty != b.name.isEmpty) return a.name.isEmpty ? 1 : -1;
          return compareFolded(a.name, b.name);
        }));

  // As playlists

  Future<int> createPlaylist(String name, [List<String>? paths]) async {
    final id = await store.createPlaylist(name, _now(), paths);
    await reload();
    return id;
  }

  Future<void> renamePlaylist(Playlist playlist, String name) async {
    await store.renamePlaylist(playlist.id, name, _now());
    await reload();
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    await store.deletePlaylist(playlist.id);
    await reload();
  }

  Future<void> addToPlaylist(int id, List<String> paths) async {
    await store.addToPlaylist(id, paths, _now());
    await reload();
  }

  Future<void> removeFromPlaylist(Playlist playlist, int index) async {
    await store.removeFromPlaylist(playlist.id, index, _now());
    await reload();
  }

  Future<void> movePlaylistTrack(Playlist playlist, int from, int to) async {
    await store.movePlaylistTrack(playlist.id, from, to, _now());
    await reload();
  }

  /// As faixas de qualquer playlist, automática ou não.
  Future<List<Track>> tracksOf(Playlist playlist) => switch (playlist.kind) {
    PlaylistKind.manual => store.playlistTracks(playlist.id),
    PlaylistKind.favorites => store.favoriteTracks(),
    PlaylistKind.mostPlayed => store.topTracks(),
    PlaylistKind.recentlyAdded => store.newestTracks(),
  };

  /// Cria uma playlist a partir do arquivo, com o nome dele. Lança se não dá para
  /// ler.
  Future<PlaylistImport> importM3u(String path) async {
    final entries = parseM3u(await File(path).readAsBytes(), p.dirname(path));
    final id = await createPlaylist(
      p.basenameWithoutExtension(path),
      entries.paths,
    );
    return PlaylistImport(id, entries.paths.length, entries.remote);
  }

  /// Grava as faixas no arquivo. Lança se não dá para escrever.
  Future<void> exportM3u(List<Track> tracks, String path) =>
      File(path).writeAsString(writeM3u(tracks));

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
  void startScan([List<MusicFolder>? which]) => _startScan(which);

  void _startScan(List<MusicFolder>? which, {bool quiet = false}) {
    final list = which ?? folders;
    if (list.isEmpty) return;
    if (_session != null) {
      // Um pedido da pessoa mostra a leitura que já ia em silêncio
      if (!quiet) _quiet = false;
      _pending.addAll(list.where((f) => !_pending.any((o) => o.id == f.id)));
      return;
    }
    if (!quiet) _cancelled = false;
    _quiet = quiet;
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
    if (_pending.isNotEmpty) {
      final next = List.of(_pending);
      _pending.clear();
      unawaited(reload());
      _startScan(next, quiet: _quiet);
      return;
    }
    _quiet = false;
    unawaited(() async {
      await reload();
      // A situação das pastas muda com o que acabou de ser lido
      await checkFolders();
    }());
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
    _cancelled = true;
    _pending.clear();
    _session?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll.cancel();
    _changedTimer?.cancel();
    watcher?.dispose();
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
