// Cliente de referência do spike do compositor (fase 3).
//
// Um app Flutter Linux comum, sem nada do Psito. Registra em PROBE_LOG:
//   recv,<seq>,<t_ns>                       a cada tecla A (CLOCK_MONOTONIC)
//   frame,<build_start_us>,<raster_finish_us>  a cada frame (FrameTiming)
// PROBE_ANIMATE=1 (ou Espaço) liga a animação, para medir fps.
import 'dart:ffi';
import 'dart:io';
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

final class _Timespec extends Struct {
  @Int64()
  external int sec;
  @Int64()
  external int nsec;
}

typedef _ClockGettime = Int32 Function(Int32, Pointer<_Timespec>);
typedef _ClockGettimeDart = int Function(int, Pointer<_Timespec>);

const _clockMonotonic = 1;
final _clockGettime = DynamicLibrary.process()
    .lookupFunction<_ClockGettime, _ClockGettimeDart>('clock_gettime');
final _timespec = calloc<_Timespec>();

/// O mesmo relógio do injetor e do FrameTiming do engine.
int monotonicNs() {
  _clockGettime(_clockMonotonic, _timespec);
  return _timespec.ref.sec * 1000000000 + _timespec.ref.nsec;
}

class ProbeLog {
  final RandomAccessFile? _file;

  ProbeLog(String? path)
    : _file = path == null ? null : File(path).openSync(mode: FileMode.append);

  void write(String line) => _file?.writeStringSync('$line\n');
}

void main() {
  final log = ProbeLog(Platform.environment['PROBE_LOG']);
  runApp(
    ProbeApp(
      log: log,
      animate: Platform.environment['PROBE_ANIMATE'] == '1',
    ),
  );
}

class ProbeApp extends StatelessWidget {
  final ProbeLog log;
  final bool animate;

  const ProbeApp({super.key, required this.log, required this.animate});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: ProbeView(log: log, animate: animate),
  );
}

class ProbeView extends StatefulWidget {
  final ProbeLog log;
  final bool animate;

  const ProbeView({super.key, required this.log, required this.animate});

  @override
  State<ProbeView> createState() => _ProbeViewState();
}

class _ProbeViewState extends State<ProbeView>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  final _events = <String>[];
  var _seq = 0;
  var _frames = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    if (widget.animate) _spin.repeat();
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _spin.dispose();
    super.dispose();
  }

  // Sem setState aqui: redesenhar a cada frame deixaria o app sempre ativo
  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _frames++;
      widget.log.write(
        'frame,${t.timestampInMicroseconds(FramePhase.buildStart)},'
        '${t.timestampInMicroseconds(FramePhase.rasterFinish)}',
      );
    }
  }

  void _remember(String event) {
    setState(() {
      _events.insert(0, event);
      if (_events.length > 6) _events.removeLast();
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.keyA) {
      widget.log.write('recv,${_seq++},${monotonicNs()}');
    } else if (event.logicalKey == LogicalKeyboardKey.space) {
      _spin.isAnimating ? _spin.stop() : _spin.repeat();
    }
    _remember('tecla ${event.logicalKey.keyLabel}');
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Listener(
        onPointerDown: (e) => _remember(
          'clique ${e.localPosition.dx.round()},${e.localPosition.dy.round()}',
        ),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                RotationTransition(
                  turns: _spin,
                  child: Container(width: 64, height: 64, color: Colors.amber),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('frames: $_frames   teclas A: $_seq'),
                      const SizedBox(height: 8),
                      for (final e in _events)
                        Text(e, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
