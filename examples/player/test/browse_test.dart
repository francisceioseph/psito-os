// As telas da Fase 2, com o banco em memória.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_player/src/library/library_db.dart';
import 'package:psito_player/src/library/models.dart';
import 'package:psito_player/src/library/scanner.dart';
import 'package:psito_player/src/ui/atoms/favorite_button.dart';
import 'package:psito_player/src/ui/atoms/monogram.dart';
import 'package:psito_player/src/ui/molecules/album_card.dart';
import 'package:psito_player/src/ui/molecules/album_row.dart';
import 'package:psito_player/src/ui/molecules/artist_card.dart';
import 'package:psito_player/src/ui/molecules/dir_row.dart';
import 'package:psito_player/src/ui/molecules/genre_card.dart';
import 'package:psito_player/src/ui/molecules/playlist_card.dart';
import 'package:psito_player/src/ui/molecules/track_row.dart';
import 'package:psito_player/src/ui/organisms/best_result_card.dart';

import 'helpers.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

void main() {
  late LibraryDb db;
  late FakeEngine engine;

  setUp(() {
    db = LibraryDb.memory();
    engine = FakeEngine();
    seedAlbum(db, album: 'Maré Alta', artist: 'Coral Vento', tracks: 3);
    seedAlbum(db, album: 'Luz de Neon', artist: 'Rua 9', tracks: 2);
  });

  Future<void> open(
    WidgetTester tester, {
    double width = 1280,
    double height = 800,
    String? pickedPlaylist,
    String? pickedSave,
    FakeScanner? scanner,
  }) async {
    setWindow(tester, width, height);
    await pumpPlayer(
      tester,
      engine: engine,
      db: db,
      scanner: scanner,
      pickedPlaylist: pickedPlaylist,
      pickedSave: pickedSave,
    );
    await settle(tester);
  }

  Future<void> go(WidgetTester tester, String destination) async {
    await tester.tap(find.text(destination).first);
    await settle(tester);
  }

  Future<void> chip(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(FilterChip, label));
    await settle(tester);
  }

  group('janela', () {
    for (final (w, h) in const [
      (240.0, 400.0),
      (400.0, 300.0),
      (600.0, 500.0),
      (800.0, 600.0),
      (1280.0, 800.0),
    ]) {
      testWidgets('cabe em ${w.toInt()}x${h.toInt()}, em cada seção', (
        tester,
      ) async {
        db.createPlaylist('Estrada', 1, ['/m/Maré Alta/1.flac']);
        await open(tester, width: w, height: h);
        Future<void> nav(String tooltip) async {
          final byTooltip = find.byTooltip(tooltip);
          final target = byTooltip.evaluate().isNotEmpty
              ? byTooltip
              : find.text(tooltip);
          await tester.ensureVisible(target.first);
          await tester.pump();
          await tester.tap(target.first, warnIfMissed: false);
          await settle(tester);
          expect(tester.takeException(), isNull, reason: tooltip);
        }

        await nav('Biblioteca');
        for (final label in [
          'Artistas',
          'Pastas',
          'Playlists',
          'Gêneros',
          'Músicas',
        ]) {
          final target = find.widgetWithText(FilterChip, label);
          await tester.ensureVisible(target);
          await tester.pump();
          await tester.tap(target, warnIfMissed: false);
          await settle(tester);
          expect(tester.takeException(), isNull, reason: label);
        }
        await nav('Playlists');
        await nav('Pastas');
        await nav('Buscar');
        await tester.enterText(find.byType(EditableText), 'coral');
        await tester.pump(const Duration(milliseconds: 200));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'busca');
      });
    }
  });

  group('biblioteca', () {
    testWidgets('alterna grade e lista, e ordena', (tester) async {
      await open(tester);
      await go(tester, 'Biblioteca');
      expect(find.byType(AlbumCard), findsNWidgets(2));
      await tester.tap(find.byTooltip('Lista'));
      await settle(tester);
      expect(find.byType(AlbumCard), findsNothing);
      expect(find.byType(AlbumRow), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('Luz de Neon')).dy,
        lessThan(tester.getTopLeft(find.text('Maré Alta')).dy),
      );
      await tester.tap(find.byTooltip('Ordenar por'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Artista').last);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Maré Alta')).dy,
        lessThan(tester.getTopLeft(find.text('Luz de Neon')).dy),
      );
    });

    testWidgets('Artistas abre o artista, com os álbuns e as faixas', (
      tester,
    ) async {
      await open(tester);
      await go(tester, 'Biblioteca');
      await chip(tester, 'Artistas');
      expect(find.byType(ArtistCard), findsNWidgets(2));
      expect(find.text('CV'), findsOneWidget);
      await tester.tap(find.widgetWithText(ArtistCard, 'Rua 9'));
      await settle(tester);
      expect(find.byType(Monogram), findsOneWidget);
      expect(find.byType(AlbumCard), findsOneWidget);
      expect(find.byType(TrackRow), findsNWidgets(2));
      await tester.tap(find.widgetWithText(FilledButton, 'Tocar'));
      await settle(tester);
      expect(engine.opened.single, hasLength(2));
      await tester.tap(find.byType(AlbumCard));
      await settle(tester);
      expect(find.text('Luz de Neon'), findsWidgets);
      // Voltar volta um passo de cada vez
      await tester.tap(find.text('Voltar'));
      await settle(tester);
      expect(find.byType(Monogram), findsOneWidget);
      await tester.tap(find.text('Voltar'));
      await settle(tester);
      expect(find.byType(ArtistCard), findsNWidgets(2));
    });

    testWidgets('Músicas: colunas, ordem, filtros e favorita', (tester) async {
      await open(tester);
      await go(tester, 'Biblioteca');
      await chip(tester, 'Músicas');
      expect(find.byType(TrackRow), findsNWidgets(5));
      expect(find.text('Título'), findsOneWidget);
      expect(find.text('Formato'), findsOneWidget);
      final first = tester.getTopLeft(find.text('Luz de Neon 1')).dy;
      expect(first, lessThan(tester.getTopLeft(find.text('Maré Alta 1')).dy));
      await tester.tap(find.text('Título'));
      await settle(tester);
      expect(
        tester.getTopLeft(find.text('Maré Alta 1')).dy,
        lessThan(tester.getTopLeft(find.text('Luz de Neon 1')).dy),
      );
      await tester.tap(
        find
            .descendant(
              of: find.widgetWithText(TrackRow, 'Maré Alta 1'),
              matching: find.byType(FavoriteButton),
            )
            .first,
      );
      await settle(tester);
      await chip(tester, 'Favoritas');
      expect(find.byType(TrackRow), findsOneWidget);
      expect(find.text('Maré Alta 1'), findsOneWidget);
      await tester.tap(find.text('Biblioteca').last);
      await settle(tester);
      expect(find.byType(AlbumCard), findsNWidgets(2));
    });

    testWidgets('Pastas e Gêneros abrem as faixas', (tester) async {
      await open(tester);
      await go(tester, 'Biblioteca');
      await chip(tester, 'Pastas');
      expect(find.byType(DirRow), findsNWidgets(2));
      await tester.tap(find.byType(DirRow).first);
      await settle(tester);
      expect(find.byType(TrackRow), findsNWidgets(2));
      await tester.tap(find.text('Voltar'));
      await settle(tester);
      await chip(tester, 'Gêneros');
      expect(find.byType(GenreCard), findsOneWidget);
      expect(find.text('Sem gênero'), findsOneWidget);
      await tester.tap(find.byType(GenreCard));
      await settle(tester);
      expect(find.byType(TrackRow), findsNWidgets(5));
    });

    testWidgets('tocar de uma lista enorme leva só um pedaço para a fila', (
      tester,
    ) async {
      final folder = db.addFolder('/grande');
      db.begin();
      for (var i = 0; i < 1500; i++) {
        db.upsertTrack(
          ScannedTrack(path: '/grande/$i.flac', title: 'g$i', album: 'G'),
          folder,
          1,
        );
      }
      db.commit();
      await open(tester);
      await go(tester, 'Biblioteca');
      await chip(tester, 'Músicas');
      await tester.tap(find.byType(TrackRow).first);
      await settle(tester);
      expect(engine.opened.single, hasLength(500));
      expect(engine.state.value.index, 0);
    });
  });

  group('disco ausente', () {
    testWidgets('a faixa fica apagada e não toca', (tester) async {
      final scanner = FakeScanner();
      final dir = Directory.systemTemp.createTempSync('psito-browse');
      addTearDown(() => dir.deleteSync(recursive: true));
      seedAlbum(db, folder: dir.path, album: 'Fora', tracks: 1);
      final id = db.folders().firstWhere((f) => f.path == dir.path).id;
      scanner.checks = {id: const FolderCheck(unavailable: true)};
      await tester.runAsync(() async {
        await open(tester, scanner: scanner);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await settle(tester);
      await go(tester, 'Pastas');
      expect(find.text('Disco não encontrado'), findsOneWidget);
      await go(tester, 'Biblioteca');
      await tester.tap(find.widgetWithText(AlbumCard, 'Fora'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await settle(tester);
      expect(
        find.byTooltip('Este arquivo não está disponível agora'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TrackRow, 'Fora 1'));
      await settle(tester);
      expect(engine.opened, isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Tocar'));
      await settle(tester);
      expect(engine.opened, isEmpty);
      expect(find.textContaining('não estão disponíveis'), findsOneWidget);
    });
  });

  group('pastas', () {
    testWidgets('mostra o que mudou, e desligar observar fica guardado', (
      tester,
    ) async {
      final scanner = FakeScanner();
      db.setSetting('watchFolders', 'off');
      scanner.checks = {db.folders().first.id: const FolderCheck(changes: 12)};
      await tester.runAsync(() async {
        await open(tester, scanner: scanner);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await settle(tester);
      await go(tester, 'Pastas');
      expect(find.text('12 alterações'), findsOneWidget);
      expect(scanner.sessions, isEmpty);
      final toggle = find.byType(SwitchListTile);
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    });
  });

  group('playlists', () {
    testWidgets('as automáticas aparecem, e os filtros separam', (
      tester,
    ) async {
      db.createPlaylist('Estrada', 1, ['/m/Maré Alta/1.flac']);
      await open(tester);
      await go(tester, 'Playlists');
      expect(find.byType(PlaylistCard), findsNWidgets(4));
      expect(find.text('Mais tocadas'), findsOneWidget);
      await chip(tester, 'Minhas');
      expect(find.byType(PlaylistCard), findsOneWidget);
      await chip(tester, 'Automáticas');
      expect(find.byType(PlaylistCard), findsNWidgets(3));
    });

    testWidgets('criar, adicionar pelo menu da faixa, reordenar e apagar', (
      tester,
    ) async {
      await open(tester);
      await go(tester, 'Playlists');
      await tester.tap(find.text('Nova playlist'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Estrada');
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();
      expect(find.text('Estrada'), findsOneWidget);

      await go(tester, 'Biblioteca');
      await tester.tap(find.widgetWithText(AlbumCard, 'Maré Alta'));
      await settle(tester);
      for (final title in ['Maré Alta 1', 'Maré Alta 2']) {
        await tester.tap(
          find.descendant(
            of: find.widgetWithText(TrackRow, title),
            matching: find.byIcon(Icons.more_vert_rounded),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Adicionar à playlist'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Estrada'));
        await tester.pumpAndSettle();
        await settle(tester);
      }
      await go(tester, 'Playlists');
      await tester.tap(find.widgetWithText(PlaylistCard, 'Estrada'));
      await settle(tester);
      expect(find.byType(TrackRow), findsNWidgets(2));
      expect(find.text('2 músicas · 6 min'), findsOneWidget);

      // Quem não arrasta tem o menu
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(TrackRow, 'Maré Alta 1'),
          matching: find.byIcon(Icons.more_vert_rounded),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mover para cima'), findsNothing);
      await tester.tap(find.text('Mover para baixo'));
      await tester.pumpAndSettle();
      await settle(tester);
      expect(
        tester.getTopLeft(find.text('Maré Alta 2')).dy,
        lessThan(tester.getTopLeft(find.text('Maré Alta 1')).dy),
      );
      expect(db.playlists().single.trackCount, 2);
      expect(
        db.playlistTracks(db.playlists().single.id).first.title,
        'Maré Alta 2',
      );

      // Tirar uma, renomear e apagar
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(TrackRow, 'Maré Alta 1'),
          matching: find.byIcon(Icons.more_vert_rounded),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tirar da playlist'));
      await tester.pumpAndSettle();
      await settle(tester);
      expect(find.byType(TrackRow), findsOneWidget);

      await tester.tap(find.byTooltip('Mais opções').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renomear'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Viagem');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      await settle(tester);
      expect(find.text('Viagem'), findsOneWidget);

      await tester.tap(find.byTooltip('Mais opções').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await settle(tester);
      expect(db.playlists(), isEmpty);
      expect(find.byType(PlaylistCard), findsNWidgets(3));
    });

    testWidgets('a automática de favoritas segue a faixa marcada', (
      tester,
    ) async {
      db.setFavorite(db.tracks().first.id, true);
      await open(tester);
      await go(tester, 'Playlists');
      await tester.tap(find.widgetWithText(PlaylistCard, 'Favoritas'));
      await settle(tester);
      expect(find.byType(TrackRow), findsOneWidget);
      expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
      expect(find.text('Renomear'), findsNothing);
    });

    testWidgets('a favorita na barra marca a que está tocando', (tester) async {
      await open(tester);
      await go(tester, 'Biblioteca');
      await tester.tap(find.widgetWithText(AlbumCard, 'Maré Alta'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Tocar'));
      await settle(tester);
      final inBar = find.byTooltip('Marcar como favorita').last;
      await tester.tap(inBar);
      await settle(tester);
      expect(db.tracks(const TrackQuery(favorites: true)), hasLength(1));
      expect(find.byTooltip('Tirar das favoritas'), findsWidgets);
    });
  });

  group('busca', () {
    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(EditableText), text);
      await tester.pump(const Duration(milliseconds: 200));
      await settle(tester);
    }

    testWidgets('agrupa, e o melhor resultado toca e abre', (tester) async {
      await open(tester);
      await go(tester, 'Buscar');
      expect(
        find.text('Digite para buscar na sua biblioteca.'),
        findsOneWidget,
      );
      await type(tester, 'coral');
      expect(find.byType(BestResultCard), findsOneWidget);
      expect(find.text('MELHOR RESULTADO'), findsOneWidget);
      expect(find.byType(TrackRow), findsNWidgets(3));
      await tester.tap(find.text('Tocar tudo'));
      await tester.runAsync(() async {});
      await settle(tester);
      expect(engine.opened.single, hasLength(3));
      await tester.tap(find.byType(BestResultCard), warnIfMissed: false);
      await settle(tester);
      expect(find.byType(Monogram), findsOneWidget);
      // Voltar traz a busca como estava
      await tester.tap(find.text('Voltar'));
      await settle(tester);
      expect(find.byType(BestResultCard), findsOneWidget);
      expect(find.text('coral'), findsOneWidget);
    });

    testWidgets('sem resultado avisa, e os filtros mostram um grupo', (
      tester,
    ) async {
      await open(tester);
      await go(tester, 'Buscar');
      await type(tester, 'xyzzy');
      expect(find.textContaining('Nada encontrado'), findsOneWidget);
      await type(tester, 'neon');
      await chip(tester, 'Álbuns');
      expect(find.byType(AlbumCard), findsOneWidget);
      expect(find.byType(TrackRow), findsNothing);
      await chip(tester, 'Artistas');
      expect(find.text('Nada por aqui ainda.'), findsOneWidget);
      await chip(tester, 'Músicas');
      expect(find.byType(TrackRow), findsNWidgets(2));
    });

    testWidgets('Ctrl K vem de qualquer tela e Esc limpa', (tester) async {
      await open(tester);
      await go(tester, 'Pastas');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(find.byType(SearchBar), findsOneWidget);
      await type(tester, 'coral');
      expect(find.byType(BestResultCard), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(BestResultCard), findsNothing);
      expect(
        find.text('Digite para buscar na sua biblioteca.'),
        findsOneWidget,
      );
    });

    testWidgets('o campo da Biblioteca abre a busca no filtro dela', (
      tester,
    ) async {
      await open(tester);
      await go(tester, 'Biblioteca');
      await chip(tester, 'Artistas');
      await tester.tap(find.text('Buscar artistas'));
      await settle(tester);
      expect(find.byType(SearchBar), findsOneWidget);
      final selected = tester
          .widgetList<FilterChip>(find.byType(FilterChip))
          .firstWhere((c) => c.selected);
      expect((selected.label as Text).data, 'Artistas');
    });
  });
}
