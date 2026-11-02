// examples/player/lib/src/player/playback_controller.dart
//
// O que está tocando, em faixas da biblioteca. A ordem da fila mora no motor (o
// playlist do mpv, que dá o gapless): aqui fica o caminho para a faixa, o que se
// lembra ao reabrir e a contagem de reproduções.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../library/library_controller.dart';
import '../library/library_store.dart';
import '../library/models.dart';
import 'engine.dart';

/// Voltar reinicia a faixa, em vez de ir à anterior, depois deste ponto.
const restartAfter = Duration(seconds: 3);

/// O que as setas andam.
const seekStep = Duration(seconds: 5);

class PlaybackController extends ChangeNotifier {
  static const _sessionKey = 'session';
  static const _saveEvery = Duration(seconds: 5);

  final PlayerEngine engine;
  final LibraryStore store;
  final int Function() _now;

  /// Avisa quando uma reprodução entra no banco, para as telas contarem.
  final VoidCallback? onPlayRecorded;

  final _known = <String, Track>{};
  int _lastIndex = -1;
  String? _lastPath;
  bool _lastPlaying = false;
  bool _counted = false;
  bool _restoring = false;
  Timer? _saver;

  /// Onde a sessão anterior parou, até a pessoa continuar.
  bool resumable = false;

  PlaybackController({
    required this.engine,
    required this.store,
    this.onPlayRecorded,
    int Function()? now,
  }) : _now = now ?? _clock {
    engine.state.addListener(_onEngine);
    _saver = Timer.periodic(_saveEvery, (_) {
      if (engine.state.value.playing) unawaited(saveSession());
    });
  }

  static int _clock() => DateTime.now().millisecondsSinceEpoch;

  PlayerState get state => engine.state.value;

  Track _track(String path) =>
      _known[path] ?? (_known[path] = Track.fromPath(path));

  List<Track> get queue => [for (final path in state.queue) _track(path)];

  Track? get current {
    final s = state;
    return s.index >= 0 && s.index < s.queue.length
        ? _track(s.queue[s.index])
        : null;
  }

  void _onEngine() {
    final s = engine.state.value;
    final path = s.index >= 0 && s.index < s.queue.length
        ? s.queue[s.index]
        : null;
    final changed = path != _lastPath || s.index != _lastIndex;
    if (path != _lastPath) _counted = false;
    if (changed) {
      _lastIndex = s.index;
      _lastPath = path;
      unawaited(saveSession());
      notifyListeners();
    }
    if (s.playing != _lastPlaying) {
      _lastPlaying = s.playing;
      if (s.playing) resumable = false;
      unawaited(saveSession());
      notifyListeners();
    }
    _maybeCount(s);
  }

  /// Conta quando passa da metade.
  void _maybeCount(PlayerState s) {
    final track = current;
    if (_counted || !s.playing || track == null || track.id == 0) return;
    if (s.duration <= Duration.zero || s.position * 2 < s.duration) return;
    _counted = true;
    unawaited(_recordPlay(track.id));
  }

  Future<void> _recordPlay(int id) async {
    await store.recordPlay(id, _now());
    onPlayRecorded?.call();
  }

  /// Toca as faixas, a partir de [index].
  Future<void> playTracks(List<Track> tracks, {int index = 0}) async {
    if (tracks.isEmpty) return;
    for (final track in tracks) {
      _known[track.path] = track;
    }
    resumable = false;
    await engine.open([for (final t in tracks) t.path], index: index);
  }

  /// Toca as faixas embaralhadas, sem mexer no modo aleatório.
  Future<void> shuffleTracks(List<Track> tracks) async =>
      playTracks(List.of(tracks)..shuffle());

  Future<void> playAlbum(int albumId, {int index = 0}) async =>
      playTracks(await store.albumTracks(albumId), index: index);

  Future<void> shuffleAlbum(int albumId) async =>
      shuffleTracks(await store.albumTracks(albumId));

  Future<void> shuffleAll() async =>
      playTracks(await store.randomTracks(shuffleAllLimit));

