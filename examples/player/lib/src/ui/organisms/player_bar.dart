// examples/player/lib/src/ui/organisms/player_bar.dart
//
// A barra do player, sempre visível. Na janela larga, em três partes: a faixa, os
// controles com o progresso e a fila com o volume. Na estreita, só o essencial.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../player/engine.dart';
import '../../player/playback_controller.dart';
import '../atoms/favorite_button.dart';
import '../molecules/now_playing_info.dart';
import '../molecules/seek_bar.dart';
import '../molecules/transport_controls.dart';
import '../molecules/volume_control.dart';

class PlayerBar extends StatelessWidget {
  /// A altura com a margem.
  static const height = 96.0;

  /// A partir daqui, a barra inteira.
  static const fullMinWidth = 760.0;

  /// A partir daqui, a capa e a fila entram na barra estreita.
  static const coverMinWidth = 380.0;

  final PlaybackController playback;
  final VoidCallback onToggleQueue;
  final bool queueOpen;

  const PlayerBar({
    super.key,
    required this.playback,
    required this.onToggleQueue,
    this.queueOpen = false,
  });

  void _seek(Duration position) => unawaited(playback.engine.seek(position));

  Widget _queueButton(BuildContext context) => IconButton(
    tooltip: context.l10n.queue,
    isSelected: queueOpen,
    icon: const Icon(Icons.queue_music_rounded),
    onPressed: onToggleQueue,
  );

  /// A faixa, ou o aviso de que deu erro ou não há nenhuma.
  Widget _info(BuildContext context, PlayerState s, double? coverSize) {
    final l = context.l10n;
    final track = playback.current;
    if (s.error != null || track == null) {
      return Text(
        s.error == null ? l.noTrack : l.openFailed,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    return NowPlayingInfo(
      track: track,
      coverSize: coverSize,
      // Fora da biblioteca, quem leu as tags foi o motor
      title: track.id == 0 ? s.title : null,
    );
  }

  Widget? _favorite(PlayerState s) {
    final track = playback.current;
    if (s.error != null || track == null || track.id == 0) return null;
    return FavoriteButton(
      favorite: track.favorite,
      onChanged: (value) => unawaited(playback.setFavorite(track, value)),
    );
  }

  Widget _full(BuildContext context, PlayerState s) => Row(
    children: [
      Expanded(flex: 3, child: _info(context, s, 56)),
      ?_favorite(s),
      const SizedBox(width: 8),
      Expanded(
        flex: 4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TransportControls(playback: playback, state: s),
            SeekBar(position: s.position, duration: s.duration, onSeek: _seek),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 3,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _queueButton(context),
            Flexible(
              child: VolumeControl(
                volume: s.volume,
                onChanged: playback.engine.setVolume,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _narrow(BuildContext context, PlayerState s, double width) {
    final roomy = width >= coverMinWidth;
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(child: _info(context, s, roomy ? 36 : null)),
              SeekBar(
                position: s.position,
                duration: s.duration,
                onSeek: _seek,
              ),
            ],
          ),
        ),
        TransportControls(playback: playback, state: s, compact: true),
        if (roomy) _queueButton(context),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ValueListenableBuilder(
              valueListenable: playback.engine.state,
              builder: (context, s, _) => LayoutBuilder(
                builder: (context, constraints) =>
                    constraints.maxWidth >= fullMinWidth
                    ? _full(context, s)
                    : _narrow(context, s, constraints.maxWidth),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
