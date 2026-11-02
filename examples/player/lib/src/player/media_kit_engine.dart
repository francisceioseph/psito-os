// examples/player/lib/src/player/media_kit_engine.dart
//
// O motor de verdade: a libmpv do sistema, pelo FFI do media_kit.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;

import 'engine.dart';

class MediaKitEngine implements PlayerEngine {
  final _state = ValueNotifier(const PlayerState());
  late final Player _player;
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// Lança se a libmpv não abre.
  MediaKitEngine() {
    MediaKit.ensureInitialized();
    _player = Player(
      configuration: const PlayerConfiguration(
        // Só áudio: sem saída de vídeo nem legendas, e 4 MB em vez de 32 MB de
        // leitura adiantada, que num arquivo local não faz falta
        vo: 'null',
        libass: false,
        bufferSize: 4 * 1024 * 1024,
        logLevel: MPVLogLevel.warn,
      ),
    );
    // O padrão do media_kit grava em ~/.cache/mpv, que é para streams
    final native = _player.platform as NativePlayer;
    unawaited(native.setProperty('cache', 'no'));
    unawaited(native.setProperty('cache-on-disk', 'no'));
    // Música não precisa de pouca latência, e o processo no sandbox não tem
    // prioridade de tempo real: 100 ms em vez do quantum do PipeWire (21 ms)
    unawaited(native.setProperty('pipewire-buffer', '100'));
    // A capa embutida conta como vídeo: sem isto, o mpv decodifica a de cada faixa
    unawaited(native.setProperty('vid', 'no'));
    final stream = _player.stream;
    _subscriptions.addAll([
      stream.playing.listen((v) => _update(_state.value.copyWith(playing: v))),
      stream.playlist.listen(
        (v) => _update(
          _state.value.copyWith(
            queue: [for (final media in v.medias) _pathOf(media)],
            index: v.medias.isEmpty ? -1 : v.index,
            // O mpv pula o arquivo que não abre: o erro era da faixa de antes
            clearError: v.index != _state.value.index,
          ),
        ),
      ),
      stream.position.listen(
        (v) => _update(_state.value.copyWith(position: v)),
      ),
      stream.duration.listen((v) {
        _update(_state.value.copyWith(duration: v));
        unawaited(_readTrack());
      }),
      stream.volume.listen(
        (v) => _update(_state.value.copyWith(volume: v / 100)),
      ),
      stream.audioParams.listen((_) => unawaited(_readTrack())),
      stream.error.listen((message) {
        debugPrint('🎵 erro do mpv: $message');
        _update(_state.value.copyWith(error: message));
      }),
      stream.log.listen(
        (log) => debugPrint('🎵 mpv ${log.prefix}: ${log.text}'),
      ),
    ]);
  }

  void _update(PlayerState state) => _state.value = state;

  /// O `Media` guarda o caminho como URI.
  static String _pathOf(Media media) => media.uri.startsWith('file:')
      ? Uri.parse(media.uri).toFilePath()
      : media.uri;

  /// O título e o formato ficam em propriedades que o media_kit não publica.
  Future<void> _readTrack() async {
    final native = _player.platform as NativePlayer;
    final title = await native.getProperty('media-title');
    final codec = await native.getProperty('audio-codec-name');
    final ao = await native.getProperty('current-ao');
    final params = _player.state.audioParams;
    final format = codec.isEmpty || params.sampleRate == null
        ? null
        : '$codec ${params.sampleRate} Hz ${params.format} '
              '${params.channelCount} ch';
    final changed =
        format != null && format != _state.value.format ||
        title != _state.value.title;
    _update(
      _state.value.copyWith(
        title: title.isEmpty ? null : title,
        format: format,
      ),
    );
    if (changed && format != null) {
      debugPrint('🎵 tocando "$title": $format, saída $ao');
    }
  }

  @override
  ValueListenable<PlayerState> get state => _state;

  @override
  Future<void> open(
    List<String> paths, {
    int index = 0,
    Duration start = Duration.zero,
    bool play = true,
  }) async {
    final old = _state.value;
    _update(
      PlayerState(volume: old.volume, shuffle: false, repeat: old.repeat),
    );
    await _player.setShuffle(false);
    await _player.open(
      Playlist(paths.map(Media.new).toList(), index: index),
      play: play,
    );
    if (start > Duration.zero) {
      // Antes de o arquivo carregar, o mpv ignora o seek
      await _player.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(const Duration(seconds: 5));
      await _player.seek(start);
    }
  }

  @override
  Future<void> playOrPause() => _player.playOrPause();

  @override
  Future<void> next() => _player.next();

  @override
  Future<void> previous() => _player.previous();

  @override
  Future<void> jump(int index) => _player.jump(index);

  @override
  Future<void> add(String path) => _player.add(Media(path));

  @override
  Future<void> move(int from, int to) => _player.move(from, to);

  @override
  Future<void> remove(int index) => _player.remove(index);

  @override
  Future<void> setShuffle(bool shuffle) async {
    await _player.setShuffle(shuffle);
    _update(_state.value.copyWith(shuffle: shuffle));
    // O mpv embaralha a fila inteira: a atual vai para o começo, para todo o
    // resto ainda tocar
    final index = _player.state.playlist.index;
    if (shuffle && index > 0) await _player.move(index, 0);
  }

  @override
  Future<void> setRepeat(PlayerRepeat repeat) async {
    await _player.setPlaylistMode(switch (repeat) {
      PlayerRepeat.off => PlaylistMode.none,
      PlayerRepeat.all => PlaylistMode.loop,
      PlayerRepeat.one => PlaylistMode.single,
    });
    _update(_state.value.copyWith(repeat: repeat));
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume * 100);

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    _state.dispose();
  }
}
