// examples/player/lib/src/ui/pages/library_page.dart
//
// A Biblioteca, com os filtros do esboço: álbuns, artistas, músicas, pastas,
// playlists e gêneros. Durante a leitura pedida pela pessoa, o progresso em cima e
// o que já foi achado, já tocável, embaixo.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/library_controller.dart';
import '../../library/library_search.dart';
import '../../library/models.dart';
import '../../player/playback_controller.dart';
import '../atoms/empty_note.dart';
import '../format.dart';
import '../molecules/chip_bar.dart';
import '../molecules/dir_row.dart';
import '../molecules/search_entry.dart';
import '../molecules/sort_menu.dart';
import '../molecules/track_table_header.dart';
import '../organisms/album_grid.dart';
import '../organisms/card_grids.dart';
import '../organisms/scan_card.dart';
import '../organisms/track_list.dart';
import '../templates/page_template.dart';
import 'playlists_page.dart';

class LibraryPage extends StatelessWidget {
  final LibraryController library;
  final PlaybackController playback;
  final ValueChanged<Object> onOpen;
  final ValueChanged<SearchFilter> onSearch;

  const LibraryPage({
    super.key,
    required this.library,
    required this.playback,
    required this.onOpen,
    required this.onSearch,
  });

  String _title(BuildContext context) =>
      library.section == LibrarySection.tracks
      ? context.l10n.songs
      : context.l10n.library;

