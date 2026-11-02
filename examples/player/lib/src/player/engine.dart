// examples/player/lib/src/player/engine.dart
//
// O que o player precisa de um motor de áudio. O app e os testes só veem esta
// interface: trocar o media_kit por outro motor não mexe na tela.
import 'package:flutter/foundation.dart';

/// O que repetir ao chegar no fim.
enum PlayerRepeat { off, all, one }

/// O que está tocando.
@immutable
class PlayerState {
  /// O título da faixa, ou null sem faixa.
  final String? title;
  final Duration position;
  final Duration duration;
  final bool playing;

  /// De 0 a 1.
  final double volume;

  /// Como o áudio está saindo, como `flac 96000 Hz s32 2 ch`, se já se sabe.
  final String? format;

  /// O erro da última abertura, nas palavras do motor.
  final String? error;

  /// Os caminhos da fila, na ordem em que vão tocar.
  final List<String> queue;

  /// A posição na fila, ou -1 sem fila.
  final int index;
  final bool shuffle;
  final PlayerRepeat repeat;

  const PlayerState({
    this.title,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playing = false,
    this.volume = 1,
    this.format,
    this.error,
    this.queue = const [],
    this.index = -1,
    this.shuffle = false,
    this.repeat = PlayerRepeat.off,
  });

  PlayerState copyWith({
    String? title,
    Duration? position,
    Duration? duration,
    bool? playing,
    double? volume,
    String? format,
    String? error,
    bool clearError = false,
    List<String>? queue,
    int? index,
    bool? shuffle,
    PlayerRepeat? repeat,
  }) => PlayerState(
    title: title ?? this.title,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    playing: playing ?? this.playing,
    volume: volume ?? this.volume,
    format: format ?? this.format,
    error: clearError ? null : error ?? this.error,
    queue: queue ?? this.queue,
    index: index ?? this.index,
    shuffle: shuffle ?? this.shuffle,
    repeat: repeat ?? this.repeat,
  );
}

abstract class PlayerEngine {
  ValueListenable<PlayerState> get state;

  /// Abre os arquivos em fila, a partir de [index]. Com [start], começa daquele
  /// ponto. Sem [play], fica pronto e parado.
  Future<void> open(
    List<String> paths, {
    int index = 0,
    Duration start = Duration.zero,
    bool play = true,
  });
  Future<void> playOrPause();
  Future<void> next();
  Future<void> previous();

  /// Vai para a faixa nessa posição da fila.
  Future<void> jump(int index);

  /// No fim da fila.
  Future<void> add(String path);

  /// Tira de [from] e deixa em [to], o índice que ela fica tendo.
  Future<void> move(int from, int to);
  Future<void> remove(int index);

  /// Ligar embaralha o que vem depois da faixa atual, que continua tocando, e
  /// desligar volta à ordem de antes.
  Future<void> setShuffle(bool shuffle);
  Future<void> setRepeat(PlayerRepeat repeat);
  Future<void> seek(Duration position);

  /// De 0 a 1.
  Future<void> setVolume(double volume);
  Future<void> dispose();
}
