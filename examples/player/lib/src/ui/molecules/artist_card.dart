// examples/player/lib/src/ui/molecules/artist_card.dart
//
// Um artista numa grade: o monograma, o nome e o que há dele.
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/models.dart';
import '../atoms/monogram.dart';
import '../format.dart';

class ArtistCard extends StatelessWidget {
  final Artist artist;
  final VoidCallback onOpen;

  const ArtistCard({super.key, required this.artist, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final name = artistName(artist.name, context);
    return Semantics(
      button: true,
      label: name,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(aspectRatio: 1, child: Monogram(name: name)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
            Text(
              '${l.albumCount(artist.albums)} · ${l.trackCount(artist.tracks)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
