// examples/player/lib/src/ui/organisms/now_playing_panel.dart
//
// O painel Tocando agora: as abas Letra, Capa e Fila em cima e os controles embaixo,
// no lugar da barra do player, que some enquanto ele está aberto.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/library_store.dart';
import '../../lyrics/lyrics_controller.dart';
import '../../player/engine.dart';
import '../../player/playback_controller.dart';
import '../atoms/favorite_button.dart';
import '../format.dart';
import '../molecules/seek_bar.dart';
import '../molecules/transport_controls.dart';
import 'cover_panel.dart';
import 'lyrics_view.dart';
import 'queue_panel.dart';

enum PanelTab { lyrics, cover, queue }

class NowPlayingPanel extends StatelessWidget {
  /// A partir desta altura, os controles inteiros, com a faixa.
  static const fullControlsMinHeight = 520.0;

  /// A partir desta largura, os cinco botões. Abaixo, tocar e a próxima.
  static const fullControlsMinWidth = 280.0;

  /// Abaixo desta largura, as abas só com o ícone.
  static const tabLabelsMinWidth = 300.0;

  final PanelTab tab;
  final PlaybackController playback;
  final LyricsController lyrics;
  final LibraryStore store;
  final ValueChanged<PanelTab> onTab;
  final VoidCallback onClose;
  final ValueChanged<List<String>> onSaveQueue;

  const NowPlayingPanel({
    super.key,
    required this.tab,
    required this.playback,
    required this.lyrics,
    required this.store,
    required this.onTab,
    required this.onClose,
    required this.onSaveQueue,
  });

  Widget _tabs(BuildContext context, double width) {
    final l = context.l10n;
    final labels = width >= tabLabelsMinWidth;
    ButtonSegment<PanelTab> segment(
      PanelTab value,
      String label,
      IconData icon,
    ) => ButtonSegment(
      value: value,
      tooltip: labels ? null : label,
      icon: labels ? null : Icon(icon),
      // O sinal próprio: o do botão não deixa a palavra caber ao lado dele
      label: labels
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value == tab) ...[
                  const Icon(Icons.check_rounded, size: 16),
                  const SizedBox(width: 4),
                ],
                Flexible(child: Text(label, maxLines: 1)),
              ],
            )
          : null,
    );
    return SegmentedButton<PanelTab>(
      segments: [
        segment(PanelTab.lyrics, l.lyricsTab, Icons.lyrics_rounded),
        segment(PanelTab.cover, l.coverTab, Icons.album_rounded),
        segment(PanelTab.queue, l.queue, Icons.queue_music_rounded),
      ],
      selected: {tab},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onTab(selection.first),
    );
  }

  Widget _content(BuildContext context) {
    final track = playback.current;
    return switch (tab) {
      PanelTab.lyrics => LyricsView(controller: lyrics),
      PanelTab.queue => QueuePanel(playback: playback, onSave: onSaveQueue),
      PanelTab.cover =>
        track == null
            ? Center(child: Text(context.l10n.noTrack))
            : CoverPanel(track: track, store: store),
    };
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(child: _tabs(context, constraints.maxWidth)),
                  IconButton(
                    tooltip: context.l10n.close,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Expanded(child: _content(context)),
            _Controls(
              playback: playback,
              withTrack: tab != PanelTab.queue,
              full:
                  constraints.maxHeight >= fullControlsMinHeight &&
                  constraints.maxWidth >= fullControlsMinWidth,
            ),
          ],
        ),
      ),
    ),
  );
}

class _Controls extends StatelessWidget {
  final PlaybackController playback;

  /// Com a faixa e o progresso. A Fila já mostra a faixa, e fica sem eles.
  final bool withTrack;

  /// Com todos os botões. Sem isto, só o progresso, tocar e a próxima.
  final bool full;

  const _Controls({
    required this.playback,
    required this.withTrack,
    required this.full,
  });

  void _seek(Duration position) => unawaited(playback.engine.seek(position));

  Widget _track(BuildContext context, PlayerState s) {
    final theme = Theme.of(context);
    final track = playback.current;
    if (track == null) {
      return Text(context.l10n.noTrack, style: theme.textTheme.bodyMedium);
    }
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.id == 0 ? s.title ?? track.title : track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              Text(
                [
                  artistName(track.artist, context),
                  if (track.album.isNotEmpty) track.album,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (track.id != 0)
          FavoriteButton(
            favorite: track.favorite,
            onChanged: (value) => unawaited(playback.setFavorite(track, value)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: playback.engine.state,
    builder: (context, s, _) {
      final seek = SeekBar(
        position: s.position,
        duration: s.duration,
        onSeek: _seek,
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (full && withTrack) ...[
              _track(context, s),
              const SizedBox(height: 4),
            ],
            if (withTrack || !full) seek,
            if (full) const SizedBox(height: 8),
            Center(
              child: TransportControls(
                playback: playback,
                state: s,
                compact: !full,
                large: full,
                toggles: withTrack,
              ),
            ),
          ],
        ),
      );
    },
  );
}
