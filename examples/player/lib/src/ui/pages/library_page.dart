// examples/player/lib/src/ui/pages/library_page.dart
//
// A grade de álbuns. Durante a leitura, o progresso em cima e o que já foi achado,
// já tocável, embaixo.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/library_controller.dart';
import '../../library/models.dart';
import '../../player/playback_controller.dart';
import '../format.dart';
import '../organisms/album_grid.dart';
import '../organisms/scan_card.dart';
import '../templates/page_template.dart';

class LibraryPage extends StatelessWidget {
  final LibraryController library;
  final PlaybackController playback;
  final ValueChanged<Album> onOpenAlbum;

  const LibraryPage({
    super.key,
    required this.library,
    required this.playback,
    required this.onOpenAlbum,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final totals = library.totals;
    final scan = library.scan;
    return PageTemplate(
      title: l.library,
      subtitle: scan != null
          ? l.scanSubtitle
          : '${l.albumCount(totals.albums)} · '
                '${l.trackCount(totals.tracks)} · '
                '${formatSize(totals.size, locale)}',
      slivers: [
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
        ] else
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        AlbumGrid(
          albums: library.albums,
          onOpen: onOpenAlbum,
          onPlay: (album) => unawaited(playback.playAlbum(album.id)),
        ),
        if (scan != null) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          const AlbumGridSkeleton(),
        ],
      ],
    );
  }
}
