// examples/player/lib/src/player/engine.dart
//
// O que o player precisa de um motor de áudio. O app e os testes só veem esta
// interface: trocar o media_kit por outro motor não mexe na tela.
import 'package:flutter/foundation.dart';

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

  const PlayerState({
    this.title,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playing = false,
    this.volume = 1,
    this.format,
    this.error,
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
  }) => PlayerState(
    title: title ?? this.title,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    playing: playing ?? this.playing,
    volume: volume ?? this.volume,
    format: format ?? this.format,
    error: clearError ? null : error ?? this.error,
  );
}

abstract class PlayerEngine {
  ValueListenable<PlayerState> get state;

  /// Abre os arquivos em fila e já toca o primeiro.
  Future<void> open(List<String> paths);
  Future<void> playOrPause();
  Future<void> seek(Duration position);

  /// De 0 a 1.
  Future<void> setVolume(double volume);
  Future<void> dispose();
}
