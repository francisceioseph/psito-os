// examples/player/lib/src/library/tags.dart
//
// As tags de um arquivo de áudio, no formato da biblioteca.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as p;

/// O que as tags dizem. Tudo pode faltar.
class FileTags {
  final String? title;
  final String? artist;
  final String? albumArtist;
  final String? album;
  final int? trackNumber;
  final int? discNumber;
  final int? year;
  final String? genre;
  final int durationMs;
  final int? sampleRate;
  final int? bitrate;
  final bool embeddedLyrics;
  final Uint8List? cover;

  const FileTags({
    this.title,
    this.artist,
    this.albumArtist,
    this.album,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.genre,
    this.durationMs = 0,
    this.sampleRate,
    this.bitrate,
    this.embeddedLyrics = false,
    this.cover,
  });
}

typedef TagReader = FileTags Function(File file);

String? _clean(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// O leitor decodifica as tags do WAV como Latin-1, e elas costumam ser UTF-8.
/// O que não for UTF-8 válido era Latin-1 mesmo, e fica.
String? fixLatin1(String? value) {
  if (value == null) return null;
  try {
    return utf8.decode(latin1.encode(value));
  } on FormatException {
    return value;
  } on ArgumentError {
    return value;
  }
}

/// Lança se o arquivo não dá para ler.
FileTags readFileTags(File file) {
  final tags = readMetadata(file, getImage: true);
  var artist = tags.artist;
  var albumArtist = tags.albumArtist;
  // No MP3, o `artist` do leitor prefere o TPE2, que é o artista do álbum
  if (p.extension(file.path).toLowerCase() == '.mp3') {
    final mp3 = readAllMetadata(file) as Mp3Metadata;
    artist = mp3.leadPerformer ?? mp3.bandOrOrchestra ?? mp3.originalArtist;
    albumArtist = mp3.bandOrOrchestra;
  }
  final wav = p.extension(file.path).toLowerCase() == '.wav';
  String? text(String? value) => _clean(wav ? fixLatin1(value) : value);
  final year = tags.year?.year;
  final front = tags.pictures.where(
    (picture) => picture.pictureType == PictureType.coverFront,
  );
  return FileTags(
    title: text(tags.title),
    artist: text(artist),
    albumArtist: text(albumArtist),
    album: text(tags.album),
    trackNumber: tags.trackNumber,
    discNumber: tags.discNumber,
    year: year == null || year <= 0 ? null : year,
    genre: text(tags.genres.firstOrNull),
    durationMs: tags.duration?.inMilliseconds ?? 0,
    sampleRate: tags.sampleRate,
    bitrate: tags.bitrate,
    embeddedLyrics: _clean(tags.lyrics) != null,
    cover: (front.firstOrNull ?? tags.pictures.firstOrNull)?.bytes,
  );
}
