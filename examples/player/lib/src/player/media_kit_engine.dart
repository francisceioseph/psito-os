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
    final stream = _player.stream;
    _subscriptions.addAll([
      stream.playing.listen((v) => _update(_state.value.copyWith(playing: v))),
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
  Future<void> open(List<String> paths) async {
    _update(PlayerState(volume: _state.value.volume));
    await _player.open(Playlist(paths.map(Media.new).toList()));
  }

  @override
  Future<void> playOrPause() => _player.playOrPause();

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
