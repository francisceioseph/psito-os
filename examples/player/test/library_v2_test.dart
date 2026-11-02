import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:psito_player/src/library/folder_watcher.dart';
import 'package:psito_player/src/library/library_controller.dart';
import 'package:psito_player/src/library/library_db.dart';
import 'package:psito_player/src/library/library_search.dart';
import 'package:psito_player/src/library/library_store.dart';
import 'package:psito_player/src/library/m3u.dart';
import 'package:psito_player/src/library/models.dart';
import 'package:psito_player/src/library/scanner.dart';
import 'package:psito_player/src/library/tags.dart';
import 'package:sqlite3/sqlite3.dart';

import 'helpers.dart';

int _add(
  LibraryDb db, {
  String folder = '/m',
  String dir = 'Coral',
  String file = 'a.flac',
  String title = 'Correnteza',
  String artist = 'Coral Vento',
  String? albumArtist,
  String album = 'Mare Alta',
  String? genre,
  int durationMs = 1000,
  int added = 1,
}) {
  final id = db.addFolder(folder);
  db.upsertTrack(
    ScannedTrack(
      path: '$folder/$dir/$file',
      title: title,
      artist: artist,
      albumArtist: albumArtist ?? artist,
      album: album,
      genre: genre,
      durationMs: durationMs,
    ),
    id,
    added,
  );
  return id;
}

