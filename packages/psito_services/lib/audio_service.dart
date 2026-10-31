// system_shell/lib/services/audio_service.dart
//
// Volume do sink padrão do PipeWire. Sem binding D-Bus estável, usa o wpctl
// para ler e ajustar e o `pactl subscribe` para saber de mudanças de fora.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

@immutable
class AudioState {
  /// False enquanto carrega ou se não há servidor de som ou saída.
  final bool available;

  /// 0–1.
  final double volume;
  final bool muted;

  const AudioState({
    required this.available,
    this.volume = 0,
    this.muted = false,
  });

  static const unavailable = AudioState(available: false);

  /// Silencioso, por mudo ou volume zero.
  bool get silent => muted || volume <= 0;

  @override
  bool operator ==(Object other) =>
      other is AudioState &&
      other.available == available &&
      other.volume == volume &&
      other.muted == muted;

  @override
  int get hashCode => Object.hash(available, volume, muted);
}

abstract class AudioService {
  ValueListenable<AudioState> get state;

  /// [volume] de 0 a 1; mexer no volume tira o mudo.
  Future<void> setVolume(double volume);

  Future<void> setMuted(bool muted);

  Future<void> dispose();
}

/// Lê "Volume: 0.40" ou "Volume: 0.40 [MUTED]".
(double, bool)? parseWpctlVolume(String output) {
  final match = RegExp(r'^Volume:\s+([\d.]+)').firstMatch(output.trim());
  final volume = match == null ? null : double.tryParse(match.group(1)!);
  if (volume == null) return null;
  return (volume, output.contains('[MUTED]'));
}

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

Stream<String> _pactlSubscribe() async* {
  final process = await Process.start('pactl', ['subscribe']);
  // O stderr precisa ser lido, senão o processo pode travar
  unawaited(process.stderr.drain<void>());
  yield* process.stdout.transform(utf8.decoder).transform(const LineSplitter());
}

class PipewireAudioService implements AudioService {
  static const _sink = '@DEFAULT_AUDIO_SINK@';
  static const resubscribeDelay = Duration(seconds: 2);
  static const _debounce = Duration(milliseconds: 50);

  final ProcessRunner _run;
  final Stream<String> Function() _subscribe;
  final _state = ValueNotifier(AudioState.unavailable);

  StreamSubscription<String>? _events;
  Timer? _reread;
  Timer? _resubscribe;
  bool _disposed = false;

  /// set-volume em andamento e o último valor pedido durante ele.
  Future<void>? _setting;
  double? _pendingVolume;

  /// Completa depois da primeira leitura, com ou sem sucesso.
  late final Future<void> ready;

  PipewireAudioService({
    ProcessRunner? run,
    Stream<String> Function()? subscribe,
  }) : _run = run ?? Process.run,
       _subscribe = subscribe ?? _pactlSubscribe {
    ready = _read();
    _listen();
  }

  @override
  ValueListenable<AudioState> get state => _state;

  Future<void> _read() async {
    try {
      final result = await _run('wpctl', ['get-volume', _sink]);
      final parsed = result.exitCode == 0
          ? parseWpctlVolume('${result.stdout}')
          : null;
      if (_disposed) return;
      _state.value = parsed == null
          ? AudioState.unavailable
          : AudioState(available: true, volume: parsed.$1, muted: parsed.$2);
    } catch (e) {
      debugPrint('🦜 Erro lendo o volume: $e');
      if (!_disposed) _state.value = AudioState.unavailable;
    }
  }

  void _listen() {
    _events = _subscribe().listen(
      (line) {
        if (!line.contains(' on sink') && !line.contains(' on server')) return;
        _reread?.cancel();
        _reread = Timer(_debounce, _read);
      },
      onError: (Object e) => debugPrint('🦜 pactl subscribe: $e'),
      // O PipeWire reiniciou ou o pactl não existe: tenta de novo
      onDone: () {
        if (_disposed) return;
        _resubscribe = Timer(resubscribeDelay, () {
          if (_disposed) return;
          _read();
          _listen();
        });
      },
      cancelOnError: true,
    );
  }

  @override
  Future<void> setVolume(double volume) async {
    final v = volume.clamp(0.0, 1.0);
    final current = _state.value;
    if (!current.available) return;
    _state.value = AudioState(available: true, volume: v);
    if (current.muted) await _wpctl(['set-mute', _sink, '0']);

    // Um processo por vez: durante um arraste, só o último valor importa
    if (_setting != null) {
      _pendingVolume = v;
      return;
    }
    _setting = _wpctl(['set-volume', '-l', '1.0', _sink, v.toStringAsFixed(2)]);
    await _setting;
    _setting = null;
    final pending = _pendingVolume;
    _pendingVolume = null;
    if (pending != null && pending != v) await setVolume(pending);
  }

  @override
  Future<void> setMuted(bool muted) async {
    final current = _state.value;
    if (!current.available) return;
    _state.value = AudioState(
      available: true,
      volume: current.volume,
      muted: muted,
    );
    await _wpctl(['set-mute', _sink, muted ? '1' : '0']);
  }

  Future<void> _wpctl(List<String> args) async {
    try {
      final result = await _run('wpctl', args);
      if (result.exitCode != 0) {
        debugPrint('🦜 wpctl ${args.join(' ')}: ${result.stderr}');
      }
    } catch (e) {
      debugPrint('🦜 Erro no wpctl ${args.join(' ')}: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _reread?.cancel();
    _resubscribe?.cancel();
    await _events?.cancel();
    _state.dispose();
  }
}

class FakeAudioService implements AudioService {
  final ValueNotifier<AudioState> _state;

  FakeAudioService([AudioState initial = sample])
    : _state = ValueNotifier(initial);

  static const sample = AudioState(available: true, volume: 0.4);

  @override
  ValueListenable<AudioState> get state => _state;

  void set(AudioState state) => _state.value = state;

  @override
  Future<void> setVolume(double volume) async =>
      _state.value = AudioState(available: true, volume: volume.clamp(0, 1));

  @override
  Future<void> setMuted(bool muted) async => _state.value = AudioState(
    available: true,
    volume: _state.value.volume,
    muted: muted,
  );

  @override
  Future<void> dispose() async => _state.dispose();
}
