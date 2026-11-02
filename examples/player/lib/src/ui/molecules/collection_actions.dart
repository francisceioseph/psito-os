// examples/player/lib/src/ui/molecules/collection_actions.dart
//
// Tocar, Aleatório e pôr na fila, de qualquer coleção de faixas.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/models.dart';
import '../../player/playback_controller.dart';

class CollectionActions extends StatelessWidget {
  final PlaybackController playback;
  final List<Track> tracks;

  /// O que vem depois, como o menu de uma playlist.
  final List<Widget> extra;

  const CollectionActions({
    super.key,
    required this.playback,
    required this.tracks,
    this.extra = const [],
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final any = tracks.isNotEmpty;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: any ? () => unawaited(playback.playTracks(tracks)) : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(l.play),
        ),
        FilledButton.tonalIcon(
          onPressed: any
              ? () => unawaited(playback.shuffleTracks(tracks))
              : null,
          icon: const Icon(Icons.shuffle_rounded),
          label: Text(l.shuffle),
        ),
        IconButton.outlined(
          tooltip: l.addToQueue,
          icon: const Icon(Icons.playlist_add_rounded),
          onPressed: any
              ? () => unawaited(playback.tracksToQueue(tracks))
              : null,
        ),
        ...extra,
      ],
    );
  }
}
