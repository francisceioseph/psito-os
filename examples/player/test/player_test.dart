import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_player/player_app.dart';
import 'package:psito_player/src/player/engine.dart';
import 'package:psito_player/src/player/player_bar.dart';
import 'package:psito_sdk/psito_sdk.dart';

class FakeEngine implements PlayerEngine {
  final _state = ValueNotifier(const PlayerState());
  final opened = <List<String>>[];
  final seeks = <Duration>[];
  bool disposed = false;

  @override
  ValueNotifier<PlayerState> get state => _state;

  @override
  Future<void> open(List<String> paths) async {
    opened.add(paths);
    _state.value = PlayerState(
      title: paths.first.split('/').last,
      duration: const Duration(minutes: 3, seconds: 7),
      playing: true,
      format: 'flac 96000 Hz s32 2 ch',
    );
  }

  @override
  Future<void> playOrPause() async {
    _state.value = _state.value.copyWith(playing: !_state.value.playing);
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    _state.value = _state.value.copyWith(position: position);
  }

  @override
  Future<void> setVolume(double volume) async {
    _state.value = _state.value.copyWith(volume: volume);
  }

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    PlayerEngine Function() createEngine, {
    List<String> initialPaths = const [],
    String? picked,
    Color accent = const Color(0xFFFFC107),
  }) => tester.pumpWidget(
    MaterialApp(
      theme: psitoTheme(accent),
      localizationsDelegates: psitoLocalizationsDelegates(
        const PlayerApp().localizationsDelegates,
      ),
      supportedLocales: psitoLocales,
      home: Scaffold(
        body: PlayerView(
          createEngine: createEngine,
          initialPaths: initialPaths,
          pickFile: (_) async => picked,
        ),
      ),
    ),
  );

  testWidgets('cabe em 240x160', (tester) async {
    tester.view.physicalSize = const Size(240, 160);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      FakeEngine.new,
      initialPaths: const ['/musica/faixa.flac'],
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a barra lateral aparece sem telas, em todos os destinos', (
    tester,
  ) async {
    await pump(tester, FakeEngine.new);
    expect(find.byType(NavigationRail), findsOneWidget);
    for (final label in [
      'Biblioteca',
      'Músicas',
      'Artistas',
      'Playlists',
      'Pastas',
      'Gêneros',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Músicas'));
    await tester.pump();
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.selectedIndex, 1);
  });

  testWidgets('sem espaço, a barra lateral sai e o player fica', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 160);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, FakeEngine.new);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(PlayerBar), findsOneWidget);
  });

  testWidgets('o tema segue a cor de destaque, sem cor própria', (
    tester,
  ) async {
    ColorScheme schemeFor() =>
        Theme.of(tester.element(find.byType(PlayerBar))).colorScheme;
    await pump(tester, FakeEngine.new, accent: const Color(0xFF2196F3));
    final blue = schemeFor();
    await pump(tester, FakeEngine.new, accent: const Color(0xFFE91E63));
    await tester.pumpAndSettle();
    final pink = schemeFor();
    expect(blue.primary, isNot(pink.primary));
    expect(blue.brightness, Brightness.dark);
    expect(blue.primaryContainer, isNot(blue.surface));
  });

  testWidgets('todos os controles têm nome para o leitor de tela', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, FakeEngine.new);
    expect(find.byTooltip('Abrir arquivo'), findsOneWidget);
    expect(find.byTooltip('Tocar'), findsOneWidget);
    for (final label in ['Progresso', 'Volume']) {
      expect(find.bySemanticsLabel(RegExp(label)), findsWidgets);
    }
    handle.dispose();
  });

  testWidgets('sem faixa, não toca nem anda', (tester) async {
    await pump(tester, FakeEngine.new);
    expect(find.text('Nenhuma faixa'), findsOneWidget);
    final play = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.play_arrow_rounded),
    );
    expect(play.onPressed, isNull);
  });

  testWidgets('os arquivos que vieram ao abrir vão juntos, em fila', (
    tester,
  ) async {
    final engine = FakeEngine();
    await pump(
      tester,
      () => engine,
      initialPaths: const ['/m/a.flac', '/m/b.flac'],
    );
    expect(engine.opened, [
      ['/m/a.flac', '/m/b.flac'],
    ]);
  });

  testWidgets('abre o arquivo que veio ao abrir, com nome e duração', (
    tester,
  ) async {
    final engine = FakeEngine();
    await pump(
      tester,
      () => engine,
      initialPaths: const ['/musica/faixa.flac'],
    );
    await tester.pump();
    expect(engine.opened, [
      ['/musica/faixa.flac'],
    ]);
    expect(find.text('faixa.flac'), findsOneWidget);
    expect(find.text('0:00 / 3:07  flac 96000 Hz s32 2 ch'), findsOneWidget);
  });

  testWidgets('o seletor abre o arquivo escolhido', (tester) async {
    final engine = FakeEngine();
    await pump(tester, () => engine, picked: '/musica/outra.mp3');
    await tester.tap(find.byTooltip('Abrir arquivo'));
    await tester.pump();
    expect(engine.opened, [
      ['/musica/outra.mp3'],
    ]);
  });

  testWidgets('tocar e pausar', (tester) async {
    final engine = FakeEngine();
    await pump(
      tester,
      () => engine,
      initialPaths: const ['/musica/faixa.flac'],
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Pausar'));
    await tester.pump();
    expect(engine.state.value.playing, isFalse);
    expect(find.byTooltip('Tocar'), findsOneWidget);
  });

  testWidgets('arrastar a barra só leva ao motor ao soltar', (tester) async {
    final engine = FakeEngine();
    await pump(
      tester,
      () => engine,
      initialPaths: const ['/musica/faixa.flac'],
    );
    await tester.pump();
    final bar = find.byType(Slider).first;
    final drag = await tester.startGesture(tester.getCenter(bar));
    await tester.pump();
    expect(engine.seeks, isEmpty);
    await drag.up();
    await tester.pump();
    expect(engine.seeks, hasLength(1));
    expect(engine.seeks.single.inSeconds, closeTo(93, 2));
  });

  testWidgets('o volume vai ao motor', (tester) async {
    final engine = FakeEngine();
    await pump(
      tester,
      () => engine,
      initialPaths: const ['/musica/faixa.flac'],
    );
    await tester.pump();
    await tester.tap(find.byType(Slider).last);
    await tester.pump();
    expect(engine.state.value.volume, lessThan(1));
  });

  testWidgets('sem a biblioteca, avisa em vez de cair', (tester) async {
    await pump(tester, () => throw Exception('libmpv'));
    expect(
      find.textContaining('O motor de áudio não está disponível'),
      findsOneWidget,
    );
  });

  testWidgets('fechar solta o motor', (tester) async {
    final engine = FakeEngine();
    await pump(tester, () => engine);
    await tester.pumpWidget(const SizedBox());
    expect(engine.disposed, isTrue);
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
}
