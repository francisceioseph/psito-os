import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:psito_player/src/library/library_db.dart';
import 'package:psito_player/src/library/library_store.dart';
import 'package:psito_player/src/library/models.dart';
import 'package:psito_player/src/lyrics/lyrics.dart';
import 'package:psito_player/src/lyrics/lyrics_controller.dart';
import 'package:psito_player/src/lyrics/lyrics_loader.dart';
import 'package:psito_player/src/lyrics/lyrics_parser.dart';
import 'package:psito_player/src/player/playback_controller.dart';
import 'package:psito_player/src/ui/organisms/cover_panel.dart';
import 'package:psito_player/src/ui/organisms/lyrics_view.dart';
import 'package:psito_player/src/ui/organisms/now_playing_panel.dart';
import 'package:psito_player/src/ui/organisms/player_bar.dart';
import 'package:psito_player/src/ui/organisms/queue_panel.dart';

import 'helpers.dart';

Duration ms(int value) => Duration(milliseconds: value);

const _srt = '''
1
00:00:12,400 --> 00:00:15,900
Primeira linha

2
00:00:16,000 --> 00:00:19,500
<i>Segunda</i> linha
continua aqui

3
sem tempo nenhum
ainda sem tempo

4
01:02:03,004 --> 01:02:05,000
{\\an8}Última
''';

