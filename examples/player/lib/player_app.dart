// examples/player/lib/player_app.dart
//
// O Psito Player: liga o motor e a biblioteca às telas, e guarda para onde a
// pessoa navegou. Os componentes ficam em `src/ui/`, em atomic design.
import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:psito_sdk/psito_sdk.dart';

import 'l10n/l10n.dart';
import 'l10n/player_localizations.dart';
import 'src/library/library_controller.dart';
import 'src/library/library_store.dart';
import 'src/library/models.dart';
import 'src/library/scanner.dart';
import 'src/player/engine.dart';
import 'src/player/media_kit_engine.dart';
import 'src/player/playback_controller.dart';
import 'src/player/player_shortcuts.dart';
import 'src/ui/organisms/navigation.dart';
import 'src/ui/organisms/player_bar.dart';
import 'src/ui/organisms/queue_panel.dart';
import 'src/ui/pages/album_page.dart';
import 'src/ui/pages/empty_library_page.dart';
import 'src/ui/pages/folders_page.dart';
import 'src/ui/pages/home_page.dart';
import 'src/ui/pages/library_page.dart';
import 'src/ui/pages/soon_page.dart';
import 'src/ui/templates/shell_template.dart';

/// O tema do player: os papéis tonais do Material 3 a partir da cor de destaque,
/// que o `psitoTheme` só traz como `primary`.
ThemeData playerTheme(ThemeData base) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: base.colorScheme.primary,
    brightness: Brightness.dark,
  ),
  extensions: base.extensions.values,
);

/// O banco e o scanner, que abrem de forma assíncrona.
class LibraryServices {
  final LibraryStore store;
  final LibraryScanner scanner;

  const LibraryServices(this.store, this.scanner);
}

class PlayerView extends StatefulWidget {
  /// Cria o motor. Pode lançar, se faltar a biblioteca.
  final PlayerEngine Function() createEngine;

  /// Abre a biblioteca. Pode lançar.
  final Future<LibraryServices> Function() openLibrary;

  /// O que abre ao começar.
  final List<String> initialPaths;

  /// O seletor de pastas. Devolve o caminho, ou null se cancelaram.
  final Future<String?> Function(String title) pickFolder;

  /// A pasta de música da pessoa, se existe.
  final String? musicDir;

  const PlayerView({
    super.key,
    required this.createEngine,
    required this.openLibrary,
    required this.pickFolder,
    this.initialPaths = const [],
    this.musicDir,
  });

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  PlayerEngine? _engine;
  LibraryStore? _store;
  LibraryController? _library;
  PlaybackController? _playback;

  /// O erro de abrir o motor ou a biblioteca.
  String? _engineError;
  String? _libraryError;

