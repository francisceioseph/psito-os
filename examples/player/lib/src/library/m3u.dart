// examples/player/lib/src/library/m3u.dart
//
// Ler e escrever M3U e M3U8. Só arquivos locais: um endereço da rede fica de fora,
// e quem diz quantos é o [M3uEntries].
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'models.dart';

@immutable
class M3uEntries {
  final List<String> paths;

  /// As linhas que apontam para fora do computador.
  final int remote;

  const M3uEntries(this.paths, {this.remote = 0});
}

/// UTF-8, com ou sem BOM. O `.m3u` antigo costuma ser Latin-1.
String _decode(Uint8List bytes) {
  final hasBom =
      bytes.length >= 3 &&
      bytes[0] == 0xef &&
      bytes[1] == 0xbb &&
      bytes[2] == 0xbf;
  final body = hasBom ? bytes.sublist(3) : bytes;
  try {
    return utf8.decode(body);
  } on FormatException {
    return latin1.decode(body);
  }
}

/// Os caminhos da lista, a partir da pasta [base] do arquivo.
M3uEntries parseM3u(Uint8List bytes, String base) {
  final paths = <String>[];
  var remote = 0;
  for (final raw in const LineSplitter().convert(_decode(bytes))) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final scheme = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]+):').firstMatch(line);
    if (scheme != null) {
      if (scheme[1]!.toLowerCase() != 'file') {
        remote++;
        continue;
      }
      try {
        paths.add(Uri.parse(line).toFilePath());
      } on FormatException {
        remote++;
      }
      continue;
    }
    final path = line.replaceAll(r'\', '/');
    paths.add(p.normalize(p.isAbsolute(path) ? path : p.join(base, path)));
  }
  return M3uEntries(paths, remote: remote);
}

/// Sempre em UTF-8 e com o caminho inteiro, que vale de qualquer pasta.
String writeM3u(List<Track> tracks) {
  final out = StringBuffer('#EXTM3U\n');
  for (final track in tracks) {
    final who = track.artist.isEmpty
        ? track.title
        : '${track.artist} - ${track.title}';
    out
      ..writeln('#EXTINF:${track.duration.inSeconds},$who')
      ..writeln(track.path);
  }
  return out.toString();
}
