import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:psito_player/src/library/library_controller.dart';
import 'package:psito_player/src/library/library_db.dart';
import 'package:psito_player/src/library/library_store.dart';
import 'package:psito_player/src/library/models.dart';
import 'package:psito_player/src/library/scanner.dart';
import 'package:psito_player/src/library/tags.dart';

import 'helpers.dart';

Uint8List _png([int w = 800, int h = 600]) =>
    Uint8List.fromList(img.encodePng(img.Image(width: w, height: h)));

void main() {
  late Directory dir;
  late LibraryDb db;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('player_test');
    db = LibraryDb.memory();
  });

  tearDown(() {
    db.close();
    dir.deleteSync(recursive: true);
  });

  void write(String relative, [List<int> bytes = const [1, 2, 3]]) {
    File(p.join(dir.path, relative))
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
  }

  MusicFolder folder() => db.folders().firstWhere((f) => f.path == dir.path);

  FileTags byName(File file) {
    final name = p.basenameWithoutExtension(file.path);
    return FileTags(
      title: 'Faixa $name',
      artist: 'Artista',
      album: p.basename(p.dirname(file.path)),
      trackNumber: int.tryParse(name),
      durationMs: 60000,
    );
  }

  Future<List<ScanProgress>> scan({
    TagReader readTags = readFileTags,
    ScanControl? control,
  }) async {
    final progress = <ScanProgress>[];
    await scanFolders(
      db: db,
      folders: [folder()],
      coverDir: p.join(dir.path, '.covers'),
      control: control ?? ScanControl(),
      onProgress: progress.add,
      readTags: readTags,
      now: () => 5000,
    );
    return progress;
  }

  group('banco', () {
    test('agrupa em álbuns, com contagens', () {
      seedAlbum(db);
      seedAlbum(db, album: 'Outro', tracks: 2);
      expect(db.totals().albums, 2);
      expect(db.totals().tracks, 5);
      final albums = db.albums();
      expect(albums.map((a) => a.title), ['Maré Alta', 'Outro']);
      expect(albums.first.trackCount, 3);
      expect(albums.first.formats, ['FLAC']);
      expect(albums.first.duration, const Duration(minutes: 9));
      expect(albums.first.folder, '/m/Maré Alta');
    });

    test('as faixas vêm na ordem do disco e do número', () {
      final id = seedAlbum(db);
      expect(db.albumTracks(id).map((t) => t.trackNumber), [1, 2, 3]);
    });

    test('ler de novo não perde as reproduções nem a data', () {
      final id = seedAlbum(db, firstAdded: 1000);
      final track = db.albumTracks(id).first;
      db.recordPlay(track.id, 2000);
      seedAlbum(db, firstAdded: 9000);
      expect(db.albumTracks(id).first.playCount, 1);
      expect(db.recentAlbums(1).single.id, id);
    });

    test('mais tocadas só tem o que já tocou, da mais tocada para a menos', () {
      final id = seedAlbum(db);
      final tracks = db.albumTracks(id);
      expect(db.mostPlayed(5), isEmpty);
      db.recordPlay(tracks[1].id, 1);
      db.recordPlay(tracks[1].id, 2);
      db.recordPlay(tracks[0].id, 3);
      expect(db.mostPlayed(5).map((t) => t.id), [tracks[1].id, tracks[0].id]);
    });

    test('remover a pasta leva as faixas, os álbuns e os artistas', () {
      seedAlbum(db);
      db.removeFolder(db.folders().single.id);
      expect(db.totals().tracks, 0);
      expect(db.albums(), isEmpty);
      expect(db.folders(), isEmpty);
    });

    test('o banco num arquivo abre de novo com os dados', () {
      final path = p.join(dir.path, 'lib.db');
      final first = LibraryDb.open(path);
      seedAlbum(first);
      first.close();
      final second = LibraryDb.open(path);
      expect(second.totals().tracks, 3);
      second.close();
    });
  });

  group('o IsolateStore', () {
    test('roda as consultas em outro isolate, com os argumentos', () async {
      final path = p.join(dir.path, 'lib.db');
      final seed = LibraryDb.open(path);
      final id = seedAlbum(seed);
      seed.close();
      final store = await IsolateStore.open(path);
      addTearDown(store.close);
      expect((await store.totals()).tracks, 3);
      expect(await store.albumTracks(id), hasLength(3));
      await store.setSetting('a', 'b');
      expect(await store.setting('a'), 'b');
      expect(
        await store.tracksAt(['/m/Maré Alta/1.flac', '/nada']),
        hasLength(1),
      );
    });

    test('um erro na consulta volta para quem pediu', () async {
      final store = await IsolateStore.open(p.join(dir.path, 'lib.db'));
      addTearDown(store.close);
      await expectLater(
        store.run<void>((_) => throw StateError('falhou')),
        throwsStateError,
      );
    });

    test('lança se o banco não abre', () async {
      await expectLater(
        IsolateStore.open('/nao/existe/lib.db'),
        throwsStateError,
      );
    });
  });

  group('scanner', () {
    setUp(() {
      write('Álbum A/1.flac');
      write('Álbum A/2.MP3');
      write('Álbum A/notas.txt');
      write('Sub/Álbum B/1.ogg');
      db.addFolder(dir.path);
    });

    test('acha só os formatos aceitos, em álbuns', () async {
      final progress = await scan(readTags: byName);
      expect(db.totals().tracks, 3);
      expect(db.albums().map((a) => a.title), ['Álbum A', 'Álbum B']);
      expect(progress.last.finished, isTrue);
      expect(progress.last.total, 3);
      expect(progress.last.done, 3);
      expect(progress.last.albums, 2);
      expect(folder().scannedAt, 5000);
    });

    test(
      'tag ilegível: a faixa fica, com o nome do arquivo e da pasta',
      () async {
        await scan(readTags: (_) => throw const FormatException('ruim'));
        final album = db.albums().firstWhere((a) => a.title == 'Álbum A');
        final tracks = db.albumTracks(album.id);
        expect(tracks.map((t) => t.title), ['1', '2']);
        expect(tracks.first.artist, '');
      },
    );

    test('registra a letra ao lado, com o .lrc na frente', () async {
      write('Álbum A/1.SRT');
      write('Álbum A/1.lrc');
      write('Álbum A/2.srt');
      await scan(readTags: byName);
      final album = db.albums().firstWhere((a) => a.title == 'Álbum A');
      final tracks = db.albumTracks(album.id);
      expect(p.basename(tracks[0].lyricsPath!), '1.lrc');
      expect(p.basename(tracks[1].lyricsPath!), '2.srt');
      expect(tracks[0].hasLyrics, isTrue);
    });

    test('a capa embutida vence o cover.jpg, e vira miniatura', () async {
      write('Álbum A/cover.jpg', _png(100, 100));
      write('Sub/Álbum B/Folder.PNG', _png());
      final embedded = _png(1200, 800);
      await scan(
        readTags: (file) {
          final tags = byName(file);
          return FileTags(
            title: tags.title,
            artist: tags.artist,
            album: tags.album,
            cover: file.path.contains('Álbum A') ? embedded : null,
          );
        },
      );
      final albums = db.albums();
      final a = albums.firstWhere((x) => x.title == 'Álbum A');
      final b = albums.firstWhere((x) => x.title == 'Álbum B');
      final thumb = img.decodeJpg(File(a.coverPath!).readAsBytesSync())!;
      expect((thumb.width, thumb.height), (coverThumbSize, coverThumbSize));
      expect(File(b.coverPath!).existsSync(), isTrue);
    });

    test('uma capa ilegível não para a leitura', () async {
      write('Álbum A/cover.jpg', [0, 1, 2]);
      final progress = await scan(readTags: byName);
      expect(db.albums().first.coverPath, isNull);
      expect(progress.last.tracks, 3);
    });

    test('ler de novo só relê o que mudou, e tira o que sumiu', () async {
      await scan(readTags: byName);
      final read = <String>[];
      File(p.join(dir.path, 'Sub/Álbum B/1.ogg')).deleteSync();
      write('Álbum A/2.MP3', [1, 2, 3, 4]);
      await scan(
        readTags: (file) {
          read.add(p.basename(file.path));
          return byName(file);
        },
      );
      expect(read, ['2.MP3']);
      expect(db.totals().tracks, 2);
      expect(db.albums().map((a) => a.title), ['Álbum A']);
    });

    test('uma pasta que não está lá não apaga o que já foi lido', () async {
      await scan(readTags: byName);
      final renamed = '${dir.path}-off';
      final current = folder();
      dir.renameSync(renamed);
      addTearDown(() => Directory(renamed).renameSync(dir.path));
      final progress = <ScanProgress>[];
      await scanFolders(
        db: db,
        folders: [current],
        coverDir: p.join(renamed, '.covers'),
        control: ScanControl(),
        onProgress: progress.add,
        readTags: byName,
      );
      expect(db.totals().tracks, 3);
      expect(progress.last.missingFolders, 1);
    });

    test('cancelar para, guarda o que leu e não apaga nada', () async {
      await scan(readTags: byName);
      write('Álbum A/3.flac');
      File(p.join(dir.path, 'Sub/Álbum B/1.ogg')).deleteSync();
      final control = ScanControl();
      await scan(readTags: byName, control: control..cancel());
      expect(db.totals().tracks, 3);
    });

    test('pausar segura a leitura até continuar', () async {
      final control = ScanControl();
      final read = <String>[];
      final running = scan(
        control: control,
        readTags: (file) {
          read.add(file.path);
          control.pause();
          return byName(file);
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(read, hasLength(1));
      expect(control.paused, isTrue);
      control.resume();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(read, hasLength(2));
      control.cancel();
      await running;
    });
  });

  group('tags de verdade', () {
    for (final name in ['tone.flac', 'tone.mp3']) {
      test('$name: artista e artista do álbum separados', () {
        final tags = readFileTags(File('test/fixtures/$name'));
        expect(tags.title, 'Tom');
        expect(tags.artist, 'Artista');
        expect(tags.albumArtist, 'Banda');
        expect(tags.album, 'Álbum');
        expect(tags.year, 2024);
        expect(tags.trackNumber, 3);
      });
    }
  });

  test('fixLatin1 conserta o UTF-8 lido como Latin-1, e só ele', () {
    expect(fixLatin1('\u00c3\u0081lbum de Testes'), 'Álbum de Testes');
    expect(fixLatin1('Música'), 'Música');
    expect(fixLatin1('Canção'), 'Canção');
    expect(fixLatin1('日本'), '日本');
    expect(fixLatin1(null), isNull);
  });

  group('o que fica ao lado da música', () {
    test('a capa, sem diferenciar maiúsculas, com o cover na frente', () {
      expect(findCoverFile(['a.flac', 'FOLDER.jpg', 'Cover.PNG']), 'Cover.PNG');
      expect(findCoverFile(['folder.jpeg']), 'folder.jpeg');
      expect(findCoverFile(['a.flac']), isNull);
    });

    test('a letra, pelo nome da música', () {
      expect(
        findLyricsFile('/m/Canção.flac', ['canção.SRT', 'x.lrc']),
        'canção.SRT',
      );
      expect(findLyricsFile('/m/a.flac', ['b.lrc']), isNull);
    });
  });

  group('o controlador', () {
    late FakeScanner scanner;
    late LibraryController library;

    setUp(() {
      scanner = FakeScanner();
      library = LibraryController(store: DirectStore(db), scanner: scanner);
      addTearDown(library.dispose);
    });

    test('adicionar uma pasta lê só ela', () async {
      expect(await library.addFolder(dir.path), AddFolderResult.added);
      expect(scanner.sessions.single.folders.single.path, dir.path);
      expect(library.scan, isNotNull);
    });

    test('recusa o que o sandbox não vê e o que já está lá', () async {
      expect(
        await library.addFolder('/nao/existe'),
        AddFolderResult.notVisible,
      );
      await library.addFolder(dir.path);
      expect(
        await library.addFolder(dir.path),
        AddFolderResult.alreadyInLibrary,
      );
      final inside = Directory(p.join(dir.path, 'sub'))..createSync();
      expect(
        await library.addFolder(inside.path),
        AddFolderResult.alreadyInLibrary,
      );
    });

    test('uma leitura pedida durante outra espera a vez', () async {
      await library.addFolder(dir.path);
      final other = Directory(p.join(dir.path, '..', 'outra_${dir.hashCode}'))
        ..createSync();
      addTearDown(() => other.deleteSync());
      await library.addFolder(p.normalize(other.path));
      expect(scanner.sessions, hasLength(1));
      await scanner.sessions.first.controller.close();
      await Future<void>.delayed(Duration.zero);
      expect(scanner.sessions, hasLength(2));
    });

    test('pausar, continuar e cancelar chegam na leitura', () async {
      await library.addFolder(dir.path);
      library.pauseScan();
      expect(library.scan!.paused, isTrue);
      library.resumeScan();
      expect(library.scan!.paused, isFalse);
      library.cancelScan();
      expect(scanner.sessions.single.log, ['pause', 'resume', 'cancel']);
    });

    test('marca a pasta que não está lá', () async {
      db.addFolder('/nao/existe');
      await library.reload();
      expect(library.missing, {'/nao/existe'});
    });

    test('estima o que falta só depois de ler um pouco', () async {
      await library.addFolder(dir.path);
      expect(library.scanRemaining, isNull);
      scanner.sessions.single.controller.add(
        const ScanProgress(total: 100, done: 50),
      );
      await Future<void>.delayed(Duration.zero);
      expect(library.scanRemaining, isNotNull);
    });
  });

  test('userMusicDir acha a pasta do user-dirs, ou a Music', () {
    expect(userMusicDir({'HOME': dir.path}), isNull);
    Directory(p.join(dir.path, 'Music')).createSync();
    expect(userMusicDir({'HOME': dir.path}), p.join(dir.path, 'Music'));
    Directory(p.join(dir.path, 'Sons')).createSync();
    Directory(p.join(dir.path, '.config')).createSync();
    File(p.join(dir.path, '.config/user-dirs.dirs')).writeAsStringSync(
      'XDG_DESKTOP_DIR="\$HOME/Mesa"\nXDG_MUSIC_DIR="\$HOME/Sons"\n',
    );
    expect(userMusicDir({'HOME': dir.path}), p.join(dir.path, 'Sons'));
  });

  test('prettyPath mostra o til só dentro do home', () {
    expect(prettyPath('/home/a/Music', '/home/a'), '~/Music');
    expect(prettyPath('/media/d', '/home/a'), '/media/d');
    expect(prettyPath('/home/ab', '/home/a'), '/home/ab');
  });
}
