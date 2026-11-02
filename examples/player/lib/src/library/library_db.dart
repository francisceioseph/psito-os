// examples/player/lib/src/library/library_db.dart
//
// O banco da biblioteca, em SQLite. É síncrono: quem usa o app fala com ele pelo
// LibraryStore, em outro isolate, e o scanner abre a própria conexão.
import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import 'models.dart';

const _schemaVersion = 2;

@visibleForTesting
const schemaV1 = '''
CREATE TABLE folders (
  id INTEGER PRIMARY KEY,
  path TEXT NOT NULL UNIQUE,
  scanned_at INTEGER
);
CREATE TABLE artists (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE
);
CREATE TABLE albums (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  artist_id INTEGER NOT NULL REFERENCES artists(id),
  year INTEGER,
  cover_path TEXT,
  cover_source TEXT,
  UNIQUE (title, artist_id)
);
CREATE TABLE tracks (
  id INTEGER PRIMARY KEY,
  path TEXT NOT NULL UNIQUE,
  folder_id INTEGER NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
  album_id INTEGER NOT NULL REFERENCES albums(id),
  artist_id INTEGER NOT NULL REFERENCES artists(id),
  title TEXT NOT NULL,
  track_number INTEGER,
  disc_number INTEGER,
  year INTEGER,
  genre TEXT,
  duration_ms INTEGER NOT NULL DEFAULT 0,
  sample_rate INTEGER,
  bitrate INTEGER,
  size INTEGER NOT NULL DEFAULT 0,
  mtime INTEGER NOT NULL DEFAULT 0,
  lyrics_path TEXT,
  embedded_lyrics INTEGER NOT NULL DEFAULT 0,
  play_count INTEGER NOT NULL DEFAULT 0,
  last_played_at INTEGER,
  added_at INTEGER NOT NULL
);
CREATE INDEX tracks_album ON tracks(album_id);
CREATE INDEX tracks_folder ON tracks(folder_id);
CREATE INDEX tracks_played ON tracks(play_count);
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
''';

/// As letras contam sem acento e sem diferenciar maiúsculas, o que o NOCASE do
/// SQLite não faz fora do ASCII.
const _collation = 'psito_folded';

const _ftsFill = '''
  INSERT INTO tracks_fts (rowid, title, artist, album, album_artist, dir)
  SELECT NEW.id, NEW.title, a.name, al.title, aa.name, NEW.rel_dir
  FROM artists a, albums al JOIN artists aa ON aa.id = al.artist_id
  WHERE a.id = NEW.artist_id AND al.id = NEW.album_id;
''';

/// Os favoritos, a pasta de cada faixa, o formato, as playlists e a busca. As
/// playlists guardam o caminho, para sobreviver a tirar a pasta da biblioteca e
/// para levar faixas de um M3U que não estão nela.
const _schemaV2Tables =
    '''
CREATE INDEX tracks_dir ON tracks(dir);
CREATE INDEX tracks_artist ON tracks(artist_id);
CREATE INDEX tracks_genre ON tracks(genre);
CREATE INDEX tracks_favorite ON tracks(favorite) WHERE favorite = 1;
CREATE TABLE playlists (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE TABLE playlist_tracks (
  playlist_id INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
  position INTEGER NOT NULL,
  path TEXT NOT NULL,
  PRIMARY KEY (playlist_id, position)
);
CREATE VIRTUAL TABLE tracks_fts USING fts5(
  title, artist, album, album_artist, dir,
  tokenize = "unicode61 remove_diacritics 2",
  prefix = '2 3'
);
INSERT INTO tracks_fts (rowid, title, artist, album, album_artist, dir)
  SELECT t.id, t.title, a.name, al.title, aa.name, t.rel_dir
  FROM tracks t
  JOIN artists a ON a.id = t.artist_id
  JOIN albums al ON al.id = t.album_id
  JOIN artists aa ON aa.id = al.artist_id;
CREATE TRIGGER tracks_fts_insert AFTER INSERT ON tracks BEGIN
  $_ftsFill
END;
CREATE TRIGGER tracks_fts_delete AFTER DELETE ON tracks BEGIN
  DELETE FROM tracks_fts WHERE rowid = OLD.id;
END;
CREATE TRIGGER tracks_fts_update
AFTER UPDATE OF title, artist_id, album_id, rel_dir ON tracks BEGIN
  DELETE FROM tracks_fts WHERE rowid = OLD.id;
  $_ftsFill
END;
''';

