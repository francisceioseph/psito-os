// examples/player/lib/src/ui/organisms/queue_panel.dart
//
// A fila, numa lista simples. As abas de Letra e Capa e o arrastar vêm depois.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../player/playback_controller.dart';
import '../atoms/cover_art.dart';
import '../format.dart';
import '../molecules/track_row.dart';

class QueuePanel extends StatelessWidget {
  final PlaybackController playback;
  final VoidCallback onClose;

  const QueuePanel({super.key, required this.playback, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: ValueListenableBuilder(
          valueListenable: playback.engine.state,
          builder: (context, s, _) {
            final queue = playback.queue;
            final total = queue.fold(
              Duration.zero,
              (sum, track) => sum + track.duration,
            );
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.queue, style: theme.textTheme.titleMedium),
                            Text(
                              '${l.trackCount(queue.length)} · '
                              '${formatLength(total, context)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: l.close,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: onClose,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: queue.isEmpty
                      ? Center(child: Text(l.queueEmpty))
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: queue.length,
                          itemBuilder: (context, i) => TrackRow(
                            track: queue[i],
                            current: i == s.index,
                            leading: CoverArt(
                              path: queue[i].coverPath,
                              seed: '${queue[i].album}|${queue[i].artist}',
                              size: 40,
                              radius: 8,
                            ),
                            onTap: () => unawaited(playback.jump(i)),
                            trailing: IconButton(
                              tooltip: l.removeFromQueue,
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: i == s.index
                                  ? null
                                  : () => unawaited(playback.removeAt(i)),
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
