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
  final String? genre;
  final bool favorite;

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
    this.genre,
    this.favorite = false,
  });

  Track withFavorite(bool favorite) => Track(
    id: id,
    path: path,
    title: title,
    artist: artist,
    albumId: albumId,
    album: album,
    trackNumber: trackNumber,
    discNumber: discNumber,
    year: year,
    duration: duration,
    format: format,
    lyricsPath: lyricsPath,
    embeddedLyrics: embeddedLyrics,
    coverPath: coverPath,
    playCount: playCount,
    genre: genre,
    favorite: favorite,
  );

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
  final Duration duration;

  const LibraryTotals({
    this.albums = 0,
    this.tracks = 0,
    this.size = 0,
    this.duration = Duration.zero,
  });
}

@immutable
class Artist {
  final int id;

  /// Vazio quando a tag não diz.
  final String name;
  final int albums;
  final int tracks;

  const Artist({
    required this.id,
    required this.name,
    this.albums = 0,
    this.tracks = 0,
  });
}

@immutable
class Genre {
  /// Vazio são as faixas sem gênero.
  final String name;
  final int tracks;

  const Genre({required this.name, this.tracks = 0});
}

/// Uma pasta com música dentro, em qualquer nível de uma pasta da biblioteca.
@immutable
class MusicDir {
  final String path;
  final int albums;
  final int tracks;

  const MusicDir({required this.path, this.albums = 0, this.tracks = 0});
}

enum PlaylistKind { manual, favorites, mostPlayed, recentlyAdded }

@immutable
class Playlist {
  /// 0 nas automáticas.
  final int id;
  final PlaylistKind kind;

  /// Vazio nas automáticas, que têm o nome na tela.
  final String name;
  final int trackCount;
  final Duration duration;
  final int updatedAt;

  /// As capas do mosaico, até quatro.
  final List<({String? path, String seed})> covers;

  const Playlist({
    required this.id,
    this.kind = PlaylistKind.manual,
    this.name = '',
    this.trackCount = 0,
    this.duration = Duration.zero,
    this.updatedAt = 0,
    this.covers = const [],
  });

  bool get automatic => kind != PlaylistKind.manual;
}

enum AlbumSort { recent, title, artist, year }

enum TrackSort { title, album, artist, duration, format, added }

/// Que faixas e em que ordem.
@immutable
class TrackQuery {
  final TrackSort sort;
  final bool ascending;
  final bool favorites;
  final bool withLyrics;
  final String? format;
  final int? artistId;

  /// O vazio são as sem gênero.
  final String? genre;
  final String? dir;

  const TrackQuery({
    this.sort = TrackSort.title,
    this.ascending = true,
    this.favorites = false,
    this.withLyrics = false,
    this.format,
    this.artistId,
    this.genre,
    this.dir,
  });

  TrackQuery sortedBy(TrackSort sort, bool ascending) => TrackQuery(
    sort: sort,
    ascending: ascending,
    favorites: favorites,
    withLyrics: withLyrics,
    format: format,
    artistId: artistId,
    genre: genre,
    dir: dir,
  );

  /// Os filtros da tela de músicas, um de cada vez.
  TrackQuery filtered({
    bool favorites = false,
    bool withLyrics = false,
    String? format,
  }) => TrackQuery(
    sort: sort,
    ascending: ascending,
    favorites: favorites,
    withLyrics: withLyrics,
    format: format,
    artistId: artistId,
    genre: genre,
    dir: dir,
  );
}

/// O que só o painel Capa precisa saber de uma faixa.
@immutable
class TrackDetails {
  final int? sampleRate;

  /// Em bits por segundo.
  final int? bitrate;

  /// `embedded` ou o nome do arquivo, como `cover.jpg`. Null sem capa.
  final String? coverSource;

  const TrackDetails({this.sampleRate, this.bitrate, this.coverSource});
}

@immutable
class SearchResults {
  final String query;
  final List<Track> tracks;
  final List<Album> albums;
  final List<Artist> artists;
  final List<MusicDir> dirs;

  const SearchResults({
    this.query = '',
    this.tracks = const [],
    this.albums = const [],
    this.artists = const [],
    this.dirs = const [],
  });

  bool get isEmpty =>
      tracks.isEmpty && albums.isEmpty && artists.isEmpty && dirs.isEmpty;

  /// O nome que tem as mesmas palavras da busca é o que a pessoa quis dizer. Sem
  /// nenhum assim, vale o artista, depois o álbum, depois a música.
  Object? get best {
    final words = _foldedWords(query);
    // O mesmo nome, ou o começo dele enquanto a pessoa digita
    bool exact(String name) {
      final own = _foldedWords(name);
      if (own.length != words.length) return false;
      for (var i = 0; i < own.length; i++) {
        if (!own[i].startsWith(words[i])) return false;
      }
      return true;
    }

    return artists.where((a) => exact(a.name)).firstOrNull ??
        albums.where((a) => exact(a.title)).firstOrNull ??
        tracks.where((t) => exact(t.title)).firstOrNull ??
        artists.firstOrNull ??
        albums.firstOrNull ??
        tracks.firstOrNull;
  }
}

List<String> _foldedWords(String text) => [
  for (final word in text.trim().split(RegExp(r'\s+')))
    String.fromCharCodes(word.codeUnits.map(_folded)),
];

/// Compara sem acento e sem diferenciar maiúsculas, sem criar texto: roda em
/// cada comparação de uma ordenação grande.
int compareFolded(String? a, String? b) {
  final x = a ?? '';
  final y = b ?? '';
  final shared = x.length < y.length ? x.length : y.length;
  for (var i = 0; i < shared; i++) {
    final diff = _folded(x.codeUnitAt(i)) - _folded(y.codeUnitAt(i));
    if (diff != 0) return diff;
  }
  return x.length - y.length;
}

// De U+00C0 a U+00FF, a letra sem acento. O resto continua como está.
const _latin1Folded =
    'aaaaaaaceeeeiiiidnooooo\u00d7ouuuuy\u00fe\u00df'
    'aaaaaaaceeeeiiiidnooooo\u00f7ouuuuy\u00fey';

int _folded(int unit) {
  if (unit >= 0x41 && unit <= 0x5a) return unit + 0x20;
  if (unit >= 0xc0 && unit <= 0xff) {
    return _latin1Folded.codeUnitAt(unit - 0xc0);
  }
  return unit;
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