void main() {
  group('codificação', () {
    const text = 'Coração à deriva';

    test('UTF-8, com e sem BOM', () {
      final bytes = utf8.encode(text);
      expect(decodeLyrics(Uint8List.fromList(bytes)), text);
      expect(
        decodeLyrics(Uint8List.fromList([0xEF, 0xBB, 0xBF, ...bytes])),
        text,
      );
    });

    test('UTF-16 com BOM, nas duas ordens', () {
      final units = text.codeUnits;
      expect(
        decodeLyrics(
          Uint8List.fromList([
            0xFF,
            0xFE,
            for (final u in units) ...[u & 0xFF, u >> 8],
          ]),
        ),
        text,
      );
      expect(
        decodeLyrics(
          Uint8List.fromList([
            0xFE,
            0xFF,
            for (final u in units) ...[u >> 8, u & 0xFF],
          ]),
        ),
        text,
      );
    });

    test('UTF-16 sem BOM, pelos zeros', () {
      expect(
        decodeLyrics(
          Uint8List.fromList([
            for (final u in 'Mar alto'.codeUnits) ...[u, 0],
          ]),
        ),
        'Mar alto',
      );
    });

    test('Latin-1 e o Windows-1252', () {
      expect(decodeLyrics(Uint8List.fromList(latin1.encode(text))), text);
      // As aspas e o travessão do 1252 ficam onde o Latin-1 tem controles
      expect(
        decodeLyrics(Uint8List.fromList([0x93, 0x4D, 0x61, 0x72, 0x94, 0x96])),
        '“Mar”–',
      );
    });

    test('o que não é texto volta null', () {
      expect(
        decodeLyrics(
          Uint8List.fromList([0x89, 0x50, 0x00, 0x00, 0x0D, 0x00, 1]),
        ),
        isNull,
      );
      expect(decodeLyrics(Uint8List.fromList([0xC3, 0x01, 0x02])), isNull);
    });
  });

  group('SRT', () {
    test('lê os blocos, junta as linhas e tira a marcação', () {
      final lyrics = parseSrt(_srt);
      expect(lyrics.synced, isTrue);
      expect(lyrics.lines, const [
        LyricLine(Duration(seconds: 12, milliseconds: 400), 'Primeira linha'),
        LyricLine(Duration(seconds: 16), 'Segunda linha continua aqui'),
        LyricLine(
          Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 4),
          'Última',
        ),
      ]);
    });

    test('com CRLF e fora de ordem', () {
      final lyrics = parseSrt(
        '2\r\n00:00:05,000 --> 00:00:06,000\r\nB\r\n\r\n'
        '1\r\n00:00:01,000 --> 00:00:02,000\r\nA\r\n',
      );
      expect(lyrics.lines.map((l) => l.text), ['A', 'B']);
    });

    test('vazio e só lixo não têm linhas', () {
      expect(parseSrt('').lines, isEmpty);
      expect(parseSrt('nada\n\ncom cara\nde legenda').lines, isEmpty);
    });
  });

  group('LRC', () {
    test('lê os tempos, com duas e três casas', () {
      final lyrics = parseLrc(
        '[ti:Correnteza]\n[ar:Coral Vento]\n'
        '[00:12.40]Primeira\n[00:16.005]Segunda\n',
      );
      expect(lyrics.synced, isTrue);
      expect(lyrics.lines, [
        LyricLine(ms(12400), 'Primeira'),
        LyricLine(ms(16005), 'Segunda'),
      ]);
    });

    test('várias marcas repetem o texto, e ordena', () {
      final lyrics = parseLrc('[01:45.10][00:12.40]Refrão\n[00:30.00]Verso');
      expect(lyrics.lines, [
        LyricLine(ms(12400), 'Refrão'),
        LyricLine(ms(30000), 'Verso'),
        LyricLine(ms(105100), 'Refrão'),
      ]);
    });

    test('o offset positivo adianta, sem passar de zero', () {
      final lyrics = parseLrc('[offset:+200]\n[00:00.10]A\n[00:01.00]B');
      expect(lyrics.lines, [
        const LyricLine(Duration.zero, 'A'),
        LyricLine(ms(800), 'B'),
      ]);
      expect(
        parseLrc('[offset:-200]\n[00:01.00]B').lines.single.time,
        ms(1200),
      );
    });

    test('lixo no meio fica de fora, e a pausa fica', () {
      final lyrics = parseLrc(
        '[00:01.00]A\nlixo aqui\n[00:02.00]\n[00:99.00]C',
      );
      expect(lyrics.lines, [LyricLine(ms(1000), 'A'), LyricLine(ms(2000), '')]);
    });

    test('as marcas de palavra saem', () {
      expect(
        parseLrc('[00:01.00]<00:01.00>Mar <00:01.50>alto').lines.single.text,
        'Mar alto',
      );
    });

    test('sem tempo nenhum, é a letra comum', () {
      final lyrics = parseLrc('\nMar alto\n\nCéu claro\n\n');
      expect(lyrics.synced, isFalse);
      expect(lyrics.lines.map((l) => l.text), ['Mar alto', '', 'Céu claro']);
    });

    test('vazio não tem linhas', () {
      expect(parseLrc('').lines, isEmpty);
    });
  });

  group('a linha da vez', () {
    final lyrics = Lyrics(
      synced: true,
      lines: [
        LyricLine(ms(1000), 'A'),
        LyricLine(ms(2000), 'B'),
        LyricLine(ms(3000), 'C'),
      ],
    );

    test('nas bordas', () {
      expect(lyrics.lineAt(ms(999)), -1);
      expect(lyrics.lineAt(ms(1000)), 0);
      expect(lyrics.lineAt(ms(1999)), 0);
      expect(lyrics.lineAt(ms(2000)), 1);
      expect(lyrics.lineAt(ms(3000)), 2);
      expect(lyrics.lineAt(ms(999999)), 2);
    });

    test('sem linhas ou sem tempo, nenhuma', () {
      expect(const Lyrics(lines: [], synced: true).lineAt(ms(5)), -1);
      expect(
        const Lyrics(
          lines: [LyricLine(Duration.zero, 'A')],
          synced: false,
        ).lineAt(ms(5)),
        -1,
      );
    });
  });

  group('achar o arquivo', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('psito-letras'));
    tearDown(() => dir.deleteSync(recursive: true));

    String audio() {
      final path = p.join(dir.path, 'Correnteza.flac');
      File(path).writeAsBytesSync(const [0, 1, 2]);
      return path;
    }

    void write(String name, String text) =>
        File(p.join(dir.path, name)).writeAsStringSync(text);

    test('o .lrc vence o .srt, sem olhar maiúsculas', () {
      final path = audio();
      write('correnteza.SRT', '1\n00:00:01,000 --> 00:00:02,000\nDo srt\n');
      write('CORRENTEZA.lrc', '[00:01.00]Do lrc\n');
      final lyrics = readLyrics(path)!;
      expect(lyrics.fileName, 'CORRENTEZA.lrc');
      expect(lyrics.lines.single.text, 'Do lrc');
    });

    test('sem .lrc, o .srt, com o nome no selo', () {
      final path = audio();
      write('Correnteza.srt', '1\n00:00:01,000 --> 00:00:02,000\nDo srt\n');
      expect(readLyrics(path)!.fileName, 'Correnteza.srt');
    });

    test('arquivo vazio ou binário fica sem letra', () {
      final path = audio();
      write('Correnteza.lrc', '');
      expect(readLyrics(path), isNull);
      File(p.join(dir.path, 'Correnteza.lrc'))
          .writeAsBytesSync(const [0x89, 0, 0, 1, 0, 2, 0xFF]);
      expect(readLyrics(path), isNull);
    });

    test('áudio ilegível e pasta que sumiu não lançam', () {
      expect(readLyrics(audio()), isNull);
      expect(readLyrics('/nao/existe/musica.flac'), isNull);
    });
  });

  group('o controlador', () {
    late LibraryDb db;
    late FakeEngine engine;
    late PlaybackController playback;
    late LyricsController controller;
    var reads = 0;

    final synced = Lyrics(
      synced: true,
      fileName: 'a.lrc',
      lines: [LyricLine(ms(1000), 'A'), LyricLine(ms(2000), 'B')],
    );

    setUp(() {
      db = LibraryDb.memory();
      engine = FakeEngine();
      reads = 0;
      final store = DirectStore(db);
      playback = PlaybackController(engine: engine, store: store);
      controller = LyricsController(
        playback: playback,
        store: store,
        load: (path) async {
          reads++;
          return path.endsWith('b.flac') ? null : synced;
        },
      );
    });

    tearDown(() {
      controller.dispose();
      playback.dispose();
      db.close();
    });

    test('desligado não lê; ligado acompanha a faixa', () async {
      await engine.open(['/m/a.flac', '/m/b.flac']);
      await pumpEventQueue();
      expect(reads, 0);
      controller.active = true;
      await pumpEventQueue();
      expect(reads, 1);
      expect(controller.lyrics, synced);
      await engine.next();
      expect(controller.lyrics, isNull);
      await pumpEventQueue();
      expect(controller.lyrics, isNull);
      expect(controller.loading, isFalse);
    });

    test('a linha muda só ao passar do tempo, e avisa uma vez', () async {
      await engine.open(['/m/a.flac']);
      controller.active = true;
      await pumpEventQueue();
      var changes = 0;
      controller.line.addListener(() => changes++);
      void at(int value) =>
          engine.set(engine.state.value.copyWith(position: ms(value)));
      at(900);
      expect(controller.line.value, -1);
      at(1000);
      at(1100);
      at(1900);
      expect(controller.line.value, 0);
      expect(changes, 1);
      at(2000);
      expect(controller.line.value, 1);
      expect(changes, 2);
    });

    test('o ajuste adianta, fica no banco e o clique respeita', () async {
      await engine.open(['/m/a.flac']);
      controller.active = true;
      await pumpEventQueue();
      engine.set(engine.state.value.copyWith(position: ms(950)));
      expect(controller.line.value, -1);
      controller.setOffset(100);
      expect(controller.line.value, 0);
      await pumpEventQueue();
      expect(db.lyricsOffset('/m/a.flac'), 100);
      await controller.seekToLine(1);
      expect(engine.seeks.last, ms(1900));
      controller.setOffset(0);
      await pumpEventQueue();
      expect(db.lyricsOffset('/m/a.flac'), 0);
    });

    test('o ajuste salvo volta com a faixa', () async {
      db.setLyricsOffset('/m/a.flac', -300);
      await engine.open(['/m/a.flac']);
      controller.active = true;
      await pumpEventQueue();
      expect(controller.offsetMs, -300);
    });

    test('a linha troca na hora, sem esperar o aviso do motor', () async {
      await engine.open(['/m/a.flac']);
      controller.active = true;
      await pumpEventQueue();
      engine.set(engine.state.value.copyWith(position: ms(980)));
      expect(controller.line.value, -1);
      await Future<void>.delayed(ms(60));
      expect(controller.line.value, 0);
      // O aviso seguinte vem um pouco atrás, e a linha não volta
      engine.set(engine.state.value.copyWith(position: ms(990)));
      expect(controller.line.value, 0);
      // Voltar de verdade volta
      engine.set(engine.state.value.copyWith(position: ms(100)));
      expect(controller.line.value, -1);
    });

    test('parada, a linha não anda sozinha', () async {
      await engine.open(['/m/a.flac']);
      controller.active = true;
      await pumpEventQueue();
      await engine.playOrPause();
      engine.set(engine.state.value.copyWith(position: ms(980)));
      await Future<void>.delayed(ms(60));
      expect(controller.line.value, -1);
    });

    test('uma leitura atrasada não sobrescreve a faixa nova', () async {
      await engine.open(['/m/a.flac', '/m/b.flac']);
      controller.active = true;
      await engine.next();
      await pumpEventQueue();
      expect(controller.lyrics, isNull);
    });
  });

  group('a fila', () {
    test('limpar tira só o que vem depois', () async {
      final engine = FakeEngine();
      final db = LibraryDb.memory();
      final playback = PlaybackController(
        engine: engine,
        store: DirectStore(db),
      );
      addTearDown(() {
        playback.dispose();
        db.close();
      });
      await engine.open(['/a', '/b', '/c', '/d'], index: 1);
      await playback.clearUpcoming();
      expect(engine.state.value.queue, ['/a', '/b']);
      expect(engine.state.value.index, 1);
    });
  });

  group('o filtro e o banco', () {
    test('Com letra acha o arquivo ao lado e a embutida', () {
      final db = LibraryDb.memory();
      addTearDown(db.close);
      final folder = db.addFolder('/m');
      ScannedTrack track(String name, {String? file, bool tags = false}) =>
          ScannedTrack(
            path: '/m/$name.flac',
            title: name,
            artist: 'X',
            albumArtist: 'X',
            album: 'Y',
            size: 1,
            mtime: 1,
            lyricsPath: file,
            embeddedLyrics: tags,
          );
      db.upsertTrack(track('com arquivo', file: '/m/a.lrc'), folder, 1);
      db.upsertTrack(track('embutida', tags: true), folder, 1);
      db.upsertTrack(track('sem'), folder, 1);
      expect(
        db.tracks(const TrackQuery(withLyrics: true)).map((t) => t.title),
        unorderedEquals(['com arquivo', 'embutida']),
      );
      expect(db.tracks(), hasLength(3));
    });

    test('os detalhes vêm do banco, e fora dele não há', () {
      final db = LibraryDb.memory();
      addTearDown(db.close);
      seedAlbum(db);
      expect(db.trackDetails('/fora.flac'), isNull);
      expect(db.trackDetails('/m/Maré Alta/1.flac'), isNotNull);
    });
  });

  group('o painel', () {
    late LibraryDb db;
    late FakeEngine engine;

    final synced = Lyrics(
      synced: true,
      fileName: 'Correnteza.srt',
      lines: [
        LyricLine(ms(1000), 'Primeira'),
        LyricLine(ms(2000), 'Segunda'),
        LyricLine(ms(3000), 'Terceira'),
      ],
    );

    setUp(() {
      db = LibraryDb.memory();
      engine = FakeEngine();
    });

    Future<void> open(
      WidgetTester tester, {
      Lyrics? lyrics,
      double width = 1280,
      double height = 800,
    }) async {
      setWindow(tester, width, height);
      seedAlbum(db);
      await pumpPlayer(
        tester,
        engine: engine,
        db: db,
        initialPaths: const ['/m/Maré Alta/1.flac', '/m/Maré Alta/2.flac'],
        readLyrics: (_) async => lyrics,
      );
      await tester.pump();
    }

    testWidgets('abrir troca a barra pelos controles, e fechar traz de volta', (
      tester,
    ) async {
      await open(tester);
      expect(find.byType(PlayerBar), findsOneWidget);
      await tester.tap(find.byTooltip('Letra'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(PlayerBar), findsNothing);
      expect(find.byType(LyricsView), findsOneWidget);
      expect(find.byTooltip('Pausar'), findsOneWidget);
      expect(find.text('Esta faixa não tem letra'), findsOneWidget);
      await tester.tap(find.byTooltip('Fechar'));
      await tester.pump();
      expect(find.byType(NowPlayingPanel), findsNothing);
      expect(find.byType(PlayerBar), findsOneWidget);
    });

    testWidgets('as abas trocam, e a capa conta do arquivo', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('Capa'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(CoverPanel), findsOneWidget);
      expect(find.textContaining('Maré Alta · 2024'), findsOneWidget);
      expect(find.text('Gerada'), findsOneWidget);
      await tester.tap(find.text('Fila'));
      await tester.pump();
      expect(find.byType(QueuePanel), findsOneWidget);
      await tester.tap(find.text('Letra'));
      await tester.pump();
      expect(find.byType(LyricsView), findsOneWidget);
    });

    testWidgets('a letra mostra o selo, destaca e pula ao clicar', (
      tester,
    ) async {
      await open(tester, lyrics: synced);
      await tester.tap(find.byTooltip('Letra'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Correnteza.srt'), findsOneWidget);
      expect(find.text('sincronizada'), findsOneWidget);
      Color? colorOf(String text) =>
          DefaultTextStyle.of(tester.element(find.text(text))).style.color;
      engine.set(engine.state.value.copyWith(position: ms(2100)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final scheme = Theme.of(tester.element(find.byType(LyricsView)))
          .colorScheme;
      expect(colorOf('Segunda'), scheme.primary);
      expect(colorOf('Terceira'), isNot(scheme.primary));
      await tester.tap(find.text('Terceira'));
      await tester.pump();
      expect(engine.seeks.last, ms(3000));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('rolar com o mouse segura a rolagem automática', (
      tester,
    ) async {
      await open(
        tester,
        lyrics: Lyrics(
          synced: true,
          lines: [
            for (var i = 0; i < 80; i++)
              LyricLine(Duration(seconds: i), 'Linha $i'),
          ],
        ),
      );
      await tester.tap(find.byTooltip('Letra'));
      await tester.pump();
      await tester.pump();
      double offset() => tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(LyricsView),
              matching: find.byType(Scrollable),
            ),
          )
          .position
          .pixels;
      await tester.drag(find.text('Linha 2'), const Offset(0, -200));
      await tester.pump();
      final held = offset();
      engine.set(engine.state.value.copyWith(position: ms(30000)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(offset(), held);
      await tester.pump(LyricsView.holdAfterScroll);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(offset(), isNot(held));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('a letra sem tempo não destaca nem pula', (tester) async {
      await open(
        tester,
        lyrics: const Lyrics(
          synced: false,
          lines: [LyricLine(Duration.zero, 'Mar alto')],
        ),
      );
      await tester.tap(find.byTooltip('Letra'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Nas tags'), findsOneWidget);
      expect(find.text('sem tempo'), findsOneWidget);
      expect(find.byTooltip('Ajustar o tempo da letra'), findsNothing);
      await tester.tap(find.text('Mar alto'));
      await tester.pump();
      expect(engine.seeks, isEmpty);
    });

    testWidgets('o ajuste aparece e grava', (tester) async {
      await open(tester, lyrics: synced);
      await tester.tap(find.byTooltip('Letra'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byTooltip('Ajustar o tempo da letra'));
      await tester.pump();
      expect(find.text('+0,0 s'), findsOneWidget);
      await tester.tap(find.byTooltip('Adiantar a letra'));
      await tester.pump();
      expect(find.text('+0,1 s'), findsOneWidget);
      await tester.pump();
      expect(db.lyricsOffset('/m/Maré Alta/1.flac'), 100);
      await tester.tap(find.byTooltip('Zerar o ajuste'));
      await tester.pump();
      expect(find.text('+0,0 s'), findsOneWidget);
    });

    testWidgets('salvar a fila cria a playlist com o que está na lista', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byTooltip('Fila'));
      await tester.pump();
      await tester.tap(find.text('Salvar como playlist'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Estrada');
      await tester.tap(find.widgetWithText(FilledButton, 'Criar'));
      await tester.pumpAndSettle();
      final saved = db.playlists().single;
      expect(saved.name, 'Estrada');
      expect(db.playlistTracks(saved.id), hasLength(2));
      expect(find.text('Salva como “Estrada”'), findsOneWidget);
    });

    testWidgets('limpar deixa só a atual', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('Fila'));
      await tester.pump();
      await tester.tap(find.text('Limpar'));
      await tester.pump();
      await tester.pump();
      expect(engine.state.value.queue, ['/m/Maré Alta/1.flac']);
    });

    testWidgets('L e Q abrem e fecham a aba', (tester) async {
      await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pump();
      expect(find.byType(LyricsView), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await tester.pump();
      expect(find.byType(QueuePanel), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await tester.pump();
      expect(find.byType(NowPlayingPanel), findsNothing);
    });

    testWidgets('sem largura, navegar fecha o painel', (tester) async {
      await open(tester, width: 600, height: 700);
      await tester.tap(find.byTooltip('Fila'));
      await tester.pump();
      expect(find.byType(NowPlayingPanel), findsOneWidget);
      await tester.tap(find.text('Pastas'));
      await tester.pump();
      expect(find.byType(NowPlayingPanel), findsNothing);
    });

    for (final (w, h) in const [
      (240.0, 260.0),
      (240.0, 400.0),
      (400.0, 300.0),
      (600.0, 500.0),
      (899.0, 560.0),
      (900.0, 300.0),
      (1280.0, 800.0),
    ]) {
      testWidgets('cabe em ${w.toInt()}x${h.toInt()}, nas três abas', (
        tester,
      ) async {
        await open(tester, lyrics: synced, width: w, height: h);
        expect(tester.takeException(), isNull);
        for (final key in [LogicalKeyboardKey.keyL, LogicalKeyboardKey.keyQ]) {
          await tester.sendKeyEvent(key);
          await tester.pump();
          await tester.pump();
          expect(find.byType(NowPlayingPanel), findsOneWidget);
          expect(find.byType(PlayerBar), findsNothing);
          expect(tester.takeException(), isNull);
        }
        await tester.tap(
          find.byIcon(Icons.album_rounded).evaluate().isEmpty
              ? find.text('Capa')
              : find.byIcon(Icons.album_rounded),
        );
        await tester.pump();
        await tester.pump();
        expect(find.byType(CoverPanel), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 500));
      });
    }

    testWidgets('na janela baixa, só a barra, sem os botões do painel', (
      tester,
    ) async {
      await open(tester, width: 800, height: 200);
      expect(find.byType(PlayerBar), findsOneWidget);
      expect(find.byTooltip('Letra'), findsNothing);
      expect(find.byTooltip('Fila'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pump();
      expect(find.byType(PlayerBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
