// examples/player/lib/src/library/library_db.dart
//
// O banco da biblioteca, em SQLite. É síncrono: quem usa o app fala com ele pelo
// LibraryStore, em outro isolate, e o scanner abre a própria conexão.
import 'dart:ffi';

import 'package:path/path.dart' as p;
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import 'models.dart';

const _schemaVersion = 1;

const _schema = '''
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

const _trackColumns = '''
  t.id, t.path, t.title, a.name AS artist, t.album_id, al.title AS album,
  t.track_number, t.disc_number, t.year, t.duration_ms, t.lyrics_path,
  t.embedded_lyrics, al.cover_path, t.play_count
''';

const _trackJoins = '''
  FROM tracks t
  JOIN artists a ON a.id = t.artist_id
  JOIN albums al ON al.id = t.album_id
''';

const _albumSelect = '''
  SELECT al.id, al.title, a.name AS artist, al.year, al.cover_path,
    COUNT(t.id) AS track_count, SUM(t.duration_ms) AS duration_ms,
    SUM(t.size) AS size, MIN(t.path) AS first_path, MAX(t.added_at) AS added_at,
    GROUP_CONCAT(DISTINCT LOWER(SUBSTR(t.path, -5))) AS tails
  FROM albums al
  JOIN artists a ON a.id = al.artist_id
  JOIN tracks t ON t.album_id = al.id
  GROUP BY al.id
''';

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
    format: Track.formatOf(path),
    lyricsPath: r['lyrics_path'] as String?,
    embeddedLyrics: r['embedded_lyrics'] == 1,
    coverPath: r['cover_path'] as String?,
    playCount: r['play_count'] as int,
  );
}

/// O SQLite não tem como cortar a extensão, que tem tamanho variável: a consulta
/// traz os fins dos caminhos, e ela sai daqui.
List<String> _formats(String? tails) {
  final found = <String>{};
  for (final tail in (tails ?? '').split(',')) {
    final dot = tail.lastIndexOf('.');
    if (dot >= 0) found.add(tail.substring(dot + 1).toUpperCase());
  }
  return found.toList()..sort();
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
  formats: _formats(r['tails'] as String?),
  folder: p.dirname(r['first_path'] as String),
);

class LibraryDb {
  final Database _db;

  LibraryDb._(this._db) {
    _db.execute('PRAGMA foreign_keys = ON');
    _db.execute('PRAGMA busy_timeout = 5000');
    if (_db.userVersion == 0) {
      _db.execute(_schema);
      _db.userVersion = _schemaVersion;
    }
  }

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
        bitrate, size, mtime, lyrics_path, embedded_lyrics, added_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT (path) DO UPDATE SET
        folder_id = excluded.folder_id, album_id = excluded.album_id,
        artist_id = excluded.artist_id, title = excluded.title,
        track_number = excluded.track_number,
        disc_number = excluded.disc_number, year = excluded.year,
        genre = excluded.genre, duration_ms = excluded.duration_ms,
        sample_rate = excluded.sample_rate, bitrate = excluded.bitrate,
        size = excluded.size, mtime = excluded.mtime,
        lyrics_path = excluded.lyrics_path,
        embedded_lyrics = excluded.embedded_lyrics
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
        COALESCE(SUM(size), 0) AS size
      FROM tracks
    ''').first;
    return LibraryTotals(
      albums: r['albums'] as int,
      tracks: r['tracks'] as int,
      size: r['size'] as int,
    );
  }

  List<Album> albums() => [
    for (final r in _db.select(
      '$_albumSelect ORDER BY al.title COLLATE NOCASE',
    ))
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