  String _subtitle(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context);
    final totals = library.totals;
    if (library.visibleScan != null) return l.scanSubtitle;
    return switch (library.section) {
      LibrarySection.albums =>
        '${l.albumCount(totals.albums)} · ${l.trackCount(totals.tracks)} · '
            '${formatSize(totals.size, locale)}',
      LibrarySection.artists =>
        '${l.artistCount(library.artists.length)} · '
            '${l.albumCount(totals.albums)}',
      LibrarySection.tracks =>
        '${l.trackCount(totals.tracks)} · '
            '${formatLength(totals.duration, context)}',
      LibrarySection.folders =>
        '${l.folderCount(library.dirs.length)} · '
            '${l.trackCount(totals.tracks)}',
      LibrarySection.playlists => l.playlistCount(
        library.playlists.length + library.autoPlaylists.length,
      ),
      LibrarySection.genres =>
        '${l.genreCount(library.genres.length)} · '
            '${l.trackCount(totals.tracks)}',
    };
  }

  (String, SearchFilter) _search(BuildContext context) {
    final l = context.l10n;
    return switch (library.section) {
      LibrarySection.albums => (l.searchAlbumsHint, SearchFilter.albums),
      LibrarySection.artists => (l.searchArtistsHint, SearchFilter.artists),
      LibrarySection.tracks => (l.searchSongsHint, SearchFilter.tracks),
      LibrarySection.folders => (l.searchFoldersHint, SearchFilter.folders),
      LibrarySection.playlists => (l.searchHint, SearchFilter.all),
      LibrarySection.genres => (l.searchGenresHint, SearchFilter.all),
    };
  }

  /// Os filtros da Biblioteca, ou os de Músicas: lá se volta pelo link de cima.
  Widget _chips(BuildContext context) {
    final l = context.l10n;
    if (library.section == LibrarySection.tracks) {
      final query = library.songQuery;
      return ChipBar<String>(
        options: [
          ('', l.allSongs),
          ('*', l.favorites),
          for (final format in library.formats) (format, format),
        ],
        selected: query.favorites ? '*' : (query.format ?? ''),
        onSelected: (value) => library.setSongQuery(
          query.filtered(
            favorites: value == '*',
            format: value.isEmpty || value == '*' ? null : value,
          ),
        ),
      );
    }
    return ChipBar<LibrarySection>(
      options: [
        (LibrarySection.albums, l.albums),
        (LibrarySection.artists, l.artists),
        (LibrarySection.tracks, l.songs),
        (LibrarySection.folders, l.folders),
        (LibrarySection.playlists, l.playlists),
        (LibrarySection.genres, l.genres),
      ],
      selected: library.section,
      onSelected: library.setSection,
    );
  }

  /// O que fica no fim da linha dos filtros.
  Widget? _sort(BuildContext context) {
    final l = context.l10n;
    return switch (library.section) {
      LibrarySection.albums => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SortMenu<AlbumSort>(
            options: [
              (AlbumSort.recent, l.sortRecent),
              (AlbumSort.title, l.sortAZ),
              (AlbumSort.artist, l.sortArtist),
              (AlbumSort.year, l.sortYear),
            ],
            selected: library.albumSort,
            onSelected: (value) => unawaited(library.setAlbumSort(value)),
          ),
          IconButton(
            tooltip: library.albumsAsList ? l.viewGrid : l.viewList,
            icon: Icon(
              library.albumsAsList
                  ? Icons.grid_view_rounded
                  : Icons.view_list_rounded,
            ),
            onPressed: () => library.setAlbumsAsList(!library.albumsAsList),
          ),
        ],
      ),
      LibrarySection.artists => SortMenu<ArtistSort>(
        options: [
          (ArtistSort.name, l.sortAZ),
          (ArtistSort.tracks, l.sortMostTracks),
        ],
        selected: library.artistSort,
        onSelected: library.setArtistSort,
      ),
      LibrarySection.genres => SortMenu<GenreSort>(
        options: [
          (GenreSort.tracks, l.sortMostTracks),
          (GenreSort.name, l.sortAZ),
        ],
        selected: library.genreSort,
        onSelected: library.setGenreSort,
      ),
      _ => null,
    };
  }

  Widget _empty(String text) => SliverToBoxAdapter(child: EmptyNote(text));

  List<Widget> _content(BuildContext context) {
    final l = context.l10n;
    switch (library.section) {
      case LibrarySection.albums:
        void play(Album album) => unawaited(playback.playAlbum(album.id));
        return [
          if (library.albumsAsList)
            AlbumList(albums: library.albums, onOpen: onOpen, onPlay: play)
          else
            AlbumGrid(albums: library.albums, onOpen: onOpen, onPlay: play),
        ];
      case LibrarySection.artists:
        return [ArtistGrid(artists: library.sortedArtists, onOpen: onOpen)];
      case LibrarySection.tracks:
        final query = library.songQuery;
        return [
          SliverToBoxAdapter(
            child: TrackTableHeader(
              query: query,
              onSort: (sort, ascending) =>
                  library.setSongQuery(query.sortedBy(sort, ascending)),
            ),
          ),
          if (library.songs.isEmpty)
            _empty(l.nothingHere)
          else
            TrackList(
              tracks: library.songs,
              library: library,
              playback: playback,
              columns: true,
            ),
        ];
      case LibrarySection.folders:
        return [
          SliverFixedExtentList.builder(
            itemExtent: DirRow.height,
            itemCount: library.dirs.length,
            itemBuilder: (context, i) => DirRow(
              dir: library.dirs[i],
              onOpen: () => onOpen(library.dirs[i]),
            ),
          ),
        ];
      case LibrarySection.playlists:
        return [
          PlaylistGrid(playlists: visiblePlaylists(library), onOpen: onOpen),
        ];
      case LibrarySection.genres:
        return [GenreGrid(genres: library.sortedGenres, onOpen: onOpen)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scan = library.visibleScan;
    final (hint, filter) = _search(context);
    final sort = _sort(context);
    return PageTemplate(
      title: _title(context),
      subtitle: _subtitle(context),
      back: library.section == LibrarySection.tracks
          ? TextButton.icon(
              onPressed: () => library.setSection(LibrarySection.albums),
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(l.library),
            )
          : null,
      actions: [SearchEntry(hint: hint, onTap: () => onSearch(filter))],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(child: _chips(context)),
                ?sort,
              ],
            ),
          ),
        ),
        if (scan != null) ...[
          SliverToBoxAdapter(
            child: ScanCard(
              scan: scan,
              remaining: library.scanRemaining,
              onPause: library.pauseScan,
              onResume: library.resumeScan,
              onCancel: library.cancelScan,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 12),
              child: Text(l.foundSoFar, style: theme.textTheme.titleLarge),
            ),
          ),
        ],
        ..._content(context),
        if (scan != null && library.section == LibrarySection.albums) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          const AlbumGridSkeleton(),
        ],
      ],
    );
  }
}
