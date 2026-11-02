// examples/player/lib/src/ui/organisms/queue_panel.dart
//
// A aba Fila: a faixa atual, que fica parada no topo, e o que vem depois, para
// arrastar e tirar.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/models.dart';
import '../../player/engine.dart';
import '../../player/playback_controller.dart';
import '../atoms/cover_art.dart';
import '../format.dart';
import '../molecules/track_row.dart';
import '../molecules/transport_controls.dart';

class QueuePanel extends StatelessWidget {
  /// A coluna do arrastar.
  static const _handleWidth = 32.0;

  /// Abaixo desta altura, salvar sai, para a lista caber.
  static const footerMinHeight = 150.0;

  final PlaybackController playback;

  /// Salva como playlist o que está na lista.
  final ValueChanged<List<String>> onSave;

  const QueuePanel({super.key, required this.playback, required this.onSave});

  Widget _art(Track track) => CoverArt(
    path: track.coverPath,
    seed: '${track.album}|${track.artist}',
    size: 40,
    radius: 8,
  );

  Widget _current(Track track, BuildContext context) => Row(
    children: [
      const SizedBox(width: _handleWidth),
      Expanded(
        child: TrackRow(
          track: track,
          current: true,
          showDuration: true,
          leading: Icon(
            Icons.equalizer_rounded,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          onTap: () {},
        ),
      ),
    ],
  );

  Widget _header(BuildContext context, PlayerState s, List<Track> shown) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final total = shown.fold(
      Duration.zero,
      (sum, track) => sum + track.duration,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${l.upNext} · ${l.trackCount(shown.length)} · '
                      '${formatLength(total, context)}'
                  .toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ),
          TextButton(
            onPressed: s.index + 1 < s.queue.length
                ? () => unawaited(playback.clearUpcoming())
                : null,
            child: Text(l.clearQueue),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, PlayerState s, List<Track> shown) {
    final l = context.l10n;
    final first = s.index + 1;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          sliver: SliverToBoxAdapter(child: _current(shown.first, context)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          sliver: SliverReorderableList(
            itemExtent: TrackRow.height,
            itemCount: shown.length - 1,
            onReorderItem: (from, to) =>
                unawaited(playback.moveInQueue(first + from, first + to)),
            itemBuilder: (context, i) {
              final track = shown[i + 1];
              return Row(
                // A mesma faixa pode entrar duas vezes
                key: ValueKey('$i ${track.path}'),
                children: [
                  ReorderableDragStartListener(
                    index: i,
                    child: Tooltip(
                      message: l.dragToReorder,
                      child: const SizedBox(
                        width: _handleWidth,
                        height: TrackRow.height,
                        child: Icon(Icons.drag_indicator_rounded, size: 20),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TrackRow(
                      track: track,
                      showDuration: true,
                      leading: _art(track),
                      onTap: () => unawaited(playback.jump(first + i)),
                      trailing: IconButton(
                        tooltip: l.removeFromQueue,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () =>
                            unawaited(playback.removeAt(first + i)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _footer(BuildContext context, PlayerState s, List<Track> shown) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.playlist_add_rounded),
                label: Text(
                  context.l10n.saveAsPlaylist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => onSave([for (final t in shown) t.path]),
              ),
            ),
            ShuffleToggle(playback: playback, state: s),
            RepeatToggle(playback: playback, state: s),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: playback.engine.state,
    builder: (context, s, _) {
      final queue = playback.queue;
      final shown = s.index < 0 ? const <Track>[] : queue.sublist(s.index);
      if (shown.isEmpty) return Center(child: Text(context.l10n.queueEmpty));
      return LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            _header(context, s, shown),
            Expanded(child: _list(context, s, shown)),
            if (constraints.maxHeight >= footerMinHeight)
              _footer(context, s, shown),
          ],
        ),
      );
    },
  );
}
