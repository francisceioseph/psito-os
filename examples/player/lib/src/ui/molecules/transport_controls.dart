// examples/player/lib/src/ui/molecules/transport_controls.dart
//
// Os botões de tocar. [compact] deixa só tocar e a próxima.
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../player/engine.dart';
import '../../player/playback_controller.dart';

class TransportControls extends StatelessWidget {
  final PlaybackController playback;
  final PlayerState state;
  final bool compact;

  const TransportControls({
    super.key,
    required this.playback,
    required this.state,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hasTrack = state.queue.isNotEmpty;
    final play = IconButton.filled(
      tooltip: state.playing ? l.pause : l.play,
      iconSize: 28,
      icon: Icon(
        state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
      ),
      onPressed: hasTrack ? playback.togglePlay : null,
    );
    final next = IconButton(
      tooltip: l.nextTrack,
      icon: const Icon(Icons.skip_next_rounded),
      onPressed: hasTrack ? playback.next : null,
    );
    if (compact) {
      return Row(mainAxisSize: MainAxisSize.min, children: [play, next]);
    }
    IconButton toggle({
      required bool on,
      required String tooltip,
      required IconData icon,
      required VoidCallback onPressed,
    }) => on
        ? IconButton.filledTonal(
            tooltip: tooltip,
            isSelected: true,
            icon: Icon(icon),
            onPressed: onPressed,
          )
        : IconButton(
            tooltip: tooltip,
            isSelected: false,
            icon: Icon(icon),
            onPressed: onPressed,
          );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        toggle(
          on: state.shuffle,
          tooltip: l.shuffle,
          icon: Icons.shuffle_rounded,
          onPressed: playback.toggleShuffle,
        ),
        IconButton(
          tooltip: l.previousTrack,
          icon: const Icon(Icons.skip_previous_rounded),
          onPressed: hasTrack ? playback.previous : null,
        ),
        play,
        next,
        toggle(
          on: state.repeat != PlayerRepeat.off,
          tooltip: switch (state.repeat) {
            PlayerRepeat.off => l.repeatOff,
            PlayerRepeat.all => l.repeatAll,
            PlayerRepeat.one => l.repeatOne,
          },
          icon: state.repeat == PlayerRepeat.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          onPressed: playback.cycleRepeat,
        ),
      ],
    );
  }
}