void main() {
  late LibraryDb db;

  setUp(() => db = LibraryDb.memory());
  tearDown(() => db.close());

  group('migração', () {
    test('um banco da fase 1 ganha o que falta, sem perder nada', () {
      final raw = sqlite3.openInMemory();
      raw.execute(schemaV1);
      raw.execute('''
        INSERT INTO folders (id, path) VALUES (1, '/home/p/Musica');
        INSERT INTO artists (id, name) VALUES (1, 'Coral Vento');
        INSERT INTO albums (id, title, artist_id) VALUES (1, 'Mare Alta', 1);
        INSERT INTO tracks (id, path, folder_id, album_id, artist_id, title,
          play_count, added_at)
        VALUES (7, '/home/p/Musica/Coral/a.FLAC', 1, 1, 1, 'Correnteza', 3, 9);
      ''');
      raw.userVersion = 1;
      final migrated = LibraryDb.wrap(raw);
      final track = migrated.tracks().single;
      expect(track.id, 7);
      expect(track.playCount, 3);
      expect(track.format, 'FLAC');
      expect(track.favorite, isFalse);
      expect(migrated.search('corr').tracks.single.id, 7);
      expect(
        migrated.search('musica').dirs.single.path,
        '/home/p/Musica/Coral',
      );
      // O caminho antes da pasta da biblioteca não conta
      expect(migrated.search('home').dirs, isEmpty);
      expect(raw.userVersion, 3);
      migrated.close();
    });
  });

  group('busca', () {
    test('cada palavra é o começo de uma palavra, sem ligar para acento', () {
      _add(db, title: 'Maré Cheia', album: 'Água');
      expect(db.search('mare').tracks, hasLength(1));
      expect(db.search('MARÉ').tracks, hasLength(1));
      expect(db.search('ma').tracks, hasLength(1));
      expect(db.search('are').tracks, isEmpty);
      expect(db.search('agua cheia').tracks, hasLength(1));
      expect(db.search('agua vazia').tracks, isEmpty);
    });

    test('o que a pessoa digita não vira sintaxe', () {
      _add(db);
      for (final odd in ['"', 'a"b', '(', 'NOT', 'title:x', '*', '--', "'"]) {
        expect(() => db.search(odd), returnsNormally, reason: odd);
      }
      expect(ftsTerms('  a  "b" '), '"a"* """b"""*');
      expect(db.search('   ').isEmpty, isTrue);
    });

    test('tirar a pasta tira da busca, e reler não duplica', () {
      final folder = _add(db);
      _add(db);
      expect(db.search('corr').tracks, hasLength(1));
      db.removeFolder(folder);
      expect(db.search('corr').isEmpty, isTrue);
    });

    test('uma tag que mudou muda a busca', () {
      _add(db);
      _add(db, title: 'Outra Coisa');
      expect(db.search('corr').tracks, isEmpty);
      expect(db.search('outra').tracks, hasLength(1));
    });

    test('tocar e favoritar não mexem no índice', () {
      _add(db);
      final id = db.tracks().single.id;
      db.recordPlay(id, 5);
      db.setFavorite(id, true);
      expect(db.search('corr').tracks.single.favorite, isTrue);
    });

    test('agrupa em músicas, álbuns, artistas e pastas', () {
      _add(db, title: 'Luz', artist: 'Sol', album: 'Dia', dir: 'Vento');
      _add(db, file: 'b.flac', title: 'Vento Norte');
      _add(db, file: 'c.flac', title: 'Sal', artist: 'Vento Sul', album: 'Mar');
      final found = db.search('vento');
      expect(
        found.tracks.map((t) => t.title),
        containsAll(['Vento Norte', 'Sal']),
      );
      expect(found.artists.map((a) => a.name), ['Coral Vento', 'Vento Sul']);
      expect(found.albums.map((a) => a.title), ['Mar', 'Mare Alta']);
      expect(found.dirs.single.path, '/m/Vento');
    });

    test('o melhor resultado prefere quem tem o mesmo nome', () {
      _add(db, title: 'Coral', artist: 'Outro', album: 'X');
      _add(db, file: 'b.flac');
      final byTitle = db.search('coral').best;
      expect(byTitle, isA<Track>().having((t) => t.title, 'title', 'Coral'));
      final byArtist = db.search('coral vento').best;
      expect(
        byArtist,
        isA<Artist>().having((a) => a.name, 'name', 'Coral Vento'),
      );
      expect(db.search('vent').best, isA<Artist>());
    });
  });

  group('consultas', () {
    test('a ordem por nome conta os acentos como as letras', () {
      for (final (i, title) in const [
        'Zeta',
        'Água',
        'beta',
        'Ômega',
      ].indexed) {
        _add(db, file: '$i.flac', title: title);
      }
      expect(db.tracks().map((t) => t.title), [
        'Água',
        'beta',
        'Ômega',
        'Zeta',
      ]);
    });

    test('filtra e ordena as faixas', () {
      _add(db, file: 'a.flac', title: 'A', durationMs: 3000);
      _add(db, file: 'b.mp3', title: 'B', durationMs: 1000);
      db.setFavorite(db.tracks().first.id, true);
      expect(db.tracks(const TrackQuery(format: 'MP3')).single.title, 'B');
      expect(db.tracks(const TrackQuery(favorites: true)).single.title, 'A');
      expect(
        db
            .tracks(const TrackQuery(sort: TrackSort.duration))
            .map((t) => t.title),
        ['B', 'A'],
      );
      expect(
        db
            .tracks(const TrackQuery(sort: TrackSort.title, ascending: false))
            .map((t) => t.title),
        ['B', 'A'],
      );
      expect(db.formats(), ['FLAC', 'MP3']);
    });

    test('artistas: quem toca, e os álbuns em que toca', () {
      _add(db, artist: 'Rua 9', albumArtist: 'Varios', album: 'Junto');
      _add(db, file: 'b.flac', artist: 'Rua 9', album: 'Sozinho');
      _add(db, file: 'c.flac', artist: '', album: 'Sem');
      final artists = db.artists();
      expect(artists.map((a) => a.name), ['Rua 9', '']);
      expect(artists.first.albums, 2);
      expect(artists.first.tracks, 2);
      expect(
        db.artistAlbums(artists.first.id).map((a) => a.title),
        containsAll(['Junto', 'Sozinho']),
      );
      expect(db.tracks(TrackQuery(artistId: artists.first.id)), hasLength(2));
    });

    test('gêneros: os que têm mais primeiro, e os sem gênero por último', () {
      _add(db, file: 'a.flac', genre: 'Rock');
      _add(db, file: 'b.flac', genre: ' Rock ');
      _add(db, file: 'c.flac', genre: 'Jazz');
      _add(db, file: 'd.flac');
      _add(db, file: 'e.flac');
      _add(db, file: 'f.flac');
      final genres = db.genres();
      expect(genres.map((g) => g.name), ['Rock', 'Jazz', '']);
      expect(genres.first.tracks, 2);
      expect(db.tracks(const TrackQuery(genre: 'Rock')), hasLength(2));
      expect(db.tracks(const TrackQuery(genre: '')), hasLength(3));
    });

    test('as pastas são onde as faixas estão', () {
      _add(db, file: 'a.flac', dir: 'X');
      _add(db, file: 'b.flac', dir: 'X');
      _add(db, file: 'c.flac', dir: 'Y/Z');
      expect(db.dirs().map((d) => (d.path, d.tracks)), [
        ('/m/X', 2),
        ('/m/Y/Z', 1),
      ]);
      expect(db.tracks(const TrackQuery(dir: '/m/Y/Z')), hasLength(1));
    });

    test('o total da biblioteca soma a duração', () {
      _add(db, file: 'a.flac', durationMs: 2000);
      _add(db, file: 'b.flac', durationMs: 3000);
      expect(db.totals().duration, const Duration(seconds: 5));
    });
  });

  group('playlists', () {
    test('criar, renomear, adicionar, mover, tirar e apagar', () {
      _add(db, file: 'a.flac', title: 'A');
      _add(db, file: 'b.flac', title: 'B');
      _add(db, file: 'c.flac', title: 'C');
      final id = db.createPlaylist('Estrada', 1, [
        '/m/Coral/a.flac',
        '/m/Coral/b.flac',
      ]);
      db.addToPlaylist(id, ['/m/Coral/c.flac'], 2);
      expect(db.playlistTracks(id).map((t) => t.title), ['A', 'B', 'C']);
      db.movePlaylistTrack(id, 0, 2, 3);
      expect(db.playlistTracks(id).map((t) => t.title), ['B', 'C', 'A']);
      db.movePlaylistTrack(id, 2, 0, 4);
      expect(db.playlistTracks(id).map((t) => t.title), ['A', 'B', 'C']);
      db.removeFromPlaylist(id, 1, 5);
      expect(db.playlistTracks(id).map((t) => t.title), ['A', 'C']);
      db.renamePlaylist(id, 'Viagem', 6);
      final playlist = db.playlists().single;
      expect(playlist.name, 'Viagem');
      expect(playlist.trackCount, 2);
      expect(playlist.duration, const Duration(seconds: 2));
      expect(playlist.updatedAt, 6);
      expect(playlist.covers, hasLength(1));
      db.deletePlaylist(id);
      expect(db.playlists(), isEmpty);
    });

    test('a mesma faixa pode entrar duas vezes', () {
      _add(db);
      final id = db.createPlaylist('X', 1, ['/m/Coral/a.flac']);
      db.addToPlaylist(id, ['/m/Coral/a.flac'], 1);
      expect(db.playlistTracks(id), hasLength(2));
      db.removeFromPlaylist(id, 0, 2);
      expect(db.playlistTracks(id), hasLength(1));
    });

    test('tirar a pasta deixa a faixa como um arquivo solto', () {
      final folder = _add(db);
      final id = db.createPlaylist('X', 1, ['/m/Coral/a.flac', '/fora/b.mp3']);
      db.removeFolder(folder);
      final tracks = db.playlistTracks(id);
      expect(tracks.map((t) => t.id), [0, 0]);
      expect(tracks.first.title, 'a');
      expect(tracks.last.format, 'MP3');
    });

    test('as automáticas contam o que têm', () {
      _add(db, file: 'a.flac', title: 'A', added: 5);
      _add(db, file: 'b.flac', title: 'B', added: 9);
      final a = db.tracks().first.id;
      db.setFavorite(a, true);
      db.recordPlay(a, 1);
      final autos = db.autoPlaylists();
      expect(autos.map((p) => p.kind), [
        PlaylistKind.favorites,
        PlaylistKind.mostPlayed,
        PlaylistKind.recentlyAdded,
      ]);
      expect(autos.map((p) => p.trackCount), [1, 1, 2]);
      expect(db.recentlyAdded(1).single.title, 'B');
    });
  });

  group('M3U', () {
    Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

    test('lê caminhos relativos, absolutos, file e ignora os comentários', () {
      final entries = parseM3u(
        bytes(
          '#EXTM3U\n#EXTINF:3,Quem - Oi\na/b.flac\r\n/abs/c.mp3\n'
          'file:///abs/d%20e.ogg\n\n../f.wav\ndir\\g.opus\n',
        ),
        '/lista',
      );
      expect(entries.paths, [
        '/lista/a/b.flac',
        '/abs/c.mp3',
        '/abs/d e.ogg',
        '/f.wav',
        '/lista/dir/g.opus',
      ]);
      expect(entries.remote, 0);
    });

    test('um endereço da rede fica de fora', () {
      final entries = parseM3u(
        bytes('http://x.y/a.mp3\nhttps://x.y/b.mp3\nsmb://x/c.mp3\n/d.mp3\n'),
        '/',
      );
      expect(entries.paths, ['/d.mp3']);
      expect(entries.remote, 3);
    });

    test('aceita BOM e Latin-1', () {
      expect(
        parseM3u(
          Uint8List.fromList([0xef, 0xbb, 0xbf, ...utf8.encode('/mú.mp3')]),
          '/',
        ).paths,
        ['/mú.mp3'],
      );
      expect(
        parseM3u(Uint8List.fromList([0x2f, 0x6d, 0xfa, 0x2e, 0x6d]), '/').paths,
        ['/mú.m'],
      );
    });

    test('o que escreve volta igual', () {
      const tracks = [
        Track(
          path: '/m/a b.flac',
          title: 'Oi',
          artist: 'Quem',
          format: 'FLAC',
          duration: Duration(seconds: 61),
        ),
        Track(path: '/m/c.mp3', title: 'Sem', format: 'MP3'),
      ];
      final text = writeM3u(tracks);
      expect(text, startsWith('#EXTM3U\n#EXTINF:61,Quem - Oi\n/m/a b.flac\n'));
      expect(text, contains('#EXTINF:0,Sem\n'));
      expect(parseM3u(bytes(text), '/').paths, ['/m/a b.flac', '/m/c.mp3']);
    });
  });

  group('pastas', () {
    late Directory dir;
    final control = ScanControl();

    setUp(() => dir = Directory.systemTemp.createTempSync('psito-v2'));
    tearDown(() => dir.deleteSync(recursive: true));

    File touch(String name) => File(p.join(dir.path, name))
      ..createSync(recursive: true)
      ..writeAsStringSync('x');

    Future<void> scan(MusicFolder folder, [List<ScanProgress>? seen]) =>
        scanFolders(
          db: db,
          folders: [folder],
          coverDir: p.join(dir.path, '.covers'),
          control: control,
          onProgress: (progress) => seen?.add(progress),
          readTags: (_) => const FileTags(),
        );

    test('a conferência conta o novo, o alterado e o removido', () async {
      touch('a.flac');
      final b = touch('b.flac');
      final c = touch('c.flac');
      final id = db.addFolder(dir.path);
      final folder = MusicFolder(id: id, path: dir.path);
      await scan(folder);
      expect((await checkFolder(db, folder)).changes, 0);
      touch('novo.mp3');
      b.setLastModifiedSync(DateTime(2000));
      c.deleteSync();
      touch('capa.txt');
      final check = await checkFolder(db, folder);
      expect(check.changes, 3);
      expect(check.unavailable, isFalse);
    });

    test(
      'a pasta que não está lá, ou que ficou vazia, não apaga a biblioteca',
      () async {
        final a = touch('a.flac');
        final id = db.addFolder(dir.path);
        final folder = MusicFolder(id: id, path: dir.path);
        await scan(folder);
        a.deleteSync();
        expect((await checkFolder(db, folder)).unavailable, isTrue);
        final seen = <ScanProgress>[];
        await scan(folder, seen);
        expect(seen.last.missingFolders, 1);
        expect(db.tracks(), hasLength(1));
        const gone = MusicFolder(id: 99, path: '/nao/existe');
        expect((await checkFolder(db, gone)).unavailable, isTrue);
      },
    );

    test('o que está oculto fica de fora, como a lixeira do disco', () async {
      touch('a.flac');
      touch('.oculto.flac');
      touch('.Trash-1000/files/b.flac');
      final folder = MusicFolder(id: db.addFolder(dir.path), path: dir.path);
      final found = await checkFolder(db, folder);
      expect(found.changes, 1);
    });

    test('observar vê o que muda nas subpastas, até nas novas', () async {
      touch('artista/album/a.flac');
      final watcher = DirectoryWatcher();
      addTearDown(watcher.dispose);
      final changed = <String>[];
      watcher.watch({dir.path}, changed.add);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      touch('artista/album/b.flac');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(changed, contains(dir.path));
      changed.clear();
      touch('artista/album/novo/c.flac');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(changed, contains(dir.path));
      changed.clear();
      touch('artista/album/novo/d.flac');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(changed, contains(dir.path));
      changed.clear();
      File('${dir.path}/artista/album/novo/d.flac').deleteSync();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(changed, contains(dir.path));
    });

    test('a pasta observada que some sai da lista, e pode voltar', () async {
      final watcher = DirectoryWatcher();
      addTearDown(watcher.dispose);
      final changed = <String>[];
      final disk = Directory('${dir.path}/disco')..createSync();
      watcher.watch({disk.path}, changed.add);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      disk.deleteSync();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      disk.createSync();
      watcher.watch({disk.path}, changed.add);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      File('${disk.path}/a.flac').writeAsStringSync('x');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(changed, contains(disk.path));
    });

    test('observar avisa do áudio e ignora o resto', () async {
      final watcher = DirectoryWatcher();
      addTearDown(watcher.dispose);
      final changed = <String>[];
      watcher.watch({dir.path}, changed.add);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      touch('nota.txt');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(changed, isEmpty);
      touch('sub/a.flac');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(changed, contains(dir.path));
      changed.clear();
      watcher.watch(const {}, changed.add);
      touch('b.flac');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(changed, isEmpty);
    });
  });

  group('controller', () {
    late FakeScanner scanner;
    late LibraryController library;

    setUp(() {
      scanner = FakeScanner();
      library = LibraryController(store: DirectStore(db), scanner: scanner);
    });
    tearDown(() => library.dispose());

    test(
      'observando, a mudança lê em silêncio, e a pessoa vê só se pedir',
      () async {
        final folder = _add(db);
        await library.reload();
        scanner.checks = {folder: const FolderCheck(changes: 2)};
        await library.checkFolders();
        expect(library.pending[folder], 2);
        expect(scanner.sessions, hasLength(1));
        expect(library.scan, isNotNull);
        expect(library.visibleScan, isNull);
        library.startScan();
        expect(library.visibleScan, isNotNull);
        expect(scanner.sessions, hasLength(1));
      },
    );

    test('sem observar, só mostra', () async {
      final folder = _add(db);
      await library.reload();
      await library.setWatching(false);
      scanner.checks = {folder: const FolderCheck(changes: 2)};
      await library.checkFolders();
      expect(library.pending[folder], 2);
      expect(scanner.sessions, isEmpty);
    });

    test('depois de cancelar, não recomeça sozinha', () async {
      final folder = _add(db);
      await library.reload();
      library.startScan();
      library.cancelScan();
      scanner.checks = {folder: const FolderCheck(changes: 2)};
      await scanner.sessions.single.controller.close();
      await Future<void>.delayed(Duration.zero);
      await library.checkFolders();
      expect(scanner.sessions, hasLength(1));
      expect(library.pending[folder], 2);
    });

    test('a pasta esvaziada conta como ausente', () async {
      final dir = Directory.systemTemp.createTempSync('psito-v2');
      addTearDown(() => dir.deleteSync(recursive: true));
      final folder = _add(db, folder: dir.path);
      await library.reload();
      expect(library.missing, isEmpty);
      scanner.checks = {folder: const FolderCheck(unavailable: true)};
      await library.checkFolders();
      expect(library.missing, {dir.path});
      expect(library.isMissing('${dir.path}/Coral/a.flac'), isTrue);
      expect(library.isMissing('/outra/a.flac'), isFalse);
      scanner.checks = {folder: const FolderCheck()};
      await library.checkFolders();
      expect(library.missing, isEmpty);
    });

    test('o disco que sai e volta é visto, e lê o que mudou', () async {
      final dir = Directory.systemTemp.createTempSync('psito-v2');
      addTearDown(() => dir.deleteSync(recursive: true));
      final folder = _add(db, folder: dir.path);
      await library.reload();
      scanner.gone = {dir.path};
      await library.pollFolders();
      expect(library.missing, {dir.path});
      scanner.checks = {folder: const FolderCheck(unavailable: true)};
      await library.checkFolders();
      await library.pollFolders();
      expect(library.missing, {dir.path});
      scanner.gone = const {};
      scanner.checks = {folder: const FolderCheck(changes: 2)};
      await library.pollFolders();
      expect(library.missing, isEmpty);
      expect(scanner.sessions.single.folders.single.path, dir.path);
    });

    test('a pasta de volta, ainda vazia, continua ausente', () async {
      final dir = Directory.systemTemp.createTempSync('psito-v2');
      addTearDown(() => dir.deleteSync(recursive: true));
      final folder = _add(db, folder: dir.path);
      await library.reload();
      scanner.checks = {folder: const FolderCheck(unavailable: true)};
      await library.checkFolders();
      expect(library.missing, {dir.path});
      await library.pollFolders();
      expect(library.missing, {dir.path});
      expect(scanner.sessions, isEmpty);
    });

    test('as escolhas da Biblioteca voltam ao reabrir', () async {
      _add(db);
      await library.reload();
      library.setSection(LibrarySection.artists);
      library.setAlbumsAsList(true);
      await library.setAlbumSort(AlbumSort.year);
      await library.setWatching(false);
      await Future<void>.delayed(Duration.zero);
      final again = LibraryController(store: DirectStore(db), scanner: scanner);
      addTearDown(again.dispose);
      await again.reload();
      expect(again.section, LibrarySection.artists);
      expect(again.albumsAsList, isTrue);
      expect(again.albumSort, AlbumSort.year);
      expect(again.watching, isFalse);
    });

    test('importa um M3U, com o nome do arquivo', () async {
      _add(db);
      final dir = Directory.systemTemp.createTempSync('psito-v2');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File(p.join(dir.path, 'Estrada.m3u8'))
        ..writeAsStringSync('/m/Coral/a.flac\nhttp://x/y.mp3\nsolta.flac\n');
      final result = await library.importM3u(file.path);
      expect(result.tracks, 2);
      expect(result.remote, 1);
      expect(library.playlists.single.name, 'Estrada');
      final out = p.join(dir.path, 'saida.m3u8');
      await library.exportM3u(db.playlistTracks(result.id), out);
      expect(File(out).readAsStringSync(), contains('/m/Coral/a.flac'));
    });

    test('a busca fica só com o último pedido', () async {
      _add(db);
      final search = LibrarySearch(DirectStore(db));
      addTearDown(search.dispose);
      search.setQuery('corr');
      await Future<void>.delayed(LibrarySearch.debounce * 2);
      expect(search.results.tracks, hasLength(1));
      search.setQuery('');
      expect(search.results.isEmpty, isTrue);
      expect(search.query, '');
    });
  });
}
