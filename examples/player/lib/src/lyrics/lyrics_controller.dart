// examples/player/lib/src/lyrics/lyrics_controller.dart
//
// A letra do que está tocando e a linha da vez. Só lê do disco com o painel aberto
// na letra, e só avisa a tela quando a linha muda.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../library/library_controller.dart';
import '../library/library_store.dart';
import '../player/playback_controller.dart';
import 'lyrics.dart';
import 'lyrics_loader.dart';

class LyricsController extends ChangeNotifier {
  /// O passo dos botões de ajuste.
  static const offsetStep = 100;

  final PlaybackController playback;
  final LibraryStore store;
  final LyricsLoader _load;

  bool _active = false;
  bool _disposed = false;
  String? _path;

  /// A letra da faixa, ou null sem nenhuma ou enquanto carrega.
  Lyrics? lyrics;
  bool loading = false;

  /// O ajuste da faixa, em milissegundos. Positivo adianta a letra, como o
  /// `[offset]` do LRC, a que ele se soma.
  int offsetMs = 0;

  /// A linha da vez, ou -1.
  final line = ValueNotifier(-1);

  static const _maxEstimate = Duration(milliseconds: 500);
  static const _slack = Duration(milliseconds: 200);
  final _sinceReport = Stopwatch()..start();
  Duration _reported = Duration.zero;
  Timer? _nextLine;

  LyricsController({
    required this.playback,
    required this.store,
    this._load = loadLyrics,
  }) {
    playback.engine.state.addListener(_onEngine);
  }

  /// Ligado, acompanha a faixa. Desligado, não abre arquivo nenhum.
  set active(bool value) {
    if (_active == value) return;
    _active = value;
    if (value) {
      _onEngine();
    } else {
      _nextLine?.cancel();
    }
  }

  void _onEngine() {
    if (!_active) return;
    final path = playback.current?.path;
    if (path != _path) unawaited(_loadTrack(path));
    _syncLine();
  }

  /// Onde a música está. O motor avisa a posição de tempos em tempos (na VM, com
  /// até 140 ms de atraso na linha), e entre um aviso e outro ela anda.
  Duration get _position {
    final s = playback.state;
    if (s.position != _reported) {
      _reported = s.position;
      _sinceReport.reset();
    }
    if (!s.playing) return s.position;
    final elapsed = _sinceReport.elapsed;
    return s.position + (elapsed > _maxEstimate ? _maxEstimate : elapsed);
  }

  void _syncLine() {
    _nextLine?.cancel();
    final lyrics = this.lyrics;
    if (lyrics == null) {
      line.value = -1;
      return;
    }
    final at = _position + Duration(milliseconds: offsetMs);
    var found = lyrics.lineAt(at);
    final shown = line.value;
    // O aviso pode vir um pouco atrás da conta, e a linha não volta por isso
    if (found == shown - 1 && lyrics.lines[shown].time - at < _slack) {
      found = shown;
    }
    line.value = found;
    if (!playback.state.playing || found + 1 >= lyrics.lines.length) return;
    final wait = lyrics.lines[found + 1].time - at;
    _nextLine = Timer(wait < Duration.zero ? Duration.zero : wait, _syncLine);
  }

  Future<void> _loadTrack(String? path) async {
    _path = path;
    lyrics = null;
    offsetMs = 0;
    line.value = -1;
    loading = path != null;
    notifyListeners();
    if (path == null) return;
    final (found, offset) = await (_load(path), store.lyricsOffset(path)).wait;
    // A pessoa pode ter trocado de faixa enquanto o disco lia
    if (_disposed || _path != path) return;
    lyrics = found;
    offsetMs = offset;
    loading = false;
    _syncLine();
    notifyListeners();
  }

  /// Pula para a linha, onde ela está com o ajuste.
  Future<void> seekToLine(int index) {
    final time = lyrics!.lines[index].time - Duration(milliseconds: offsetMs);
    return playback.engine.seek(time < Duration.zero ? Duration.zero : time);
  }

  void setOffset(int value) {
    final path = _path;
    if (path == null || value == offsetMs) return;
    offsetMs = value;
    _syncLine();
    notifyListeners();
    unawaited(store.setLyricsOffset(path, value));
  }

  @override
  void dispose() {
    _disposed = true;
    _nextLine?.cancel();
    playback.engine.state.removeListener(_onEngine);
    line.dispose();
    super.dispose();
  }
}
