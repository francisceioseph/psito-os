// examples/player/lib/src/ui/molecules/album_row.dart
//
// Um álbum na vista em lista.
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/models.dart';
import '../atoms/cover_art.dart';
import '../format.dart';

class AlbumRow extends StatelessWidget {
  static const height = 64.0;

  final Album album;
  final VoidCallback onOpen;
  final VoidCallback onPlay;

  const AlbumRow({
    super.key,
    required this.album,
    required this.onOpen,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final artist = artistName(album.artist, context);
    final facts = [
      artist,
      if (album.year != null) '${album.year}',
      l.trackCount(album.trackCount),
    ].join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onOpen,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              CoverArt(
                path: album.coverPath,
                seed: '${album.title}|${album.artist}',
                size: 48,
                radius: 8,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  button: true,
                  label: '${album.title}, $artist',
                  excludeSemantics: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        facts,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: l.playAlbum(album.title),
                icon: const Icon(Icons.play_arrow_rounded),
                onPressed: onPlay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