  PlayerDestination _destination = PlayerDestination.home;
  Album? _album;
  bool _queueOpen = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Fechar a janela encerra o processo sem passar pelo dispose
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        await _playback?.saveSession();
        return AppExitResponse.exit;
      },
    );
    try {
      _engine = widget.createEngine();
    } catch (e) {
      debugPrint('🎵 sem motor: $e');
      _engineError = '$e';
      return;
    }
    unawaited(_open());
  }

  Future<void> _open() async {
    final LibraryServices services;
    try {
      services = await widget.openLibrary();
    } catch (e) {
      debugPrint('🎵 sem biblioteca: $e');
      if (mounted) setState(() => _libraryError = '$e');
      return;
    }
    if (!mounted) {
      unawaited(services.store.close());
      return;
    }
    _store = services.store;
    final library = LibraryController(
      store: services.store,
      scanner: services.scanner,
    );
    final playback = PlaybackController(
      engine: _engine!,
      store: services.store,
      onPlayRecorded: () => unawaited(library.reload()),
    );
    setState(() {
      _library = library;
      _playback = playback;
    });
    await library.reload();
    if (!mounted) return;
    await playback.restore(open: widget.initialPaths);
  }

  @override
  void dispose() {
    final playback = _playback;
    final store = _store;
    final engine = _engine;
    _lifecycle.dispose();
    _library?.dispose();
    unawaited(() async {
      await playback?.saveSession();
      playback?.dispose();
      await store?.close();
      await engine?.dispose();
    }());
    super.dispose();
  }

  void _navigate(PlayerDestination destination) => setState(() {
    _destination = destination;
    _album = null;
  });

  void _openAlbum(Album album) => setState(() {
    _destination = PlayerDestination.library;
    _album = album;
  });

  Future<void> _addFolder(String path) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await _library!.addFolder(path);
    final message = switch (result) {
      AddFolderResult.added => null,
      AddFolderResult.alreadyInLibrary => l.folderAlreadyAdded,
      AddFolderResult.notVisible => l.folderNotVisible,
    };
    if (message != null) {
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    } else if (mounted) {
      _navigate(PlayerDestination.library);
    }
  }

  Future<void> _pickFolder() async {
    final path = await widget.pickFolder(context.l10n.addFolder);
    if (path != null && mounted) await _addFolder(path);
  }

  Widget _page(LibraryController library, PlaybackController playback) {
    final l = context.l10n;
    final album = _album;
    if (album != null) {
      return AlbumPage(
        key: ValueKey(album.id),
        album: album,
        library: library,
        playback: playback,
        onBack: () => setState(() => _album = null),
      );
    }
    final emptyHere =
        library.empty &&
        (_destination == PlayerDestination.home ||
            _destination == PlayerDestination.library);
    if (emptyHere) {
      return EmptyLibraryPage(
        musicDir: widget.musicDir,
        onAddFolder: () => unawaited(_pickFolder()),
        onUseFolder: (path) => unawaited(_addFolder(path)),
      );
    }
    return switch (_destination) {
      PlayerDestination.home => HomePage(
        library: library,
        playback: playback,
        onOpenAlbum: _openAlbum,
        onSeeAll: () => _navigate(PlayerDestination.library),
      ),
      PlayerDestination.library => LibraryPage(
        library: library,
        playback: playback,
        onOpenAlbum: _openAlbum,
      ),
      PlayerDestination.folders => FoldersPage(
        library: library,
        onAddFolder: () => unawaited(_pickFolder()),
      ),
      PlayerDestination.playlists => SoonPage(title: l.playlists),
      PlayerDestination.search => SoonPage(title: l.search),
      PlayerDestination.settings => SoonPage(title: l.settings),
    };
  }

  Widget _shell(LibraryController library, PlaybackController playback) =>
      ListenableBuilder(
        listenable: Listenable.merge([library, playback]),
        builder: (context, _) => Focus(
          autofocus: true,
          onKeyEvent: (_, event) => handlePlayerKey(event, playback),
          child: ShellTemplate(
            rail: PlayerRail(
              selected: _destination,
              onSelected: _navigate,
              onAddFolder: () => unawaited(_pickFolder()),
            ),
            compactNav: CompactNavigation(
              selected: _destination,
              onSelected: _navigate,
              onAddFolder: () => unawaited(_pickFolder()),
            ),
            content: _page(library, playback),
            panel: _queueOpen
                ? QueuePanel(
                    playback: playback,
                    onClose: () => setState(() => _queueOpen = false),
                  )
                : null,
            bar: PlayerBar(
              playback: playback,
              queueOpen: _queueOpen,
              onToggleQueue: () => setState(() => _queueOpen = !_queueOpen),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = playerTheme(Theme.of(context));
    final library = _library;
    final playback = _playback;
    final Widget body;
    if (_engineError != null) {
      body = _Message(context.l10n.engineUnavailable(_engineError!));
    } else if (_libraryError != null) {
      body = _Message(context.l10n.libraryUnavailable(_libraryError!));
    } else if (library == null || playback == null) {
      body = const SizedBox.expand();
    } else {
      body = _shell(library, playback);
    }
    return Theme(
      data: theme,
      child: Scaffold(backgroundColor: theme.colorScheme.surface, body: body),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;

  const _Message(this.text);

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Text(text),
    ),
  );
}

/// Onde o banco e as miniaturas ficam. Com `files:home`, é o home de verdade.
LibraryServicesPaths libraryPaths(Map<String, String> env) {
  final home = env['HOME'] ?? '.';
  final data = env['XDG_DATA_HOME'] ?? p.join(home, '.local', 'share');
  final cache = env['XDG_CACHE_HOME'] ?? p.join(home, '.cache');
  return (
    db: p.join(data, 'psito', 'player', 'library.db'),
    covers: p.join(cache, 'psito', 'player', 'covers'),
  );
}

typedef LibraryServicesPaths = ({String db, String covers});

Future<LibraryServices> openLibraryServices() async {
  final paths = libraryPaths(Platform.environment);
  await Directory(p.dirname(paths.db)).create(recursive: true);
  await Directory(paths.covers).create(recursive: true);
  return LibraryServices(
    await IsolateStore.open(paths.db),
    IsolateScanner(dbPath: paths.db, coverDir: paths.covers),
  );
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
    openLibrary: openLibraryServices,
    initialPaths: context.openedPaths,
    musicDir: userMusicDir(Platform.environment),
    pickFolder: (title) => context.pickFolder(title: title),
  );
}
