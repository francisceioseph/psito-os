// examples/player/lib/src/ui/organisms/best_result_card.dart
//
// O melhor resultado da busca, que pode ser um artista, um álbum ou uma música.
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/models.dart';
import '../atoms/cover_art.dart';
import '../atoms/monogram.dart';
import '../format.dart';

class BestResultCard extends StatelessWidget {
  final Object result;
  final VoidCallback onOpen;
  final VoidCallback onPlay;

  const BestResultCard({
    super.key,
    required this.result,
    required this.onOpen,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (art, name, facts) = switch (result) {
      final Artist artist => (
        Monogram(name: artistName(artist.name, context), size: 72),
        artistName(artist.name, context),
        '${l.kindArtist} · ${l.albumCount(artist.albums)} · '
            '${l.trackCount(artist.tracks)}',
      ),
      final Album album => (
        CoverArt(
          path: album.coverPath,
          seed: '${album.title}|${album.artist}',
          size: 72,
        ),
        album.title,
        '${l.kindAlbum} · ${artistName(album.artist, context)}',
      ),
      final Track track => (
        CoverArt(
          path: track.coverPath,
          seed: '${track.album}|${track.artist}',
          size: 72,
        ),
        track.title,
        '${l.kindSong} · ${artistName(track.artist, context)}',
      ),
      _ => throw ArgumentError.value(result),
    };
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.bestResult.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: '$name, $facts',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    art,
                    const SizedBox(height: 12),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      facts,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l.playAll),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
