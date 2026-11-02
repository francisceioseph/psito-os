// examples/player/lib/src/library/models.dart
//
// O que a biblioteca guarda, como o resto do app vê. Tudo imutável e sem nada
// além de dados, para atravessar de um isolate para o outro.
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Uma faixa. O [id] 0 é um arquivo fora da biblioteca, aberto de fora.
@immutable
class Track {
  final int id;
  final String path;
  final String title;

  /// Vazio quando a tag não diz.
  final String artist;
  final int albumId;
  final String album;
  final int? trackNumber;
  final int? discNumber;
  final int? year;
  final Duration duration;

  /// A extensão em maiúsculas, como `FLAC`.
  final String format;

  /// O `.lrc` ou `.srt` ao lado da música.
  final String? lyricsPath;
  final bool embeddedLyrics;
  final String? coverPath;
  final int playCount;

  const Track({
    this.id = 0,
    required this.path,
    required this.title,
    this.artist = '',
    this.albumId = 0,
    this.album = '',
    this.trackNumber,
    this.discNumber,
    this.year,
    this.duration = Duration.zero,
    required this.format,
    this.lyricsPath,
    this.embeddedLyrics = false,
    this.coverPath,
    this.playCount = 0,
  });

  /// Um arquivo de que só se sabe o caminho.
  factory Track.fromPath(String path) => Track(
    path: path,
    title: p.basenameWithoutExtension(path),
    format: formatOf(path),
  );

  bool get hasLyrics => lyricsPath != null || embeddedLyrics;

  static String formatOf(String path) =>
      p.extension(path).replaceFirst('.', '').toUpperCase();
}

@immutable
class Album {
  final int id;
  final String title;

  /// Vazio quando a tag não diz.
  final String artist;
  final int? year;
  final String? coverPath;
  final int trackCount;
  final Duration duration;
  final int size;

  /// Os formatos das faixas, em maiúsculas.
  final List<String> formats;

  /// A pasta da primeira faixa.
  final String folder;

  const Album({
    required this.id,
    required this.title,
    this.artist = '',
    this.year,
    this.coverPath,
    this.trackCount = 0,
    this.duration = Duration.zero,
    this.size = 0,
    this.formats = const [],
    this.folder = '',
  });
}

/// Uma pasta da biblioteca.
@immutable
class MusicFolder {
  final int id;
  final String path;

  /// Em milissegundos desde a época, ou null antes da primeira leitura.
  final int? scannedAt;
  final int albums;
  final int tracks;
  final int size;

  const MusicFolder({
    required this.id,
    required this.path,
    this.scannedAt,
    this.albums = 0,
    this.tracks = 0,
    this.size = 0,
  });
}

@immutable
class LibraryTotals {
  final int albums;
  final int tracks;
  final int size;

  const LibraryTotals({this.albums = 0, this.tracks = 0, this.size = 0});
}

/// O que o scanner tira de um arquivo.
@immutable
class ScannedTrack {
  final String path;
  final String title;
  final String artist;

  /// Quem agrupa o álbum: o artista do álbum ou, sem ele, o da faixa.
  final String albumArtist;
  final String album;
  final int? trackNumber;
  final int? discNumber;
  final int? year;
  final String? genre;
  final int durationMs;
  final int? sampleRate;
  final int? bitrate;
  final int size;
  final int mtime;
  final String? lyricsPath;
  final bool embeddedLyrics;

  const ScannedTrack({
    required this.path,
    required this.title,
    this.artist = '',
    this.albumArtist = '',
    this.album = '',
    this.trackNumber,
    this.discNumber,
    this.year,
    this.genre,
    this.durationMs = 0,
    this.sampleRate,
    this.bitrate,
    this.size = 0,
    this.mtime = 0,
    this.lyricsPath,
    this.embeddedLyrics = false,
  });
}
