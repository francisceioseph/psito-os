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
import 'src/library/folder_watcher.dart';
import 'src/library/library_controller.dart';
import 'src/library/library_search.dart';
import 'src/library/library_store.dart';
import 'src/library/models.dart';
import 'src/library/scanner.dart';
import 'src/lyrics/lyrics_controller.dart';
import 'src/lyrics/lyrics_loader.dart';
import 'src/player/engine.dart';
import 'src/player/media_kit_engine.dart';
import 'src/player/playback_controller.dart';
import 'src/player/player_shortcuts.dart';
import 'src/ui/atoms/generic_art.dart';
import 'src/ui/atoms/monogram.dart';
import 'src/ui/format.dart';
import 'src/ui/molecules/track_menu.dart';
import 'src/ui/organisms/navigation.dart';
import 'src/ui/organisms/now_playing_panel.dart';
import 'src/ui/organisms/player_bar.dart';
import 'src/ui/pages/album_page.dart';
import 'src/ui/pages/empty_library_page.dart';
import 'src/ui/pages/folders_page.dart';
import 'src/ui/pages/home_page.dart';
import 'src/ui/pages/library_page.dart';
import 'src/ui/pages/playlist_page.dart';
import 'src/ui/pages/playlists_page.dart';
import 'src/ui/pages/search_page.dart';
import 'src/ui/pages/soon_page.dart';
import 'src/ui/pages/tracks_page.dart';
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
  final FolderWatcher? watcher;

  const LibraryServices(this.store, this.scanner, {this.watcher});
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

  /// O seletor de um arquivo M3U.
  final Future<String?> Function(String title) pickPlaylistFile;

  /// O seletor de onde gravar um arquivo, com o nome sugerido.
  final Future<String?> Function(String title, String suggestedName)
  pickSaveFile;

  /// A pasta de música da pessoa, se existe.
  final String? musicDir;

  /// Acha a letra de um arquivo.
  final LyricsLoader readLyrics;

  const PlayerView({
    super.key,
    required this.createEngine,
    required this.openLibrary,
    required this.pickFolder,
    required this.pickPlaylistFile,
    required this.pickSaveFile,
    this.initialPaths = const [],
    this.musicDir,
    this.readLyrics = loadLyrics,
  });

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  PlayerEngine? _engine;
  LibraryStore? _store;
  LibraryController? _library;
  PlaybackController? _playback;
  LibrarySearch? _search;
  LyricsController? _lyrics;
  final _searchFocus = FocusNode();

  /// O erro de abrir o motor ou a biblioteca.
  String? _engineError;
  String? _libraryError;

  PlayerDestination _destination = PlayerDestination.home;

  /// O que foi aberto a partir do destino: um álbum, um artista, um gênero, uma
  /// pasta ou uma playlist, com o que estava atrás.
  final _stack = <Object>[];

  /// A aba do painel Tocando agora, ou null fechado.
  PanelTab? _panel;
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
    unawaited(_openLibrary());
  }

  Future<void> _openLibrary() async {
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
      watcher: services.watcher,
    );
    final playback = PlaybackController(
      engine: _engine!,
      store: services.store,
      onLibraryChanged: () => unawaited(library.reload()),
      isAvailable: (path) => !library.isMissing(path),
      onNothingAvailable: () => _snack(context.l10n.nothingAvailable),
    );
    setState(() {
      _library = library;
      _playback = playback;
      _search = LibrarySearch(services.store);
      _lyrics = LyricsController(
        playback: playback,
        store: services.store,
        load: widget.readLyrics,
      );
    });
    await library.reload();
    if (!mounted) return;
    await playback.restore(open: widget.initialPaths);
    if (!mounted) return;
    await library.checkFolders();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    final playback = _playback;
    final store = _store;
    final engine = _engine;
    _lifecycle.dispose();
    _lyrics?.dispose();
    _library?.dispose();
    _search?.dispose();
    _searchFocus.dispose();
    unawaited(() async {
      await playback?.saveSession();
      playback?.dispose();
      await store?.close();
      await engine?.dispose();
    }());
    super.dispose();
  }

  void _navigate(PlayerDestination destination) {
    // Sem largura para os dois, o painel esconderia o destino
    final covers =
        MediaQuery.sizeOf(context).width < ShellTemplate.panelSideMinWidth;
    setState(() {
      _destination = destination;
      _stack.clear();
    });
    if (covers) _setPanel(null);
  }

  void _setPanel(PanelTab? tab) {
    _lyrics?.active = tab == PanelTab.lyrics;
    setState(() => _panel = tab);
  }

  /// O atalho de uma aba: abre nela e, se já está nela, fecha.
  void _togglePanel(PanelTab tab) => _setPanel(_panel == tab ? null : tab);

  Future<void> _saveQueue(List<String> paths) async {
    final l = context.l10n;
    final name = await askPlaylistName(
      context,
      title: l.saveAsPlaylist,
      action: l.create,
    );
    if (name == null || !mounted) return;
    await _library!.createPlaylist(name, paths);
    if (mounted) _snack(context.l10n.playlistSaved(name));
  }

  void _open(Object item) => setState(() => _stack.add(item));

  void _back() => setState(() => _stack.removeLast());

  void _openSearch([SearchFilter? filter]) {
    if (filter != null) _search?.setFilter(filter);
    _navigate(PlayerDestination.search);
    _searchFocus.requestFocus();
  }

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

  Future<void> _createPlaylist() async {
    final l = context.l10n;
    final name = await askPlaylistName(
      context,
      title: l.newPlaylist,
      action: l.create,
    );
    if (name != null) await _library!.createPlaylist(name);
  }

  Future<void> _importPlaylist() async {
    final l = context.l10n;
    final path = await widget.pickPlaylistFile(l.importM3u);
    if (path == null || !mounted) return;
    try {
      final result = await _library!.importM3u(path);
      _snack(
        result.remote == 0
            ? l.imported(result.tracks)
            : '${l.imported(result.tracks)} · ${l.importedRemote(result.remote)}',
      );
    } on FileSystemException catch (e) {
      _snack(l.importFailed(e.osError?.message ?? e.message));
    }
  }

  Future<void> _exportPlaylist(String name, List<Track> tracks) async {
    final l = context.l10n;
    final path = await widget.pickSaveFile(l.exportM3u, '$name.m3u8');
    if (path == null || !mounted) return;
    try {
      await _library!.exportM3u(tracks, path);
    } on FileSystemException catch (e) {
      _snack(l.exportFailed(e.osError?.message ?? e.message));
    }
  }

  /// O que está aberto em cima do destino.
  Widget? _opened(LibraryController library, PlaybackController playback) {
    if (_stack.isEmpty) return null;
    final item = _stack.last;
    Widget tracks(String key, String title, Widget art, TrackQuery query) =>
        TracksPage(
          key: ValueKey(key),
          title: title,
          art: art,
          query: query,
          library: library,
          playback: playback,
          onBack: _back,
          onOpenAlbum: _open,
        );
    return switch (item) {
      final Album album => AlbumPage(
        key: ValueKey('album ${album.id}'),
        album: album,
        library: library,
        playback: playback,
        onBack: _back,
      ),
      final Artist artist => tracks(
        'artist ${artist.id}',
        artistName(artist.name, context),
        Monogram(name: artistName(artist.name, context)),
        TrackQuery(artistId: artist.id),
      ),
      final Genre genre => tracks(
        'genre ${genre.name}',
        genreName(genre.name, context),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GenericArt(seed: genreName(genre.name, context)),
        ),
        TrackQuery(genre: genre.name, sort: TrackSort.artist),
      ),
      final MusicDir dir => tracks(
        'dir ${dir.path}',
        prettyPath(dir.path, Platform.environment['HOME']),
        Icon(
          Icons.folder_rounded,
          size: 96,
          color: Theme.of(context).colorScheme.primary,
        ),
        TrackQuery(dir: dir.path, sort: TrackSort.album),
      ),
      final Playlist playlist => PlaylistPage(
        key: ValueKey('playlist ${playlist.kind.name} ${playlist.id}'),
        playlist: playlist,
        library: library,
        playback: playback,
        onBack: _back,
        onExport: _exportPlaylist,
      ),
      _ => throw ArgumentError.value(item),
    };
  }

  Widget _page(LibraryController library, PlaybackController playback) {
    final l = context.l10n;
    final opened = _opened(library, playback);
    if (opened != null) return opened;
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
        onOpenAlbum: _open,
        onSeeAll: () => _navigate(PlayerDestination.library),
      ),
      PlayerDestination.library => LibraryPage(
        library: library,
        playback: playback,
        onOpen: _open,
        onSearch: _openSearch,
      ),
      PlayerDestination.folders => FoldersPage(
        library: library,
        onAddFolder: () => unawaited(_pickFolder()),
      ),
      PlayerDestination.playlists => PlaylistsPage(
        library: library,
        onOpen: _open,
        onCreate: () => unawaited(_createPlaylist()),
        onImport: () => unawaited(_importPlaylist()),
      ),
      PlayerDestination.search => SearchPage(
        search: _search!,
        library: library,
        playback: playback,
        focusNode: _searchFocus,
        onOpen: _open,
      ),
      PlayerDestination.settings => SoonPage(title: l.settings),
    };
  }

  Widget _shell(LibraryController library, PlaybackController playback) =>
      ListenableBuilder(
        listenable: Listenable.merge([library, playback]),
        builder: (context, _) => Focus(
          autofocus: true,
          onKeyEvent: (_, event) => handlePlayerKey(
            event,
            playback,
            onSearch: _openSearch,
            onLyrics: () => _togglePanel(PanelTab.lyrics),
            onQueue: () => _togglePanel(PanelTab.queue),
          ),
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
            panel: _panel == null
                ? null
                : NowPlayingPanel(
                    tab: _panel!,
                    playback: playback,
                    lyrics: _lyrics!,
                    store: _store!,
                    onTab: _setPanel,
                    onClose: () => _setPanel(null),
                    onSaveQueue: (paths) => unawaited(_saveQueue(paths)),
                  ),
            bar: PlayerBar(
              playback: playback,
              canOpenPanel:
                  MediaQuery.sizeOf(context).height >=
                  ShellTemplate.contentMinHeight,
              onOpenPanel: _setPanel,
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
    watcher: DirectoryWatcher(),
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
    pickPlaylistFile: (title) =>
        context.pickFile(title: title, patterns: const ['*.m3u', '*.m3u8']),
    pickSaveFile: (title, name) =>
        context.pickSaveFile(title: title, suggestedName: name),
  );
}
