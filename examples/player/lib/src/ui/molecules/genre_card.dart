// examples/player/lib/src/ui/molecules/genre_card.dart
//
// Um gênero: a arte que nasce do nome, o nome e o número de músicas.
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/models.dart';
import '../atoms/generic_art.dart';
import '../format.dart';

class GenreCard extends StatelessWidget {
  final Genre genre;
  final VoidCallback onOpen;

  const GenreCard({super.key, required this.genre, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final name = genreName(genre.name, context);
    return Semantics(
      button: true,
      label: name,
      excludeSemantics: true,
      child: Material(
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GenericArt(seed: name),
            // Um véu do tema, para o texto se ler sobre qualquer arte
            ColoredBox(
              color: theme.colorScheme.surface.withValues(alpha: 0.45),
            ),
            InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      l.trackCount(genre.tracks),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
