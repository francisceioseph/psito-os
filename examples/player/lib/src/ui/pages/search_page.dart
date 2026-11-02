// examples/player/lib/src/ui/pages/search_page.dart
//
// A busca, agrupada: o melhor resultado e as músicas lado a lado, depois os álbuns e
// as pastas. Cada filtro mostra só o seu grupo, inteiro.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../../library/library_controller.dart';
import '../../library/library_search.dart';
import '../../library/models.dart';
import '../../player/playback_controller.dart';
import '../atoms/empty_note.dart';
import '../molecules/album_card.dart';
import '../molecules/chip_bar.dart';
import '../molecules/dir_row.dart';
import '../molecules/section_heading.dart';
import '../molecules/track_menu.dart';
import '../molecules/track_row.dart';
import '../atoms/cover_art.dart';
import '../organisms/album_grid.dart';
import '../organisms/best_result_card.dart';
import '../organisms/card_grids.dart';
import '../organisms/track_list.dart';

class SearchPage extends StatefulWidget {
  /// A partir daqui, as colunas do "Tudo". Abaixo, uma coisa depois da outra.
  static const sideBySideMinWidth = 720.0;
  static const bestWidth = 280.0;
  static const songsInAll = 4;
  static const foldersInAll = 3;
  static const albumMinWidth = 130.0;

  final LibrarySearch search;
  final LibraryController library;
  final PlaybackController playback;
  final FocusNode focusNode;
  final ValueChanged<Object> onOpen;