const _trackColumns = '''
  t.id, t.path, t.title, a.name AS artist, t.album_id, al.title AS album,
  t.track_number, t.disc_number, t.year, t.duration_ms, t.lyrics_path,
  t.embedded_lyrics, al.cover_path, t.play_count, t.favorite, t.format, t.genre
''';

const _trackJoins = '''
  FROM tracks t
  JOIN artists a ON a.id = t.artist_id
  JOIN albums al ON al.id = t.album_id
''';

const _albumFrom = '''
  SELECT al.id, al.title, a.name AS artist, al.year, al.cover_path,
    COUNT(t.id) AS track_count, SUM(t.duration_ms) AS duration_ms,
    SUM(t.size) AS size, MIN(t.path) AS first_path, MAX(t.added_at) AS added_at,
    GROUP_CONCAT(DISTINCT t.format) AS formats
  FROM albums al
  JOIN artists a ON a.id = al.artist_id
  JOIN tracks t ON t.album_id = al.id
''';

const _albumSelect = '$_albumFrom GROUP BY al.id';

/// Do que a tela ordena para o SQL.
String _albumOrder(AlbumSort sort) => switch (sort) {
  AlbumSort.recent => 'added_at DESC, al.id DESC',
  AlbumSort.title => 'al.title COLLATE $_collation',
  AlbumSort.artist => 'a.name COLLATE $_collation, al.year, al.title',
  AlbumSort.year =>
    'al.year IS NULL, al.year DESC, al.title COLLATE $_collation',
};

String _trackOrder(TrackSort sort, bool ascending) {
  final direction = ascending ? 'ASC' : 'DESC';
  const byTitle = 't.title COLLATE $_collation';
  return switch (sort) {
    TrackSort.title => '$byTitle $direction',
    TrackSort.album =>
      'al.title COLLATE $_collation $direction, '
          'COALESCE(t.disc_number, 1), t.track_number IS NULL, t.track_number',
    TrackSort.artist => 'a.name COLLATE $_collation $direction, $byTitle',
    TrackSort.duration => 't.duration_ms $direction, $byTitle',
    TrackSort.format => 't.format $direction, $byTitle',
    TrackSort.added => 't.added_at $direction, t.id $direction',
  };
}

Track _track(Row r) {
  final path = r['path'] as String;
  return Track(
    id: r['id'] as int,
    path: path,
    title: r['title'] as String,
    artist: r['artist'] as String,
    albumId: r['album_id'] as int,
    album: r['album'] as String,
    trackNumber: r['track_number'] as int?,
    discNumber: r['disc_number'] as int?,
    year: r['year'] as int?,
    duration: Duration(milliseconds: r['duration_ms'] as int),
    format: r['format'] as String,
    genre: r['genre'] as String?,
    favorite: r['favorite'] == 1,
    lyricsPath: r['lyrics_path'] as String?,
    embeddedLyrics: r['embedded_lyrics'] == 1,
    coverPath: r['cover_path'] as String?,
    playCount: r['play_count'] as int,
  );
}

Album _album(Row r) => Album(
  id: r['id'] as int,
  title: r['title'] as String,
  artist: r['artist'] as String,
  year: r['year'] as int?,
  coverPath: r['cover_path'] as String?,
  trackCount: r['track_count'] as int,
  duration: Duration(milliseconds: r['duration_ms'] as int),
  size: r['size'] as int,
  formats:
      ((r['formats'] as String?)?.split(',') ?? const <String>[])
          .where((format) => format.isNotEmpty)
          .toList()
        ..sort(),
  folder: p.dirname(r['first_path'] as String),
);

