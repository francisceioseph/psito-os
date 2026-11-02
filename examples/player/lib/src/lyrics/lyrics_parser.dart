// examples/player/lib/src/lyrics/lyrics_parser.dart
//
// Os bytes de um `.lrc` ou `.srt` viram linhas. O que não se entende fica de fora
// sem derrubar o resto: esses arquivos vêm de qualquer lugar.
import 'dart:convert';
import 'dart:typed_data';

import 'lyrics.dart';

/// De 0x80 a 0x9F, o que o Windows-1252 põe no lugar dos controles do Latin-1.
/// Zero é o que ele não define.
const _cp1252 = [
  0x20AC, 0, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
  0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0, 0x017D, 0, //
  0, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, //
  0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0, 0x017E, 0x0178, //
];

String _utf16(Uint8List bytes, int start, {required bool little}) {
  final data = ByteData.sublistView(bytes);
  final units = <int>[
    for (var i = start; i + 1 < bytes.length; i += 2)
      data.getUint16(i, little ? Endian.little : Endian.big),
  ];
  return String.fromCharCodes(units);
}

/// Sem BOM, o UTF-16 se entrega pelos zeros de um lado só. Devolve se é o
/// little-endian, ou null se os zeros não seguem esse padrão.
bool? _utf16WithoutBom(Uint8List bytes) {
  var even = 0;
  var odd = 0;
  for (var i = 0; i < bytes.length; i++) {
    if (bytes[i] != 0) continue;
    i.isEven ? even++ : odd++;
  }
  final half = bytes.length ~/ 2;
  if (odd > half * .3 && even == 0) return true;
  if (even > half * .3 && odd == 0) return false;
  return null;
}

String? _cp1252Decode(Uint8List bytes) {
  final units = <int>[];
  for (final byte in bytes) {
    final isText = byte >= 0x20 || const {9, 10, 12, 13}.contains(byte);
    if (!isText) return null;
    if (byte < 0x80 || byte > 0x9F) {
      units.add(byte);
      continue;
    }
    final unit = _cp1252[byte - 0x80];
    if (unit == 0) return null;
    units.add(unit);
  }
  return String.fromCharCodes(units);
}

/// O texto do arquivo: UTF-8, UTF-16 ou Windows-1252. Null se não é texto.
String? decodeLyrics(Uint8List bytes) {
  if (bytes.length >= 2) {
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _utf16(bytes, 2, little: true);
    }
    if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _utf16(bytes, 2, little: false);
    }
  }
  if (bytes.contains(0)) {
    final little = _utf16WithoutBom(bytes);
    return little == null ? null : _utf16(bytes, 0, little: little);
  }
  final hasBom =
      bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF;
  try {
    return utf8.decode(hasBom ? bytes.sublist(3) : bytes);
  } on FormatException {
    return _cp1252Decode(bytes);
  }
}

final _lrcTime = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
final _lrcOffset = RegExp(
  r'^\s*\[offset:\s*([+-]?\d+)\s*\]',
  caseSensitive: false,
);
final _lrcTag = RegExp(r'^\s*\[[a-zA-Z#]+:[^\]]*\]\s*$');

/// As marcas de palavra do LRC estendido, como `<00:12.40>`.
final _wordTime = RegExp(r'<\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?>');

/// `.4` são 400 ms, `.40` também, e `.405` são 405.
int _fraction(String? digits) =>
    digits == null ? 0 : int.parse(digits.padRight(3, '0').substring(0, 3));

List<String> _splitLines(String text) => const LineSplitter().convert(text);

/// Um LRC, ou o texto de uma tag, que pode ser só a letra sem tempo.
///
/// O `[offset]` positivo adianta a letra, como no ffmpeg e na maioria dos players.
Lyrics parseLrc(String text) {
  final timed = <LyricLine>[];
  final plain = <String>[];
  var offset = 0;
  for (final line in _splitLines(text.replaceFirst('﻿', ''))) {
    final offsetMark = _lrcOffset.firstMatch(line);
    if (offsetMark != null) {
      offset = int.parse(offsetMark[1]!.replaceFirst('+', ''));
      continue;
    }
    if (_lrcTag.hasMatch(line)) continue;
    var rest = line.trimLeft();
    final times = <Duration>[];
    while (true) {
      final mark = _lrcTime.matchAsPrefix(rest);
      if (mark == null) break;
      final seconds = int.parse(mark[2]!);
      if (seconds < 60) {
        times.add(
          Duration(
            minutes: int.parse(mark[1]!),
            seconds: seconds,
            milliseconds: _fraction(mark[3]),
          ),
        );
      }
      rest = rest.substring(mark.end).trimLeft();
    }
    if (times.isEmpty) {
      plain.add(line.trim());
      continue;
    }
    final words = rest.replaceAll(_wordTime, ' ').trim();
    final clean = words.replaceAll(RegExp(r'\s+'), ' ');
    for (final time in times) {
      timed.add(LyricLine(time, clean));
    }
  }
  if (timed.isEmpty) return _plain(plain);
  final shift = Duration(milliseconds: offset);
  return Lyrics(
    synced: true,
    lines: _sorted([
      for (final line in timed)
        LyricLine(
          line.time - shift < Duration.zero ? Duration.zero : line.time - shift,
          line.text,
        ),
    ]),
  );
}

/// Sem as pontas em branco.
Lyrics _plain(List<String> lines) {
  var first = 0;
  var last = lines.length;
  while (first < last && lines[first].isEmpty) {
    first++;
  }
  while (last > first && lines[last - 1].isEmpty) {
    last--;
  }
  return Lyrics(
    synced: false,
    lines: [
      for (final line in lines.sublist(first, last))
        LyricLine(Duration.zero, line),
    ],
  );
}

/// Os arquivos podem vir fora de ordem. O sort do Dart não é estável, e duas
/// linhas no mesmo tempo ficam na ordem em que vieram.
List<LyricLine> _sorted(List<LyricLine> lines) {
  final indexed = lines.indexed.toList()
    ..sort((a, b) {
      final byTime = a.$2.time.compareTo(b.$2.time);
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
  return [for (final (_, line) in indexed) line];
}

final _srtStart = RegExp(
  r'^\s*(\d+):(\d{1,2}):(\d{1,2})(?:[,.](\d{1,3}))?\s*-->',
);
final _srtBlockEnd = RegExp(r'\n[ \t]*\n');

/// `<i>` e `<font ...>`, e `{\an8}`, a posição na tela.
final _srtMarkup = RegExp(r'<[^>]*>|\{\\[^}]*\}');

Lyrics parseSrt(String text) {
  final normal = text.replaceFirst('﻿', '').replaceAll('\r\n', '\n');
  final lines = <LyricLine>[];
  for (final block in normal.split(_srtBlockEnd)) {
    final rows = block.split('\n');
    final at = rows.indexWhere(_srtStart.hasMatch);
    if (at < 0) continue;
    final mark = _srtStart.firstMatch(rows[at])!;
    final minutes = int.parse(mark[2]!);
    final seconds = int.parse(mark[3]!);
    if (minutes >= 60 || seconds >= 60) continue;
    final words = rows
        .skip(at + 1)
        .join(' ')
        .replaceAll(_srtMarkup, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (words.isEmpty) continue;
    lines.add(
      LyricLine(
        Duration(
          hours: int.parse(mark[1]!),
          minutes: minutes,
          seconds: seconds,
          milliseconds: _fraction(mark[4]),
        ),
        words,
      ),
    );
  }
  return Lyrics(synced: lines.isNotEmpty, lines: _sorted(lines));
}
