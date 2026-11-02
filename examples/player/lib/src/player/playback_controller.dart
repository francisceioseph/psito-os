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

  /// Avisa quando o que as telas contam mudou no banco.
  final VoidCallback? onLibraryChanged;

  /// Diz se o arquivo pode tocar agora. Um disco desligado não pode.
  final bool Function(String path)? isAvailable;

  /// Pediram para tocar, e nenhuma faixa está disponível.
  final VoidCallback? onNothingAvailable;

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
    this.onLibraryChanged,
    this.isAvailable,
    this.onNothingAvailable,
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
    onLibraryChanged?.call();
  }

  /// Marca ou desmarca a faixa, e ela já volta certa para quem a tem na fila.
  Future<void> setFavorite(Track track, bool favorite) async {
    if (track.id == 0) return;
    _known[track.path] = track.withFavorite(favorite);
    notifyListeners();
    await store.setFavorite(track.id, favorite);
    onLibraryChanged?.call();
  }

  /// Toca as faixas, a partir de [index]. O que não está disponível fica de fora,
  /// e de uma lista grande vai só um pedaço, começando um pouco antes da escolhida.
  Future<void> playTracks(List<Track> tracks, {int index = 0}) async {
    if (tracks.isEmpty) return;
    final chosen = tracks[index];
    final available = isAvailable;
    final playable = available == null
        ? tracks
        : [
            for (final t in tracks)
              if (available(t.path)) t,
          ];
    if (playable.isEmpty) {
      onNothingAvailable?.call();
      return;
    }
    var at = playable.indexOf(chosen);
    if (at < 0) at = 0;
    final first = (at - queueLimit ~/ 10).clamp(0, playable.length);
    final window = playable.length <= queueLimit
        ? playable
        : playable.sublist(
            first,
            (first + queueLimit).clamp(0, playable.length),
          );
    for (final track in window) {
      _known[track.path] = track;
    }
    resumable = false;
    await engine.open([
      for (final t in window) t.path,
    ], index: playable.length <= queueLimit ? at : at - first);
  }

  /// Toca as faixas embaralhadas, sem mexer no modo aleatório.
  Future<void> shuffleTracks(List<Track> tracks) async =>
      playTracks(List.of(tracks)..shuffle());

  Future<void> playAlbum(int albumId, {int index = 0}) async =>
      playTracks(await store.albumTracks(albumId), index: index);

  Future<void> shuffleAlbum(int albumId) async =>
      shuffleTracks(await store.albumTracks(albumId));

  Future<void> shuffleAll() async =>
      playTracks(await store.randomTracks(queueLimit));

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

  Future<void> albumToQueue(int albumId) async =>
      tracksToQueue(await store.albumTracks(albumId));

  Future<void> tracksToQueue(List<Track> tracks) async {
    for (final track in tracks) {
      await addToQueue(track);
    }
  }

  Future<void> jump(int index) => engine.jump(index);
  Future<void> removeAt(int index) => engine.remove(index);
  Future<void> moveInQueue(int from, int to) => engine.move(from, to);

  /// Tira o que vem depois da atual. Do fim para o começo, para os índices não
  /// andarem.
  Future<void> clearUpcoming() async {
    final s = state;
    for (var i = s.queue.length - 1; i > s.index; i--) {
      await engine.remove(i);
    }
  }

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
    final queue = (session?['queue'] as List?)?.whereType<String>().toList();
    if (queue == null || queue.isEmpty) return;
    final current = (session!['index'] as num? ?? 0).toInt().clamp(
      0,
      queue.length - 1,
    );
    // A faixa de um disco desligado o mpv demoraria a recusar
    final available = isAvailable ?? (_) => true;
    if (!available(queue[current])) return;
    final paths = queue.where(available).toList();
    final index = queue.take(current).where(available).length;
    _known.addAll(await store.tracksAt(paths));
    final start = Duration(
      milliseconds: (session['positionMs'] as num? ?? 0).toInt(),
    );
    resumable = true;
    _restoring = true;
    try {
      await engine.open(paths, index: index, start: start, play: false);
    } on TimeoutException catch (e) {
      // Sem a sessão, o resto da abertura ainda vale
      debugPrint('🎵 a sessão não abriu: $e');
      resumable = false;
      return;
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
