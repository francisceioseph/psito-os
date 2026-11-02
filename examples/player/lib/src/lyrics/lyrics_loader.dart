// examples/player/lib/src/lyrics/lyrics_loader.dart
//
// Acha a letra de uma faixa, na ordem do LETRAS.md: o `.lrc`, o `.srt` e as tags.
// Lê do disco, que pode ser lento e externo: quem está na tela usa o loadLyrics.
import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../library/scanner.dart';
import 'lyrics.dart';
import 'lyrics_parser.dart';

/// Quem passa disto não é a letra de uma música.
const lyricsMaxBytes = 2 * 1024 * 1024;

typedef LyricsLoader = Future<Lyrics?> Function(String audioPath);

Lyrics? _readFile(String path) {
  final file = File(path);
  if (file.lengthSync() > lyricsMaxBytes) {
    debugPrint('🎵 letra grande demais: $path');
    return null;
  }
  final text = decodeLyrics(file.readAsBytesSync());
  if (text == null) {
    debugPrint('🎵 letra sem texto legível: $path');
    return null;
  }
  final lyrics = p.extension(path).toLowerCase() == '.srt'
      ? parseSrt(text)
      : parseLrc(text);
  return lyrics.lines.isEmpty ? null : lyrics.from(p.basename(path));
}

Lyrics? _readTags(String audioPath) {
  // O leitor deixa o zero do fim da descrição, no ID3
  final text = readMetadata(
    File(audioPath),
    getImage: false,
  ).lyrics?.replaceAll('\u0000', '');
  if (text == null || text.trim().isEmpty) return null;
  final lyrics = parseLrc(text);
  return lyrics.lines.isEmpty ? null : lyrics;
}

/// A letra de [audioPath], ou null sem nenhuma. O primeiro lugar que tem arquivo
/// é o que vale, mesmo que ele não dê para ler.
Lyrics? readLyrics(String audioPath) {
  try {
    final dir = p.dirname(audioPath);
    final names = [
      for (final entry in Directory(dir).listSync(followLinks: false))
        p.basename(entry.path),
    ];
    final file = findLyricsFile(audioPath, names);
    return file == null ? _readTags(audioPath) : _readFile(p.join(dir, file));
  } catch (e) {
    debugPrint('🎵 sem letra para $audioPath: $e');
    return null;
  }
}

Future<Lyrics?> loadLyrics(String audioPath) =>
    Isolate.run(() => readLyrics(audioPath));
