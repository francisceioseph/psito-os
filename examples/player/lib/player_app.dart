// examples/player/lib/player_app.dart
//
// O Psito Player. Na Fase 0: a barra lateral sem telas, abrir arquivos e tocar.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'l10n/player_localizations.dart';
import 'src/player/engine.dart';
import 'src/player/media_kit_engine.dart';
import 'src/player/player_bar.dart';

const audioPatterns = ['*.flac', '*.mp3', '*.ogg', '*.opus', '*.m4a', '*.wav'];

/// O tema do player: os papéis tonais do Material 3 a partir da cor de destaque,
/// que o `psitoTheme` só traz como `primary`.
ThemeData playerTheme(ThemeData base) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: base.colorScheme.primary,
    brightness: Brightness.dark,
  ),
  extensions: base.extensions.values,
);

class PlayerView extends StatefulWidget {
  /// Cria o motor. Pode lançar, se faltar a biblioteca.
  final PlayerEngine Function() createEngine;

  /// O que abre ao começar.
  final List<String> initialPaths;

  /// O seletor de arquivos. Devolve o caminho, ou null se cancelaram.
  final Future<String?> Function(String title) pickFile;

  const PlayerView({
    super.key,
    required this.createEngine,
    required this.pickFile,
    this.initialPaths = const [],
  });

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  /// Abaixo disto, a barra lateral não cabe e fica só o player.
  static const _railMinWidth = 320.0;
  static const _railMinHeight = 520.0;
  static const _barHeight = 80.0;

  PlayerEngine? _engine;
  String? _engineError;
  int _destination = 0;

  @override
  void initState() {
    super.initState();
    try {
      _engine = widget.createEngine();
    } catch (e) {
      debugPrint('🎵 sem motor: $e');
      _engineError = '$e';
      return;
    }
    if (widget.initialPaths.isNotEmpty) {
      unawaited(_engine!.open(widget.initialPaths));
    }
  }

  @override
  void dispose() {
    unawaited(_engine?.dispose());
    super.dispose();
  }

  Future<void> _pick(PlayerEngine engine, String title) async {
    final path = await widget.pickFile(title);
    if (path != null) await engine.open([path]);
  }

  Widget _rail(PlayerLocalizations l, PlayerEngine engine) {
    NavigationRailDestination destination(IconData icon, String label) =>
        NavigationRailDestination(icon: Icon(icon), label: Text(label));
    return NavigationRail(
      selectedIndex: _destination,
      labelType: NavigationRailLabelType.all,
      onDestinationSelected: (i) => setState(() => _destination = i),
      leading: IconButton.filledTonal(
        tooltip: l.openFile,
        icon: const Icon(Icons.folder_open_rounded),
        onPressed: () => _pick(engine, l.openFile),
      ),
      destinations: [
        destination(Icons.album_rounded, l.library),
        destination(Icons.music_note_rounded, l.songs),
        destination(Icons.person_rounded, l.artists),
        destination(Icons.queue_music_rounded, l.playlists),
        destination(Icons.folder_rounded, l.folders),
        destination(Icons.category_rounded, l.genres),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = PlayerLocalizations.of(context);
    final theme = playerTheme(Theme.of(context));
    final engine = _engine;
    return Theme(
      data: theme,
      child: ColoredBox(
        color: theme.colorScheme.surface,
        child: DefaultTextStyle(
          style: theme.textTheme.bodyMedium!,
          child: engine == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(l.engineUnavailable(_engineError ?? '')),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) => Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (constraints.maxWidth >= _railMinWidth &&
                                constraints.maxHeight >= _railMinHeight)
                              _rail(l, engine),
                            const Expanded(child: SizedBox.expand()),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: _barHeight,
                        child: PlayerBar(engine: engine),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class PlayerApp extends PsitoApp {
  const PlayerApp();

  @override
  String get id => 'player';

  @override
  String get name => 'Music Player';

  @override
  String localizedName(Locale locale) =>
      lookupPlayerLocalizations(locale).appName;

  @override
  List<LocalizationsDelegate<dynamic>> get localizationsDelegates => const [
    PlayerLocalizations.delegate,
  ];

  @override
  IconData get icon => Icons.music_note_rounded;

  @override
  Color get color => const Color(0xFFFE8363);

  @override
  Size get defaultSize => const Size(1280, 800);

  @override
  Widget build(PsitoAppContext context) => PlayerView(
    createEngine: MediaKitEngine.new,
    initialPaths: context.openedPaths,
    pickFile: (title) =>
        context.pickFile(title: title, patterns: audioPatterns),
  );
}
