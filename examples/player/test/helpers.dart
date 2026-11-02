import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_player/player_app.dart';
import 'package:psito_player/src/library/library_db.dart';
import 'package:psito_player/src/library/library_store.dart';
import 'package:psito_player/src/library/models.dart';
import 'package:psito_player/src/library/scanner.dart';
import 'package:psito_player/src/lyrics/lyrics_loader.dart';
import 'package:psito_player/src/player/engine.dart';
import 'package:psito_sdk/psito_sdk.dart';

/// Um motor em memória, com a fila como a do mpv: o aleatório inverte o que vem
/// depois da atual, para o teste saber a ordem.
class FakeEngine implements PlayerEngine {
  final _state = ValueNotifier(const PlayerState());
  final opened = <List<String>>[];
  final seeks = <Duration>[];
  List<String>? _beforeShuffle;
  bool disposed = false;

  void set(PlayerState state) => _state.value = state;

  @override
  ValueNotifier<PlayerState> get state => _state;

  @override
  Future<void> open(
    List<String> paths, {
    int index = 0,
    Duration start = Duration.zero,
    bool play = true,
  }) async {
    opened.add(paths);
    _state.value = _state.value.copyWith(
      queue: paths,
      index: index,
      position: start,
      duration: const Duration(minutes: 3, seconds: 7),
      playing: play,
      title: paths[index].split('/').last,
      shuffle: false,
    );
  }

  @override
  Future<void> playOrPause() async =>
      _state.value = _state.value.copyWith(playing: !_state.value.playing);

  void _go(int index) => _state.value = _state.value.copyWith(
    index: index,
    position: Duration.zero,
  );

  @override
  Future<void> next() async {
    final s = _state.value;
    if (s.index + 1 < s.queue.length) _go(s.index + 1);
  }

  @override
  Future<void> previous() async {
    if (_state.value.index > 0) _go(_state.value.index - 1);
  }

  @override
  Future<void> jump(int index) async => _go(index);

  @override
  Future<void> add(String path) async => _state.value = _state.value.copyWith(
    queue: [..._state.value.queue, path],
  );

  @override
  Future<void> move(int from, int to) async {
    final s = _state.value;
    final queue = List.of(s.queue);
    final path = queue.removeAt(from);
    queue.insert(to, path);
    _state.value = s.copyWith(
      queue: queue,
      index: queue.indexOf(s.queue[s.index]),
    );
  }

  @override
  Future<void> remove(int index) async {
    final s = _state.value;
    final queue = List.of(s.queue)..removeAt(index);
    _state.value = s.copyWith(
      queue: queue,
      index: index < s.index ? s.index - 1 : s.index,
    );
  }

  @override
  Future<void> setShuffle(bool shuffle) async {
    final s = _state.value;
    if (shuffle) {
      _beforeShuffle = s.queue;
      final current = s.queue[s.index];
      final rest = [...s.queue]..removeAt(s.index);
      _state.value = s.copyWith(
        shuffle: true,
        queue: [current, ...rest.reversed],
        index: 0,
      );
    } else {
      final queue = _beforeShuffle ?? s.queue;
      _state.value = s.copyWith(
        shuffle: false,
        queue: queue,
        index: queue.indexOf(s.queue[s.index]),
      );
    }
  }

  @override
  Future<void> setRepeat(PlayerRepeat repeat) async =>
      _state.value = _state.value.copyWith(repeat: repeat);

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    _state.value = _state.value.copyWith(position: position);
  }

  @override
  Future<void> setVolume(double volume) async =>
      _state.value = _state.value.copyWith(volume: volume);

  @override
  Future<void> dispose() async => disposed = true;
}

class FakeSession implements ScanSession {
  final controller = StreamController<ScanProgress>();
  final List<MusicFolder> folders;
  final log = <String>[];

  FakeSession(this.folders);

  @override
  Stream<ScanProgress> get progress => controller.stream;
  @override
  void pause() => log.add('pause');
  @override
  void resume() => log.add('resume');
  @override
  void cancel() => log.add('cancel');
}

class FakeScanner implements LibraryScanner {
  final sessions = <FakeSession>[];

  @override
  ScanSession start(List<MusicFolder> folders) {
    final session = FakeSession(folders);
    sessions.add(session);
    return session;
  }

  /// O que cada pasta tem a dizer na conferência, por id.
  Map<int, FolderCheck> checks = const {};

  @override
  Future<Map<int, FolderCheck>> check(List<MusicFolder> folders) async =>
      checks;

  /// As pastas que não estão lá.
  Set<String> gone = const {};

  @override
  Future<bool> folderExists(String path) async => !gone.contains(path);
}

/// Grava um álbum no banco. Devolve o id dele.
int seedAlbum(
  LibraryDb db, {
  String folder = '/m',
  String album = 'Maré Alta',
  String artist = 'Coral Vento',
  int tracks = 3,
  int firstAdded = 1000,
}) {
  final folderId = db.addFolder(folder);
  var albumId = 0;
  for (var i = 1; i <= tracks; i++) {
    albumId = db.upsertTrack(
      ScannedTrack(
        path: '$folder/$album/$i.flac',
        title: '$album $i',
        artist: artist,
        albumArtist: artist,
        album: album,
        trackNumber: i,
        year: 2024,
        durationMs: 180000,
        size: 1000000,
        mtime: 1,
      ),
      folderId,
      firstAdded + i,
    );
  }
  db.markScanned(folderId, 1000);
  return albumId;
}

/// Abre o player inteiro, com o banco em memória e os fakes.
Future<void> pumpPlayer(
  WidgetTester tester, {
  FakeEngine? engine,
  PlayerEngine Function()? createEngine,
  LibraryDb? db,
  LibraryScanner? scanner,
  List<String> initialPaths = const [],
  String? picked,
  String? pickedPlaylist,
  String? pickedSave,
  String? musicDir,
  Color accent = const Color(0xFFFFC107),
  Future<LibraryServices> Function()? openLibrary,
  LyricsLoader? readLyrics,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: psitoTheme(accent),
      localizationsDelegates: psitoLocalizationsDelegates(
        const PlayerApp().localizationsDelegates,
      ),
      supportedLocales: psitoLocales,
      home: PlayerView(
        createEngine: createEngine ?? () => engine ?? FakeEngine(),
        openLibrary:
            openLibrary ??
            () async => LibraryServices(
              DirectStore(db ?? LibraryDb.memory()),
              scanner ?? FakeScanner(),
            ),
        initialPaths: initialPaths,
        musicDir: musicDir,
        pickFolder: (_) async => picked,
        pickPlaylistFile: (_) async => pickedPlaylist,
        pickSaveFile: (_, _) async => pickedSave,
        readLyrics: readLyrics ?? (_) async => null,
      ),
    ),
  );
  // A biblioteca abre em microtarefas
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void setWindow(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
