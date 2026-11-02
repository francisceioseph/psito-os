// examples/player/lib/src/ui/pages/home_page.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/library_controller.dart';
import '../../library/models.dart';
import '../../player/playback_controller.dart';
import '../atoms/cover_art.dart';
import '../molecules/track_row.dart';
import '../organisms/album_grid.dart';
import '../organisms/continue_card.dart';
import '../organisms/player_bar.dart';
import '../templates/page_template.dart';

class HomePage extends StatelessWidget {
  final LibraryController library;
  final PlaybackController playback;
  final ValueChanged<Album> onOpenAlbum;
  final VoidCallback onSeeAll;

  const HomePage({
    super.key,
    required this.library,
    required this.playback,
    required this.onOpenAlbum,
    required this.onSeeAll,
  });

  Widget _heading(BuildContext context, String title, {Widget? action}) =>
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ?action,
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PageTemplate(
      title: l.home,
      subtitle: l.homeSubtitle,
      slivers: [
        SliverToBoxAdapter(
          child: ValueListenableBuilder(
            valueListenable: playback.engine.state,
            builder: (context, s, _) => ContinueCard(
              track: playback.resumable ? playback.current : null,
              position: s.position,
              onContinue: () => unawaited(playback.togglePlay()),
              onShuffleAll: () => unawaited(playback.shuffleAll()),
            ),
          ),
        ),
        if (library.recent.isNotEmpty) ...[
          _heading(
            context,
            l.recentlyAdded,
            action: TextButton(onPressed: onSeeAll, child: Text(l.seeAll)),
          ),
          AlbumGrid(
            singleRow: true,
            albums: library.recent,
            onOpen: onOpenAlbum,
            onPlay: (album) => unawaited(playback.playAlbum(album.id)),
          ),
        ],
        if (library.mostPlayed.isNotEmpty) ...[
          _heading(context, l.mostPlayed),
          SliverList.builder(
            itemCount: library.mostPlayed.length,
            itemBuilder: (context, i) {
              final track = library.mostPlayed[i];
              return TrackRow(
                track: track,
                leading: CoverArt(
                  path: track.coverPath,
                  seed: '${track.album}|${track.artist}',
                  size: 40,
                  radius: 8,
                ),
                menu: (context) => trackMenu(context, playback, track),
                onTap: () => unawaited(
                  playback.playTracks(library.mostPlayed, index: i),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
