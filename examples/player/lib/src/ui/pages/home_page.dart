// examples/player/lib/src/ui/pages/home_page.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/library_controller.dart';
import '../../library/models.dart';
import '../../player/playback_controller.dart';
import '../molecules/section_heading.dart';
import '../organisms/album_grid.dart';
import '../organisms/continue_card.dart';
import '../organisms/track_list.dart';
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
          SliverToBoxAdapter(
            child: SectionHeading(
              l.recentlyAdded,
              action: TextButton(onPressed: onSeeAll, child: Text(l.seeAll)),
            ),
          ),
          AlbumGrid(
            singleRow: true,
            albums: library.recent,
            onOpen: onOpenAlbum,
            onPlay: (album) => unawaited(playback.playAlbum(album.id)),
          ),
        ],
        if (library.mostPlayed.isNotEmpty) ...[
          SliverToBoxAdapter(child: SectionHeading(l.mostPlayed)),
          TrackList(
            tracks: library.mostPlayed,
            library: library,
            playback: playback,
          ),
        ],
      ],
    );
  }
}