  /// Abre arquivos de fora. Os que estão na biblioteca vêm com as tags.
  Future<void> playPaths(List<String> paths) async {
    _known.addAll(await store.tracksAt(paths));
    resumable = false;
    await engine.open(paths);
  }

  /// Entra logo depois da atual.
  Future<void> playNext(Track track) async {
    _known[track.path] = track;
    final s = state;
    if (s.queue.isEmpty) return playTracks([track]);
    await engine.add(track.path);
    await engine.move(s.queue.length, s.index + 1);
  }

  Future<void> addToQueue(Track track) async {
    _known[track.path] = track;
    if (state.queue.isEmpty) return playTracks([track]);
    await engine.add(track.path);
  }

  Future<void> albumToQueue(int albumId) async {
    for (final track in await store.albumTracks(albumId)) {
      await addToQueue(track);
    }
  }

  Future<void> jump(int index) => engine.jump(index);
  Future<void> removeAt(int index) => engine.remove(index);
  Future<void> togglePlay() => engine.playOrPause();
  Future<void> next() => engine.next();

  Future<void> previous() => state.position > restartAfter || state.index <= 0
      ? engine.seek(Duration.zero)
      : engine.previous();

  Future<void> seekBy(Duration delta) {
    final s = state;
    final target = s.position + delta;
    return engine.seek(
      target < Duration.zero
          ? Duration.zero
          : target > s.duration
          ? s.duration
          : target,
    );
  }

  Future<void> toggleShuffle() => engine.setShuffle(!state.shuffle);

  Future<void> cycleRepeat() => engine.setRepeat(switch (state.repeat) {
    PlayerRepeat.off => PlayerRepeat.all,
    PlayerRepeat.all => PlayerRepeat.one,
    PlayerRepeat.one => PlayerRepeat.off,
  });

  /// Grava onde parou. O aleatório não volta: a ordem gravada já é a da fila.
  Future<void> saveSession() async {
    final s = state;
    // Enquanto volta, a posição ainda é 0
    if (_restoring || s.queue.isEmpty) return;
    await store.setSetting(
      _sessionKey,
      jsonEncode({
        'queue': s.queue,
        'index': s.index,
        'positionMs': s.position.inMilliseconds,
        'volume': s.volume,
        'repeat': s.repeat.name,
      }),
    );
  }

  /// Traz a sessão anterior, parada no ponto em que estava. Com [open], abre
  /// esses arquivos em vez da fila, e só o volume e o repetir voltam.
  Future<void> restore({List<String> open = const []}) async {
    final saved = await store.setting(_sessionKey);
    Map<String, Object?>? session;
    try {
      if (saved != null) session = jsonDecode(saved) as Map<String, Object?>;
    } on FormatException catch (e) {
      debugPrint('🎵 sessão ilegível: $e');
    }
    if (session != null) {
      final volume = session['volume'];
      if (volume is num) await engine.setVolume(volume.toDouble());
      final repeat = PlayerRepeat.values.asNameMap()[session['repeat']];
      if (repeat != null) await engine.setRepeat(repeat);
    }
    if (open.isNotEmpty) return playPaths(open);
    final paths = (session?['queue'] as List?)?.whereType<String>().toList();
    if (paths == null || paths.isEmpty) return;
    _known.addAll(await store.tracksAt(paths));
    final index = (session!['index'] as num? ?? 0).toInt().clamp(
      0,
      paths.length - 1,
    );
    final start = Duration(
      milliseconds: (session['positionMs'] as num? ?? 0).toInt(),
    );
    resumable = true;
    _restoring = true;
    try {
      await engine.open(paths, index: index, start: start, play: false);
    } finally {
      _restoring = false;
    }
    // Quem parou depois da metade já contou
    final duration = _known[paths[index]]?.duration ?? Duration.zero;
    _counted = duration > Duration.zero && start * 2 >= duration;
    notifyListeners();
  }

  @override
  void dispose() {
    _saver?.cancel();
    engine.state.removeListener(_onEngine);
    super.dispose();
  }
}