  const SearchPage({
    super.key,
    required this.search,
    required this.library,
    required this.playback,
    required this.focusNode,
    required this.onOpen,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final _text = TextEditingController(text: widget.search.query);

  @override
  void didUpdateWidget(SearchPage old) {
    super.didUpdateWidget(old);
    if (_revision != widget.library.revision) {
      _revision = widget.library.revision;
      unawaited(widget.search.refresh());
    }
  }

  late int _revision = widget.library.revision;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _clear() {
    _text.clear();
    widget.search.setQuery('');
    widget.focusNode.requestFocus();
  }

  Future<void> _playBest(Object best, SearchResults results) async {
    final playback = widget.playback;
    switch (best) {
      case final Artist artist:
        await playback.playTracks(
          await widget.library.store.tracks(TrackQuery(artistId: artist.id)),
        );
      case final Album album:
        await playback.playAlbum(album.id);
      case final Track track:
        await playback.playTracks(
          results.tracks,
          index: results.tracks.indexOf(track),
        );
    }
  }

  void _openBest(Object best, SearchResults results) {
    if (best is Track) {
      unawaited(_playBest(best, results));
    } else {
      widget.onOpen(best);
    }
  }

  Widget _field(BuildContext context) {
    final l = context.l10n;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            _text.text.isNotEmpty) {
          _clear();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ListenableBuilder(
        listenable: _text,
        builder: (context, _) => SearchBar(
          controller: _text,
          focusNode: widget.focusNode,
          autoFocus: true,
          hintText: l.searchAllHint,
          elevation: const WidgetStatePropertyAll(0),
          leading: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.search_rounded),
          ),
          trailing: [
            if (_text.text.isNotEmpty)
              IconButton(
                tooltip: l.clearSearch,
                icon: const Icon(Icons.close_rounded),
                onPressed: _clear,
              ),
          ],
          onChanged: widget.search.setQuery,
        ),
      ),
    );
  }

  /// As linhas das músicas fora de um sliver, para ficarem ao lado do melhor
  /// resultado.
  Widget _songs(BuildContext context, List<Track> tracks, SearchResults all) {
    final library = widget.library;
    final playback = widget.playback;
    final current = playback.current?.path;
    return Column(
      children: [
        for (final track in tracks)
          TrackRow(
            track: track,
            current: track.path == current,
            missing: library.isMissing(track.path),
            leading: CoverArt(
              path: track.coverPath,
              seed: '${track.album}|${track.artist}',
              size: 40,
              radius: 8,
            ),
            menu: (context) => trackMenu(context, library, playback, track),
            onTap: () => unawaited(
              playback.playTracks(all.tracks, index: all.tracks.indexOf(track)),
            ),
          ),
      ],
    );
  }

  Widget _albums(BuildContext context, List<Album> albums, double width) {
    final count = max(
      1,
      (width / SearchPage.albumMinWidth).floor(),
    ).clamp(1, albums.length);
    final side = (width - 12 * (count - 1)) / count;
    return Row(
      spacing: 12,
      children: [
        for (final album in albums.take(count))
          SizedBox(
            width: side,
            height: side + AlbumCard.textHeight,
            child: AlbumCard(
              key: ValueKey(album.id),
              album: album,
              onOpen: () => widget.onOpen(album),
              onPlay: () => unawaited(widget.playback.playAlbum(album.id)),
            ),
          ),
      ],
    );
  }

  Widget _dirs(List<MusicDir> dirs) => Column(
    children: [
      for (final dir in dirs.take(SearchPage.foldersInAll))
        DirRow(dir: dir, onOpen: () => widget.onOpen(dir)),
    ],
  );

  Widget _all(BuildContext context, SearchResults results, double width) {
    final l = context.l10n;
    final best = results.best;
    final wide = width >= SearchPage.sideBySideMinWidth;
    final tracks = results.tracks.take(SearchPage.songsInAll).toList();
    final bestCard = best == null
        ? null
        : BestResultCard(
            result: best,
            onOpen: () => _openBest(best, results),
            onPlay: () => unawaited(_playBest(best, results)),
          );
    final songs = tracks.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(l.songs),
              _songs(context, tracks, results),
            ],
          );
    final albumsWidth = wide && results.dirs.isNotEmpty ? width * 0.6 : width;
    final albums = results.albums.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(l.albums),
              _albums(context, results.albums, albumsWidth),
            ],
          );
    final dirs = results.dirs.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [SectionHeading(l.folders), _dirs(results.dirs)],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wide && bestCard != null && songs != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: SearchPage.bestWidth, child: bestCard),
              const SizedBox(width: 24),
              Expanded(child: songs),
            ],
          )
        else ...[
          ?bestCard,
          ?songs,
        ],
        if (wide && albums != null && dirs != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: albumsWidth, child: albums),
              const SizedBox(width: 24),
              Expanded(child: dirs),
            ],
          )
        else ...[
          ?albums,
          ?dirs,
        ],
      ],
    );
  }

  List<Widget> _results(BuildContext context, SearchResults results) {
    final l = context.l10n;
    final search = widget.search;
    if (search.query.trim().isEmpty) {
      return [SliverToBoxAdapter(child: EmptyNote(l.searchPrompt))];
    }
    if (results.isEmpty) {
      return [
        SliverToBoxAdapter(child: EmptyNote(l.noResults(search.query.trim()))),
      ];
    }
    Widget nothing() => SliverToBoxAdapter(child: EmptyNote(l.nothingHere));
    return switch (search.filter) {
      SearchFilter.all => [
        SliverToBoxAdapter(
          child: LayoutBuilder(
            builder: (context, constraints) =>
                _all(context, results, constraints.maxWidth),
          ),
        ),
      ],
      SearchFilter.tracks => [
        if (results.tracks.isEmpty)
          nothing()
        else
          TrackList(
            tracks: results.tracks,
            library: widget.library,
            playback: widget.playback,
            columns: true,
          ),
      ],
      SearchFilter.albums => [
        if (results.albums.isEmpty)
          nothing()
        else
          AlbumGrid(
            albums: results.albums,
            onOpen: widget.onOpen,
            onPlay: (album) => unawaited(widget.playback.playAlbum(album.id)),
          ),
      ],
      SearchFilter.artists => [
        if (results.artists.isEmpty)
          nothing()
        else
          ArtistGrid(artists: results.artists, onOpen: widget.onOpen),
      ],
      SearchFilter.folders => [
        if (results.dirs.isEmpty)
          nothing()
        else
          SliverFixedExtentList.builder(
            itemExtent: DirRow.height,
            itemCount: results.dirs.length,
            itemBuilder: (context, i) => DirRow(
              dir: results.dirs[i],
              onOpen: () => widget.onOpen(results.dirs[i]),
            ),
          ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final search = widget.search;
    return ListenableBuilder(
      listenable: search,
      builder: (context, _) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field(context),
                  const SizedBox(height: 12),
                  ChipBar<SearchFilter>(
                    options: [
                      (SearchFilter.all, l.allFilter),
                      (SearchFilter.tracks, l.songs),
                      (SearchFilter.albums, l.albums),
                      (SearchFilter.artists, l.artists),
                      (SearchFilter.folders, l.folders),
                    ],
                    selected: search.filter,
                    onSelected: search.setFilter,
                  ),
                ],
              ),
            ),
          ),
          for (final sliver in _results(context, search.results))
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: sliver,
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}