/// O que vai para o MATCH: cada palavra é o começo de uma palavra, entre aspas
/// para o que a pessoa digita não virar sintaxe da busca.
@visibleForTesting
String ftsTerms(String query) => query
    .trim()
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .map((word) => '"${word.replaceAll('"', '""')}"*')
    .join(' ');

class LibraryDb {
  final Database _db;

  LibraryDb._(this._db) {
    _db.execute('PRAGMA foreign_keys = ON');
    _db.execute('PRAGMA busy_timeout = 5000');
    _db.createCollation(name: _collation, function: compareFolded);
    _migrate();
  }

  void _migrate() {
    if (_db.userVersion >= _schemaVersion) return;
    _db.execute('BEGIN IMMEDIATE');
    // Com o banco já travado: outra conexão pode ter passado na frente
    final from = _db.userVersion;
    if (from < 1) _db.execute(schemaV1);
    if (from < 2) _toV2();
    _db.userVersion = _schemaVersion;
    _db.execute('COMMIT');
  }

  void _toV2() {
    _db.execute('''
      ALTER TABLE tracks ADD COLUMN favorite INTEGER NOT NULL DEFAULT 0;
      ALTER TABLE tracks ADD COLUMN dir TEXT NOT NULL DEFAULT '';
      ALTER TABLE tracks ADD COLUMN rel_dir TEXT NOT NULL DEFAULT '';
      ALTER TABLE tracks ADD COLUMN format TEXT NOT NULL DEFAULT '';
    ''');
    final update = _db.prepare(
      'UPDATE tracks SET dir = ?, rel_dir = ?, format = ? WHERE id = ?',
    );
    for (final r in _db.select('''
      SELECT t.id, t.path, f.path AS folder
      FROM tracks t JOIN folders f ON f.id = t.folder_id
    ''')) {
      final path = r['path'] as String;
      update.execute([
        p.dirname(path),
        _relativeDir(path, r['folder'] as String),
        Track.formatOf(path),
        r['id'],
      ]);
    }
    update.dispose();
    _db.execute(_schemaV2Tables);
  }

  /// A pasta da faixa como a busca vê: a partir da pasta da biblioteca, com o nome
  /// dela. O resto do caminho (`/home/...`) acharia tudo.
  static String _relativeDir(String path, String folder) =>
      p.relative(p.dirname(path), from: p.dirname(folder));

  /// A biblioteca do sistema se chama assim no Debian, sem o pacote -dev. Vale
  /// por isolate.
  static void _useSystemLibrary() => open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so.0'),
  );

  factory LibraryDb.open(String path) {
    _useSystemLibrary();
    final db = sqlite3.open(path);
    // O scanner escreve enquanto o app lê
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA synchronous = NORMAL');
    return LibraryDb._(db);
  }

  /// Um banco já aberto, para testar a migração.
  @visibleForTesting
  factory LibraryDb.wrap(Database db) => LibraryDb._(db);

  factory LibraryDb.memory() {
    _useSystemLibrary();
    return LibraryDb._(sqlite3.openInMemory());
  }

  void close() => _db.dispose();

  void begin() => _db.execute('BEGIN IMMEDIATE');
  void commit() => _db.execute('COMMIT');

  // As pastas

  /// A pasta nova, ou a que já existia nesse caminho.
  int addFolder(String path) {
    _db.execute('INSERT OR IGNORE INTO folders (path) VALUES (?)', [path]);
    return _db.select('SELECT id FROM folders WHERE path = ?', [
          path,
        ]).first['id']
        as int;
  }

  /// Tira a pasta e as faixas dela, com o que ficar sem faixa nenhuma. Não
  /// mexe nos arquivos.
  void removeFolder(int id) {
    _db.execute('DELETE FROM folders WHERE id = ?', [id]);
    removeOrphans();
  }

  void markScanned(int id, int at) =>
      _db.execute('UPDATE folders SET scanned_at = ? WHERE id = ?', [at, id]);

  List<MusicFolder> folders() => [
    for (final r in _db.select('''
      SELECT f.id, f.path, f.scanned_at, COUNT(t.id) AS tracks,
        COUNT(DISTINCT t.album_id) AS albums, COALESCE(SUM(t.size), 0) AS size
      FROM folders f LEFT JOIN tracks t ON t.folder_id = f.id
      GROUP BY f.id ORDER BY f.path
    '''))
      MusicFolder(
        id: r['id'] as int,
        path: r['path'] as String,
        scannedAt: r['scanned_at'] as int?,
        albums: r['albums'] as int,
        tracks: r['tracks'] as int,
        size: r['size'] as int,
      ),
  ];

  // O que o scanner escreve

  /// O que já se conhece da pasta: caminho, e a data e o tamanho de quando foi
  /// lido, para não ler de novo o que não mudou.
  Map<String, (int, int)> knownFiles(int folderId) => {
    for (final r in _db.select(
      'SELECT path, mtime, size FROM tracks WHERE folder_id = ?',
      [folderId],
    ))
      r['path'] as String: (r['mtime'] as int, r['size'] as int),
  };

  int _artist(String name) {
    _db.execute('INSERT OR IGNORE INTO artists (name) VALUES (?)', [name]);
    return _db.select('SELECT id FROM artists WHERE name = ?', [
          name,
        ]).first['id']
        as int;
  }

  /// Grava a faixa e devolve o álbum dela. Lê de novo sem perder as reproduções
  /// nem a data em que entrou.
  int upsertTrack(ScannedTrack t, int folderId, int now) {
    final folder =
        _db.select('SELECT path FROM folders WHERE id = ?', [
              folderId,
            ]).first['path']
            as String;
    final albumArtist = _artist(t.albumArtist);
    _db.execute(
      'INSERT OR IGNORE INTO albums (title, artist_id, year) VALUES (?, ?, ?)',
      [t.album, albumArtist, t.year],
    );
    final albumId =
        _db.select('SELECT id FROM albums WHERE title = ? AND artist_id = ?', [
              t.album,
              albumArtist,
            ]).first['id']
            as int;
    if (t.year != null) {
      _db.execute('UPDATE albums SET year = ? WHERE id = ? AND year IS NULL', [
        t.year,
        albumId,
      ]);
    }
    _db.execute(
      '''
      INSERT INTO tracks (path, folder_id, album_id, artist_id, title,
        track_number, disc_number, year, genre, duration_ms, sample_rate,
        bitrate, size, mtime, lyrics_path, embedded_lyrics, added_at, dir,
        rel_dir, format)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT (path) DO UPDATE SET
        folder_id = excluded.folder_id, album_id = excluded.album_id,
        artist_id = excluded.artist_id, title = excluded.title,
        track_number = excluded.track_number,
        disc_number = excluded.disc_number, year = excluded.year,
        genre = excluded.genre, duration_ms = excluded.duration_ms,
        sample_rate = excluded.sample_rate, bitrate = excluded.bitrate,
        size = excluded.size, mtime = excluded.mtime,
        lyrics_path = excluded.lyrics_path,
        embedded_lyrics = excluded.embedded_lyrics, dir = excluded.dir,
        rel_dir = excluded.rel_dir, format = excluded.format
      ''',
      [
        t.path,
        folderId,
        albumId,
        _artist(t.artist),
        t.title,
        t.trackNumber,
        t.discNumber,
        t.year,
        t.genre,
        t.durationMs,
        t.sampleRate,
        t.bitrate,
        t.size,
        t.mtime,
        t.lyricsPath,
        t.embeddedLyrics ? 1 : 0,
        now,
        p.dirname(t.path),
        _relativeDir(t.path, folder),
        Track.formatOf(t.path),
      ],
    );
    return albumId;
  }

  bool albumHasCover(int id) =>
      _db.select('SELECT cover_path FROM albums WHERE id = ?', [
        id,
      ]).first['cover_path'] !=
      null;

  /// [source] diz de onde veio: `embedded` ou o nome do arquivo.
  void setAlbumCover(int id, String path, String source) => _db.execute(
    'UPDATE albums SET cover_path = ?, cover_source = ? WHERE id = ?',
    [path, source, id],
  );

  void removeTracks(Iterable<String> paths) {
    final statement = _db.prepare('DELETE FROM tracks WHERE path = ?');
    for (final path in paths) {
      statement.execute([path]);
    }
    statement.dispose();
  }

  /// Apaga os álbuns e artistas sem faixa, e devolve as capas que sobraram.
  List<String> removeOrphans() {
    final covers = [
      for (final r in _db.select('''
        SELECT cover_path FROM albums
        WHERE cover_path IS NOT NULL
          AND id NOT IN (SELECT album_id FROM tracks)
      '''))
        r['cover_path'] as String,
    ];
    _db.execute(
      'DELETE FROM albums WHERE id NOT IN (SELECT album_id FROM tracks)',
    );
    _db.execute('''
      DELETE FROM artists
      WHERE id NOT IN (SELECT artist_id FROM tracks)
        AND id NOT IN (SELECT artist_id FROM albums)
    ''');
    return covers;
  }

  // O que as telas leem

  LibraryTotals totals() {
    final r = _db.select('''
      SELECT COUNT(*) AS tracks, COUNT(DISTINCT album_id) AS albums,
        COALESCE(SUM(size), 0) AS size,
        COALESCE(SUM(duration_ms), 0) AS duration_ms
      FROM tracks
    ''').first;
    return LibraryTotals(
      albums: r['albums'] as int,
      tracks: r['tracks'] as int,
      size: r['size'] as int,
      duration: Duration(milliseconds: r['duration_ms'] as int),
    );
  }

  List<Album> albums([AlbumSort sort = AlbumSort.title]) => [
    for (final r in _db.select('$_albumSelect ORDER BY ${_albumOrder(sort)}'))
      _album(r),
  ];

  List<Album> recentAlbums(int limit) => [
    for (final r in _db.select(
      '$_albumSelect ORDER BY added_at DESC, al.id DESC LIMIT ?',
      [limit],
    ))
      _album(r),
  ];

  List<Track> albumTracks(int albumId) => [
    for (final r in _db.select(
      '''
      SELECT $_trackColumns $_trackJoins WHERE t.album_id = ?
      ORDER BY COALESCE(t.disc_number, 1), t.track_number IS NULL,
        t.track_number, t.path
      ''',
      [albumId],
    ))
      _track(r),
  ];

  /// Só as que já tocaram.
  List<Track> mostPlayed(int limit) => [
    for (final r in _db.select(
      '''
      SELECT $_trackColumns $_trackJoins WHERE t.play_count > 0
      ORDER BY t.play_count DESC, t.last_played_at DESC LIMIT ?
      ''',
      [limit],
    ))
      _track(r),
  ];

  List<Track> randomTracks(int limit) => [
    for (final r in _db.select(
      'SELECT $_trackColumns $_trackJoins ORDER BY RANDOM() LIMIT ?',
      [limit],
    ))
      _track(r),
  ];

  /// As faixas que [query] pede. O que ela não restringe, não entra no WHERE.
  List<Track> tracks([TrackQuery query = const TrackQuery()]) {
    final where = <String>[];
    final args = <Object?>[];
    void filter(String clause, Object? arg) {
      where.add(clause);
      args.add(arg);
    }

    if (query.favorites) where.add('t.favorite = 1');
    if (query.format != null) filter('t.format = ?', query.format);
    if (query.artistId != null) filter('t.artist_id = ?', query.artistId);
    if (query.dir != null) filter('t.dir = ?', query.dir);
    if (query.genre != null) {
      filter("TRIM(COALESCE(t.genre, '')) = ?", query.genre);
    }
    final clause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final order = _trackOrder(query.sort, query.ascending);
    return [
      for (final r in _db.select(
        'SELECT $_trackColumns $_trackJoins $clause ORDER BY $order',
        args,
      ))
        _track(r),
    ];
  }

  /// Os formatos que existem, para os filtros.
  List<String> formats() => [
    for (final r in _db.select(
      "SELECT DISTINCT format FROM tracks WHERE format <> '' ORDER BY format",
    ))
      r['format'] as String,
  ];

  /// Quem está nas tags das faixas. O artista do álbum, como "Vários", agrupa o
  /// álbum e não vira um artista aqui.
  List<Artist> artists() => [
    for (final r in _db.select('''
      SELECT a.id, a.name, COUNT(*) AS tracks, COUNT(DISTINCT t.album_id) AS albums
      FROM tracks t JOIN artists a ON a.id = t.artist_id
      GROUP BY a.id ORDER BY a.name = '', a.name COLLATE $_collation
    '''))
      _artistFrom(r),
  ];

  Artist _artistFrom(Row r) => Artist(
    id: r['id'] as int,
    name: r['name'] as String,
    albums: r['albums'] as int,
    tracks: r['tracks'] as int,
  );

  /// Os álbuns em que o artista toca, mesmo que o álbum seja de outro.
  List<Album> artistAlbums(int artistId) => [
    for (final r in _db.select(
      '''
      $_albumFrom
      WHERE al.id IN (SELECT album_id FROM tracks WHERE artist_id = ?)
      GROUP BY al.id ORDER BY al.year IS NULL, al.year DESC
      ''',
      [artistId],
    ))
      _album(r),
  ];

  /// O nome vazio são as faixas sem gênero.
  List<Genre> genres() => [
    for (final r in _db.select('''
      SELECT TRIM(COALESCE(genre, '')) AS name, COUNT(*) AS tracks
      FROM tracks GROUP BY 1 ORDER BY name = '', tracks DESC
    '''))
      Genre(name: r['name'] as String, tracks: r['tracks'] as int),
  ];

  /// As pastas que têm música de verdade, não só as que foram adicionadas.
  List<MusicDir> dirs() => [
    for (final r in _db.select('''
      SELECT dir, COUNT(*) AS tracks, COUNT(DISTINCT album_id) AS albums
      FROM tracks GROUP BY dir ORDER BY dir COLLATE $_collation
    '''))
      _dirFrom(r),
  ];

  MusicDir _dirFrom(Row r) => MusicDir(
    path: r['dir'] as String,
    albums: r['albums'] as int,
    tracks: r['tracks'] as int,
  );

  void setFavorite(int trackId, bool favorite) => _db.execute(
    'UPDATE tracks SET favorite = ? WHERE id = ?',
    [favorite ? 1 : 0, trackId],
  );

  // As playlists

  static const mostPlayedSize = 50;
  static const recentlyAddedSize = 30;

  int createPlaylist(String name, int now, [List<String> paths = const []]) {
    _db.execute(
      'INSERT INTO playlists (name, created_at, updated_at) VALUES (?, ?, ?)',
      [name, now, now],
    );
    final id = _db.lastInsertRowId;
    addToPlaylist(id, paths, now);
    return id;
  }

  void renamePlaylist(int id, String name, int now) => _db.execute(
    'UPDATE playlists SET name = ?, updated_at = ? WHERE id = ?',
    [name, now, id],
  );

  void deletePlaylist(int id) =>
      _db.execute('DELETE FROM playlists WHERE id = ?', [id]);

  void addToPlaylist(int id, List<String> paths, int now) {
    if (paths.isEmpty) return;
    final next =
        _db
                .select(
                  '''
          SELECT COALESCE(MAX(position) + 1, 0) AS next
          FROM playlist_tracks WHERE playlist_id = ?
          ''',
                  [id],
                )
                .first['next']
            as int;
    _rewrite(id, paths, now, from: next);
  }

  void _rewrite(int id, List<String> paths, int now, {int from = 0}) {
    _db.execute('BEGIN');
    if (from == 0) {
      _db.execute('DELETE FROM playlist_tracks WHERE playlist_id = ?', [id]);
    }
    final insert = _db.prepare(
      'INSERT INTO playlist_tracks (playlist_id, position, path) VALUES (?, ?, ?)',
    );
    for (var i = 0; i < paths.length; i++) {
      insert.execute([id, from + i, paths[i]]);
    }
    insert.dispose();
    _db.execute('UPDATE playlists SET updated_at = ? WHERE id = ?', [now, id]);
    _db.execute('COMMIT');
  }

  List<String> _playlistPaths(int id) => [
    for (final r in _db.select(
      'SELECT path FROM playlist_tracks WHERE playlist_id = ? ORDER BY position',
      [id],
    ))
      r['path'] as String,
  ];

  void removeFromPlaylist(int id, int index, int now) =>
      _rewrite(id, _playlistPaths(id)..removeAt(index), now);

  /// Depois de mover, a faixa fica em [to].
  void movePlaylistTrack(int id, int from, int to, int now) {
    final paths = _playlistPaths(id);
    paths.insert(to, paths.removeAt(from));
    _rewrite(id, paths, now);
  }

  List<Playlist> playlists() {
    final covers = _db.prepare('''
      SELECT al.cover_path, al.title, aa.name
      FROM playlist_tracks pt
      JOIN tracks t ON t.path = pt.path
      JOIN albums al ON al.id = t.album_id
      JOIN artists aa ON aa.id = al.artist_id
      WHERE pt.playlist_id = ?
      GROUP BY al.id ORDER BY MIN(pt.position) LIMIT 4
    ''');
    final found = [
      for (final r in _db.select('''
        SELECT p.id, p.name, p.updated_at, COUNT(pt.path) AS tracks,
          COALESCE(SUM(t.duration_ms), 0) AS duration_ms
        FROM playlists p
        LEFT JOIN playlist_tracks pt ON pt.playlist_id = p.id
        LEFT JOIN tracks t ON t.path = pt.path
        GROUP BY p.id
      '''))
        Playlist(
          id: r['id'] as int,
          name: r['name'] as String,
          trackCount: r['tracks'] as int,
          duration: Duration(milliseconds: r['duration_ms'] as int),
          updatedAt: r['updated_at'] as int,
          covers: [
            for (final c in covers.select([r['id']]))
              (
                path: c['cover_path'] as String?,
                seed: '${c['title']}|${c['name']}',
              ),
          ],
        ),
    ];
    covers.dispose();
    return found;
  }

  List<Track> playlistTracks(int id) => [
    for (final r in _db.select(
      '''
      SELECT pt.path AS entry, $_trackColumns
      FROM playlist_tracks pt
      LEFT JOIN tracks t ON t.path = pt.path
      LEFT JOIN artists a ON a.id = t.artist_id
      LEFT JOIN albums al ON al.id = t.album_id
      WHERE pt.playlist_id = ? ORDER BY pt.position
      ''',
      [id],
    ))
      r['id'] == null ? Track.fromPath(r['entry'] as String) : _track(r),
  ];

  List<Track> favorites() => tracks(const TrackQuery(favorites: true));

  List<Track> recentlyAdded(int limit) => [
    for (final r in _db.select(
      'SELECT $_trackColumns $_trackJoins '
      'ORDER BY t.added_at DESC, t.id DESC LIMIT ?',
      [limit],
    ))
      _track(r),
  ];

  /// As três automáticas, com o que têm agora.
  List<Playlist> autoPlaylists() {
    Playlist summary(PlaylistKind kind, List<Track> tracks) => Playlist(
      id: 0,
      kind: kind,
      trackCount: tracks.length,
      duration: tracks.fold(Duration.zero, (sum, t) => sum + t.duration),
    );
    return [
      summary(PlaylistKind.favorites, favorites()),
      summary(PlaylistKind.mostPlayed, mostPlayed(mostPlayedSize)),
      summary(PlaylistKind.recentlyAdded, recentlyAdded(recentlyAddedSize)),
    ];
  }

  // A busca

  /// O que casa com [query], em cada grupo. As músicas vêm por relevância, com o
  /// título pesando mais.
  SearchResults search(String query, {int limit = 200}) {
    final terms = ftsTerms(query);
    if (terms.isEmpty) return const SearchResults();
    final inSongs = '{title artist album album_artist} : ($terms)';
    final tracks = [
      for (final r in _db.select(
        '''
        SELECT $_trackColumns
        FROM tracks_fts f
        JOIN tracks t ON t.id = f.rowid
        JOIN artists a ON a.id = t.artist_id
        JOIN albums al ON al.id = t.album_id
        WHERE tracks_fts MATCH ?
        ORDER BY bm25(tracks_fts, 10.0, 5.0, 5.0, 2.0, 0.0), t.id LIMIT ?
        ''',
        [inSongs, limit],
      ))
        _track(r),
    ];
    final albums = [
      for (final r in _db.select(
        '''
        $_albumFrom
        WHERE al.id IN (
          SELECT t2.album_id FROM tracks_fts f
          JOIN tracks t2 ON t2.id = f.rowid
          WHERE tracks_fts MATCH ?
        )
        GROUP BY al.id ORDER BY al.title COLLATE $_collation LIMIT ?
        ''',
        ['{album album_artist} : ($terms)', limit],
      ))
        _album(r),
    ];
    final artists = [
      for (final r in _db.select(
        '''
        SELECT a.id, a.name, COUNT(*) AS tracks, COUNT(DISTINCT t.album_id) AS albums
        FROM tracks t JOIN artists a ON a.id = t.artist_id
        WHERE a.id IN (
          SELECT t2.artist_id FROM tracks_fts f
          JOIN tracks t2 ON t2.id = f.rowid
          WHERE tracks_fts MATCH ?
        )
        GROUP BY a.id ORDER BY tracks DESC, a.name COLLATE $_collation LIMIT ?
        ''',
        ['{artist} : ($terms)', limit],
      ))
        _artistFrom(r),
    ];
    final dirs = [
      for (final r in _db.select(
        '''
        SELECT dir, COUNT(*) AS tracks, COUNT(DISTINCT album_id) AS albums
        FROM tracks
        WHERE dir IN (
          SELECT t2.dir FROM tracks_fts f
          JOIN tracks t2 ON t2.id = f.rowid
          WHERE tracks_fts MATCH ?
        )
        GROUP BY dir ORDER BY dir COLLATE $_collation LIMIT ?
        ''',
        ['{dir} : ($terms)', limit],
      ))
        _dirFrom(r),
    ];
    return SearchResults(
      query: query,
      tracks: tracks,
      albums: albums,
      artists: artists,
      dirs: dirs,
    );
  }

  /// As faixas nestes caminhos que estão na biblioteca, por caminho.
  Map<String, Track> tracksAt(List<String> paths) {
    final statement = _db.prepare(
      'SELECT $_trackColumns $_trackJoins WHERE t.path = ?',
    );
    final found = <String, Track>{};
    for (final path in paths) {
      final rows = statement.select([path]);
      if (rows.isNotEmpty) found[path] = _track(rows.first);
    }
    statement.dispose();
    return found;
  }

  void recordPlay(int trackId, int at) => _db.execute(
    '''
    UPDATE tracks SET play_count = play_count + 1, last_played_at = ?
    WHERE id = ?
    ''',
    [at, trackId],
  );

  // As preferências

  String? setting(String key) {
    final rows = _db.select('SELECT value FROM settings WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void setSetting(String key, String value) => _db.execute(
    'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
    [key, value],
  );
}
