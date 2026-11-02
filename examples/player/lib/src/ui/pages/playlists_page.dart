// examples/player/lib/src/ui/pages/playlists_page.dart
//
// As playlists: as automáticas primeiro e as da pessoa depois.
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/library_controller.dart';
import '../../library/models.dart';
import '../atoms/empty_note.dart';
import '../molecules/chip_bar.dart';
import '../molecules/sort_menu.dart';
import '../organisms/card_grids.dart';
import '../templates/page_template.dart';

/// As playlists do filtro e da ordem escolhidos.
List<Playlist> visiblePlaylists(LibraryController library) {
  final manual = List.of(library.playlists)
    ..sort(
      library.playlistSortByName
          ? (a, b) => compareFolded(a.name, b.name)
          : (a, b) => b.updatedAt - a.updatedAt,
    );
  return switch (library.playlistFilter) {
    PlaylistFilter.all => [...library.autoPlaylists, ...manual],
    PlaylistFilter.mine => manual,
    PlaylistFilter.automatic => library.autoPlaylists,
  };
}

class PlaylistsPage extends StatelessWidget {
  final LibraryController library;
  final ValueChanged<Playlist> onOpen;
  final VoidCallback onCreate;
  final VoidCallback onImport;

  const PlaylistsPage({
    super.key,
    required this.library,
    required this.onOpen,
    required this.onCreate,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final all = [...library.autoPlaylists, ...library.playlists];
    final tracks = library.playlists.fold(0, (sum, p) => sum + p.trackCount);
    final shown = visiblePlaylists(library);
    return PageTemplate(
      title: l.playlists,
      subtitle: '${l.playlistCount(all.length)} · ${l.trackCount(tracks)}',
      actions: [
        OutlinedButton.icon(
          onPressed: onImport,
          icon: const Icon(Icons.upload_file_rounded),
          label: Text(l.importM3u),
        ),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded),
          label: Text(l.newPlaylist),
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: ChipBar<PlaylistFilter>(
                    options: [
                      (PlaylistFilter.all, l.allSongs),
                      (PlaylistFilter.mine, l.mineFilter),
                      (PlaylistFilter.automatic, l.automaticFilter),
                    ],
                    selected: library.playlistFilter,
                    onSelected: library.setPlaylistFilter,
                  ),
                ),
                SortMenu<bool>(
                  options: [(false, l.sortRecent), (true, l.sortAZ)],
                  selected: library.playlistSortByName,
                  onSelected: library.setPlaylistSortByName,
                ),
              ],
            ),
          ),
        ),
        if (shown.isEmpty)
          SliverToBoxAdapter(child: EmptyNote(l.nothingHere))
        else
          PlaylistGrid(playlists: shown, onOpen: onOpen),
      ],
    );
  }
}
