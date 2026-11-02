// examples/player/lib/src/ui/molecules/now_playing_info.dart
//
// A faixa: capa, título e artista.
import 'package:flutter/material.dart';

import '../../library/models.dart';
import '../atoms/cover_art.dart';
import '../format.dart';

class NowPlayingInfo extends StatelessWidget {
  final Track track;

  /// O lado da capa, ou null sem capa.
  final double? coverSize;

  /// Substitui o título, como numa faixa fora da biblioteca.
  final String? title;

  const NowPlayingInfo({
    super.key,
    required this.track,
    this.coverSize = 56,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (coverSize != null) ...[
          CoverArt(
            path: track.coverPath,
            seed: '${track.album}|${track.artist}',
            size: coverSize,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title ?? track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              Text(
                artistName(track.artist, context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
