import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_services/audio_service.dart';

/// wpctl falso: responde get-volume com [volume] e guarda as outras chamadas.
class _FakeWpctl {
  String volume = 'Volume: 0.40';
  int exitCode = 0;
  final List<String> calls = [];
  int reads = 0;

  /// Quando não é null, os set-volume esperam por ele (simula lentidão).
  Completer<void>? gate;

  Future<ProcessResult> call(String exe, List<String> args) async {
    if (args.first == 'get-volume') {
      reads++;
      return ProcessResult(0, exitCode, volume, exitCode == 0 ? '' : 'erro');
    }
    calls.add(args.join(' '));
    if (args.first == 'set-volume') await gate?.future;
    return ProcessResult(0, 0, '', '');
  }
}

void main() {
  late _FakeWpctl wpctl;
  late StreamController<String> events;
  var subscriptions = 0;

  PipewireAudioService service() => PipewireAudioService(
    run: wpctl.call,
    subscribe: () {
      subscriptions++;
      events = StreamController<String>();
      return events.stream;
    },
  );

  setUp(() {
    wpctl = _FakeWpctl();
    subscriptions = 0;
  });

  test('parseWpctlVolume', () {
    expect(parseWpctlVolume('Volume: 0.40\n'), (0.4, false));
    expect(parseWpctlVolume('Volume: 1.00 [MUTED]'), (1.0, true));
    expect(parseWpctlVolume('Object not found'), isNull);
  });

  test('lê o volume no boot; wpctl falhando fica indisponível', () async {
    final ok = service();
    await ok.ready;
    expect(ok.state.value, const AudioState(available: true, volume: 0.4));
    await ok.dispose();

    wpctl.exitCode = 1;
    final failing = service();
    await failing.ready;
    expect(failing.state.value, AudioState.unavailable);
    await failing.dispose();
  });

  test('setVolume manda o set-volume e tira o mudo', () async {
    wpctl.volume = 'Volume: 0.40 [MUTED]';
    final audio = service();
    await audio.ready;

    await audio.setVolume(0.7);
    expect(wpctl.calls, [
      'set-mute @DEFAULT_AUDIO_SINK@ 0',
      'set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 0.70',
    ]);
    expect(audio.state.value, const AudioState(available: true, volume: 0.7));
    await audio.dispose();
  });

  test('vários setVolume seguidos rodam só o primeiro e o último', () async {
    final audio = service();
    await audio.ready;
    wpctl.gate = Completer();

    final first = audio.setVolume(0.5);
    await Future<void>.delayed(Duration.zero);
    for (final v in [0.6, 0.7, 0.8]) {
      unawaited(audio.setVolume(v));
    }
    wpctl.gate!.complete();
    await first;

    expect(wpctl.calls, [
      'set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 0.50',
      'set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 0.80',
    ]);
    await audio.dispose();
  });

  test('evento de sink relê o volume; de client não', () {
    fakeAsync((async) {
      final audio = service();
      async.flushMicrotasks();
      expect(wpctl.reads, 1);

      events.add("Event 'new' on client #60");
      async.elapse(const Duration(milliseconds: 100));
      expect(wpctl.reads, 1);

      wpctl.volume = 'Volume: 0.90';
      events.add("Event 'change' on sink #52");
      events.add("Event 'change' on sink #52");
      async.elapse(const Duration(milliseconds: 100));
      expect(wpctl.reads, 2);
      expect(audio.state.value.volume, 0.9);
      audio.dispose();
    });
  });

  test('se o pactl subscribe termina, reassina depois de 2 s', () {
    fakeAsync((async) {
      final audio = service();
      async.flushMicrotasks();
      expect(subscriptions, 1);

      events.close();
      async.elapse(const Duration(seconds: 1));
      expect(subscriptions, 1);
      async.elapse(PipewireAudioService.resubscribeDelay);
      expect(subscriptions, 2);
      expect(wpctl.reads, 2);
      audio.dispose();
    });
  });
}
