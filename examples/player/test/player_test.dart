import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_player/src/library/library_db.dart';
import 'package:psito_player/src/library/scanner.dart';
import 'package:psito_player/src/ui/atoms/cover_art.dart';
import 'package:psito_player/src/ui/format.dart';
import 'package:psito_player/src/ui/molecules/album_card.dart';
import 'package:psito_player/src/ui/molecules/folder_row.dart';
import 'package:psito_player/src/ui/molecules/track_row.dart';
import 'package:psito_player/src/ui/organisms/player_bar.dart';
import 'package:psito_player/src/ui/organisms/queue_panel.dart';
import 'package:psito_player/src/ui/organisms/scan_card.dart';
import 'package:psito_player/src/ui/pages/empty_library_page.dart';

import 'helpers.dart';

void main() {
  late LibraryDb db;

  setUp(() {
    // Sem fechar: a árvore só desmonta depois dos tearDowns, e grava a sessão
    db = LibraryDb.memory();
  });

  group('janela', () {
    for (final (w, h) in const [
      (240.0, 160.0),
      (240.0, 400.0),
      (400.0, 300.0),
      (600.0, 500.0),
      (800.0, 600.0),
      (1280.0, 800.0),
    ]) {
      testWidgets('cabe em ${w.toInt()}x${h.toInt()}, em todas as telas', (
        tester,
      ) async {
        setWindow(tester, w, h);
        final album = seedAlbum(db);
        db.recordPlay(db.albumTracks(album).first.id, 1);
        final engine = FakeEngine();
        await pumpPlayer(
          tester,
          engine: engine,
          db: db,
          initialPaths: const ['/m/Maré Alta/1.flac'],
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        for (final tooltip in [
          'Biblioteca',
          'Pastas',
          'Playlists',
          'Ajustes',
        ]) {
          final button = find.byTooltip(tooltip);
          if (button.evaluate().isNotEmpty) {
            await tester.tap(button.first, warnIfMissed: false);
            await tester.pump();
            expect(tester.takeException(), isNull, reason: tooltip);
          }
        }
      });
    }

    testWidgets('em 240x160, só a barra do player', (tester) async {
      setWindow(tester, 240, 160);
      await pumpPlayer(tester, db: db);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(PlayerBar), findsOneWidget);
      expect(find.byType(EmptyLibraryPage), findsNothing);
    });

    testWidgets('sem altura para a barra lateral, ícones em cima', (
      tester,
    ) async {
      setWindow(tester, 500, 400);
      await pumpPlayer(tester, db: db);
      expect(find.byType(NavigationRail), findsNothing);
      await tester.tap(find.byTooltip('Pastas'));
      await tester.pump();
      expect(find.text('Atualizar tudo'), findsOneWidget);
    });
  });

  testWidgets('a capa do cartão é quadrada em qualquer largura', (
    tester,
  ) async {
    seedAlbum(db);
    for (final width in [300.0, 700.0, 1280.0]) {
      setWindow(tester, width, 800);
      await pumpPlayer(tester, db: db);
      final size = tester.getSize(find.byType(CoverArt).first);
      expect(size.width, closeTo(size.height, 1), reason: '$width');
    }
  });

  testWidgets('o Início mostra só uma fileira de recentes', (tester) async {
    setWindow(tester, 1280, 800);
    for (var i = 0; i < 12; i++) {
      seedAlbum(db, album: 'Album $i', tracks: 1);
    }
    await pumpPlayer(tester, db: db);
    final cards = find.byType(AlbumCard);
    final rows = {
      for (final element in cards.evaluate())
        tester.getTopLeft(find.byWidget(element.widget)).dy,
    };
    expect(rows, hasLength(1));
    expect(cards.evaluate().length, lessThan(12));
  });

  group('navegação', () {
    testWidgets('a barra lateral tem os destinos do esboço', (tester) async {
      setWindow(tester, 1280, 800);
      await pumpPlayer(tester, db: db);
      NavigationRail rail() =>
          tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail().selectedIndex, 0);
      for (final label in [
        'Início',
        'Biblioteca',
        'Playlists',
        'Pastas',
        'Buscar',
      ]) {
        expect(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
      await tester.tap(find.text('Playlists'));
      await tester.pump();
      expect(rail().selectedIndex, 2);
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pump();
      expect(rail().selectedIndex, isNull);
    });
  });

  group('biblioteca vazia', () {
    testWidgets('oferece adicionar e usar a pasta de música', (tester) async {
      setWindow(tester, 1280, 800);
      final scanner = FakeScanner();
      await pumpPlayer(tester, db: db, scanner: scanner, musicDir: '/tmp');
      expect(find.text('Sua biblioteca está vazia'), findsOneWidget);
      expect(find.text('FLAC'), findsOneWidget);
      await tester.tap(find.text('Usar /tmp'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      await tester.pump();
      expect(scanner.sessions.single.folders.single.path, '/tmp');
      expect(find.byType(ScanCard), findsOneWidget);
      expect(find.text('Sua biblioteca está vazia'), findsNothing);
    });

    testWidgets('sem a pasta de música, só adicionar', (tester) async {
      await pumpPlayer(tester, db: db);
      expect(find.text('Adicionar pasta de músicas'), findsOneWidget);
      expect(find.textContaining('Usar'), findsNothing);
    });

    testWidgets('o botão da barra usa o seletor; uma pasta invisível avisa', (
      tester,
    ) async {
      setWindow(tester, 1280, 800);
      await pumpPlayer(tester, db: db, picked: '/nao/existe');
      await tester.tap(find.byTooltip('Adicionar pasta'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('não enxerga'), findsOneWidget);
    });
  });

  group('varredura', () {
    testWidgets('mostra o progresso, o que achou e os controles', (
      tester,
    ) async {
      setWindow(tester, 1280, 800);
      seedAlbum(db);
      final scanner = FakeScanner();
      await pumpPlayer(tester, db: db, scanner: scanner);
      await tester.tap(find.text('Biblioteca'));
      await tester.pump();
      await tester.tap(find.text('Pastas'));
      await tester.pump();
      await tester.tap(find.byTooltip('Atualizar pasta'));
      await tester.pump();
      final session = scanner.sessions.single;
      session.controller.add(
        const ScanProgress(
          total: 1847,
          done: 1140,
          currentFolder: '/m/Coral Vento',
          albums: 78,
          tracks: 1140,
          covers: 64,
          skipped: 1,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Lendo sua biblioteca'), findsOneWidget);
      expect(find.text('1.140 de 1.847 arquivos'), findsOneWidget);
      expect(find.text('78 álbuns'), findsOneWidget);
      expect(find.text('1 arquivo ignorado'), findsOneWidget);
      await tester.tap(find.text('Pausar'));
      await tester.pump();
      expect(session.log, ['pause']);
      await tester.tap(find.text('Continuar'));
      await tester.pump();
      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      expect(session.log, ['pause', 'resume', 'cancel']);
      await session.controller.close();
      await tester.pump();
      await tester.pump();
      expect(find.byType(ScanCard), findsNothing);
    });
  });

  group('com música', () {
    late FakeEngine engine;

    Future<void> open(WidgetTester tester) async {
      setWindow(tester, 1280, 800);
      engine = FakeEngine();
      await pumpPlayer(tester, engine: engine, db: db);
    }

    setUp(() => seedAlbum(db));

    testWidgets('a grade abre o álbum, com faixas, e o álbum toca', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Biblioteca'));
      await tester.pump();
      expect(find.text('3 músicas', findRichText: true), findsNothing);
      await tester.tap(find.byType(AlbumCard));
      await tester.pump();
      await tester.pump();
      expect(find.byType(TrackRow), findsNWidgets(3));
      expect(find.text('Coral Vento'), findsWidgets);
      expect(find.text('FLAC'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'Tocar'));
      await tester.pump();
      await tester.pump();
      expect(engine.opened.single, hasLength(3));
      expect(find.byIcon(Icons.equalizer_rounded), findsOneWidget);
      await tester.tap(find.text('Álbuns'));
      await tester.pump();
      expect(find.byType(AlbumCard), findsOneWidget);
    });

    testWidgets('clicar numa faixa toca a partir dela', (tester) async {
      await open(tester);
      await tester.tap(find.text('Biblioteca'));
      await tester.pump();
      await tester.tap(find.byType(AlbumCard));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Maré Alta 2'));
      await tester.pump();
      await tester.pump();
      expect(engine.state.value.index, 1);
    });

    testWidgets('o menu da faixa põe na fila', (tester) async {
      await open(tester);
      await tester.tap(find.text('Biblioteca'));
      await tester.pump();
      await tester.tap(find.byType(AlbumCard));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byTooltip('Mais opções').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar à fila'));
      await tester.pumpAndSettle();
      expect(engine.state.value.queue, ['/m/Maré Alta/1.flac']);
    });

    testWidgets('passar o ponteiro no cartão mostra tocar', (tester) async {
      await open(tester);
      await tester.tap(find.text('Biblioteca'));
      await tester.pump();
      expect(find.byTooltip('Tocar Maré Alta'), findsNothing);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(AlbumCard)));
      await tester.pump();
      await tester.tap(find.byTooltip('Tocar Maré Alta'));
      await tester.pump();
      await tester.pump();
      expect(engine.opened.single, hasLength(3));
    });

    testWidgets('a fila abre ao lado, mostra e pula', (tester) async {
      await open(tester);
      await tester.tap(find.text('Biblioteca'));
      await tester.pump();
      await tester.tap(find.byType(AlbumCard));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Tocar'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byTooltip('Fila'));
      await tester.pump();
      expect(find.byType(QueuePanel), findsOneWidget);
      expect(find.text('3 músicas · 9 min'), findsOneWidget);
      final rows = find.descendant(
        of: find.byType(QueuePanel),
        matching: find.byType(TrackRow),
      );
      expect(rows, findsNWidgets(3));
      await tester.tap(rows.last);
      await tester.pump();
      expect(engine.state.value.index, 2);
      await tester.tap(find.byTooltip('Tirar da fila').first);
      await tester.pump();
      expect(engine.state.value.queue, hasLength(2));
      await tester.tap(find.byTooltip('Fechar'));
      await tester.pump();
      expect(find.byType(QueuePanel), findsNothing);
    });

    testWidgets('o Início mostra recentes, mais tocadas e continuar', (
      tester,
    ) async {
      final album = db.albums().single.id;
      db.recordPlay(db.albumTracks(album).first.id, 1);
      await pumpPlayerWithSession(tester, db);
      expect(find.text('Adicionados recentemente'), findsOneWidget);
      expect(find.text('Mais tocadas'), findsOneWidget);
      expect(find.text('CONTINUAR DE ONDE PAROU'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      await tester.pump();
      expect(find.text('CONTINUAR DE ONDE PAROU'), findsNothing);
    });

    testWidgets('tudo em aleatório toca', (tester) async {
      await open(tester);
      await tester.tap(find.text('Tudo em aleatório'));
      await tester.pump();
      await tester.pump();
      expect(engine.opened.single, hasLength(3));
    });

    testWidgets('a pasta mostra situação, e remover tira da biblioteca', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Pastas'));
      await tester.pump();
      expect(find.byType(FolderRow), findsOneWidget);
      expect(find.text('Disco não encontrado'), findsOneWidget);
      expect(find.text('1 álbum · 3 músicas · 3 MB'), findsOneWidget);
      await tester.tap(find.byTooltip('Mais opções'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover da biblioteca'));
      await tester.pumpAndSettle();
      expect(find.byType(FolderRow), findsNothing);
      expect(db.totals().tracks, 0);
    });

    testWidgets('a barra mostra a faixa, e tocar, pausar e pular funcionam', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Tudo em aleatório'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byTooltip('Pausar'));
      await tester.pump();
      expect(engine.state.value.playing, isFalse);
      await tester.tap(find.byTooltip('Próxima faixa'));
      await tester.pump();
      expect(engine.state.value.index, 1);
      await tester.tap(find.byTooltip('Aleatório'));
      await tester.pump();
      expect(engine.state.value.shuffle, isTrue);
      await tester.tap(find.byTooltip('Repetir: desligado'));
      await tester.pump();
      expect(find.byTooltip('Repetir: tudo'), findsOneWidget);
    });

    testWidgets('arrastar o progresso só leva ao motor ao soltar', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Tudo em aleatório'));
      await tester.pump();
      await tester.pump();
      final bar = find.descendant(
        of: find.byType(PlayerBar),
        matching: find.byType(Slider),
      );
      final drag = await tester.startGesture(tester.getCenter(bar.first));
      await tester.pump();
      expect(engine.seeks, isEmpty);
      await drag.up();
      await tester.pump();
      expect(engine.seeks.single.inSeconds, closeTo(93, 2));
    });

    testWidgets('o volume vai ao motor', (tester) async {
      await open(tester);
      final bar = find.descendant(
        of: find.byType(PlayerBar),
        matching: find.byType(Slider),
      );
      await tester.tap(bar.last);
      await tester.pump();
      expect(engine.state.value.volume, lessThan(1));
    });
  });

  group('atalhos', () {
    late FakeEngine engine;

    Future<void> playing(WidgetTester tester, {Widget? extra}) async {
      setWindow(tester, 1280, 800);
      engine = FakeEngine();
      seedAlbum(db);
      await pumpPlayer(tester, engine: engine, db: db);
      await tester.tap(find.text('Tudo em aleatório'));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('Espaço toca e pausa, e as setas andam 5 s', (tester) async {
      await playing(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(engine.state.value.playing, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(engine.seeks.last, const Duration(seconds: 5));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(engine.seeks.last, Duration.zero);
    });

    testWidgets('com um botão em foco, o Espaço é dele', (tester) async {
      await playing(tester);
      String? focusedTooltip() => FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<Tooltip>()
          ?.message;
      for (var i = 0; i < 60 && focusedTooltip() != 'Próxima faixa'; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(focusedTooltip(), 'Próxima faixa');
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(engine.state.value.playing, isTrue);
      expect(engine.state.value.index, 1);
    });

    testWidgets('digitando, nenhum atalho vale', (tester) async {
      setWindow(tester, 1280, 800);
      engine = FakeEngine();
      seedAlbum(db);
      await pumpPlayer(tester, engine: engine, db: db);
      await tester.tap(find.text('Tudo em aleatório'));
      await tester.pump();
      await tester.pump();
      final field = FocusNode();
      addTearDown(field.dispose);
      final overlay = OverlayEntry(
        builder: (_) => Material(child: TextField(focusNode: field)),
      );
      tester.state<OverlayState>(find.byType(Overlay).first).insert(overlay);
      addTearDown(() {
        overlay
          ..remove()
          ..dispose();
      });
      await tester.pump();
      field.requestFocus();
      await tester.pump();
      expect(field.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(engine.state.value.playing, isTrue);
      expect(engine.seeks, isEmpty);
    });

    testWidgets('sem nada na fila, o Espaço não faz nada', (tester) async {
      setWindow(tester, 1280, 800);
      engine = FakeEngine();
      await pumpPlayer(tester, engine: engine, db: db);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(engine.state.value.playing, isFalse);
    });
  });

  group('o resto', () {
    testWidgets('o tema segue a cor de destaque', (tester) async {
      ColorScheme scheme() =>
          Theme.of(tester.element(find.byType(PlayerBar))).colorScheme;
      await pumpPlayer(tester, db: db, accent: const Color(0xFF2196F3));
      final blue = scheme();
      await pumpPlayer(tester, db: db, accent: const Color(0xFFE91E63));
      await tester.pumpAndSettle();
      expect(blue.primary, isNot(scheme().primary));
      expect(blue.brightness, Brightness.dark);
      expect(blue.primaryContainer, isNot(blue.surface));
    });

    testWidgets('todo controle tem nome para o leitor de tela', (tester) async {
      setWindow(tester, 1280, 800);
      final handle = tester.ensureSemantics();
      seedAlbum(db);
      await pumpPlayer(tester, db: db);
      for (final page in ['Início', 'Biblioteca', 'Pastas']) {
        await tester.tap(find.text(page).first);
        await tester.pump();
        final root = tester.getSemantics(find.byType(PlayerBar));
        expect(root, isNotNull);
        final unnamed = <String>[];
        void visit(SemanticsNode node) {
          final data = node.getSemanticsData();
          final tappable = data.hasAction(SemanticsAction.tap);
          if (tappable && data.label.isEmpty && data.tooltip.isEmpty) {
            unnamed.add('$page: $node');
          }
          node.visitChildren((child) {
            visit(child);
            return true;
          });
        }

        visit(root.owner!.rootSemanticsNode!);
        expect(unnamed, isEmpty);
      }
      expect(find.bySemanticsLabel(RegExp('Progresso')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('Volume')), findsWidgets);
      handle.dispose();
    });

    testWidgets('sem faixa, não toca', (tester) async {
      await pumpPlayer(tester, db: db);
      expect(find.text('Nenhuma faixa'), findsOneWidget);
      final play = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.play_arrow_rounded).first,
      );
      expect(play.onPressed, isNull);
    });

    testWidgets('um arquivo de fora abre com o nome que o motor leu', (
      tester,
    ) async {
      setWindow(tester, 1280, 800);
      final engine = FakeEngine();
      await pumpPlayer(
        tester,
        engine: engine,
        db: db,
        initialPaths: const ['/musica/faixa.flac', '/musica/b.flac'],
      );
      await tester.pump();
      expect(engine.opened.single, ['/musica/faixa.flac', '/musica/b.flac']);
      expect(find.text('faixa.flac'), findsOneWidget);
    });

    testWidgets('um erro do motor aparece na barra', (tester) async {
      final engine = FakeEngine();
      await pumpPlayer(tester, engine: engine, db: db);
      engine.set(engine.state.value.copyWith(error: 'ruim'));
      await tester.pump();
      expect(find.textContaining('ruim'), findsOneWidget);
    });

    testWidgets('sem o motor, avisa em vez de cair', (tester) async {
      await pumpPlayer(tester, createEngine: () => throw Exception('libmpv'));
      expect(
        find.textContaining('O motor de áudio não está disponível'),
        findsOneWidget,
      );
    });

    testWidgets('sem o banco, avisa em vez de cair', (tester) async {
      await pumpPlayer(
        tester,
        openLibrary: () async => throw StateError('sqlite'),
      );
      expect(
        find.textContaining('Não foi possível abrir a biblioteca'),
        findsOneWidget,
      );
    });

    testWidgets('fechar grava a sessão e solta o motor', (tester) async {
      final engine = FakeEngine();
      seedAlbum(db);
      await pumpPlayer(tester, engine: engine, db: db);
      await tester.tap(find.text('Tudo em aleatório'), warnIfMissed: false);
      await tester.pump();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump();
      expect(db.setting('session'), contains('Maré Alta'));
      expect(engine.disposed, isTrue);
    });
  });

  test('formatDuration', () {
    const pt = Locale('pt');
    expect(formatDuration(const Duration(seconds: 7), pt), '0:07');
    expect(formatDuration(const Duration(minutes: 3, seconds: 7), pt), '3:07');
    expect(
      formatDuration(const Duration(hours: 1, minutes: 2, seconds: 7), pt),
      '1:02:07',
    );
  });

  test('formatSize', () {
    const pt = Locale('pt');
    expect(formatSize(96000000000, pt), '96 GB');
    expect(formatSize(2100000000, pt), '2,1 GB');
    expect(formatSize(340000000, pt), '340 MB');
    expect(formatSize(0, pt), '0 MB');
  });
}

/// Abre o player com uma sessão guardada, para o cartão de continuar.
Future<void> pumpPlayerWithSession(WidgetTester tester, LibraryDb db) async {
  setWindow(tester, 1280, 800);
  db.setSetting(
    'session',
    '{"queue":["/m/Maré Alta/1.flac"],"index":0,"positionMs":84000,'
        '"volume":1,"repeat":"off"}',
  );
  await pumpPlayer(tester, engine: FakeEngine(), db: db);
  await tester.pump();
}
