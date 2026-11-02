// examples/player/lib/src/ui/molecules/transport_controls.dart
//
// Os botões de tocar. [compact] deixa só tocar e a próxima, e [large] é o tamanho
// do painel Tocando agora.
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../player/engine.dart';
import '../../player/playback_controller.dart';

class TransportControls extends StatelessWidget {
  final PlaybackController playback;
  final PlayerState state;
  final bool compact;
  final bool large;

  /// Com o aleatório e o repetir.
  final bool toggles;

  const TransportControls({
    super.key,
    required this.playback,
    required this.state,
    this.compact = false,
    this.large = false,
    this.toggles = true,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hasTrack = state.queue.isNotEmpty;
    final play = IconButton.filled(
      tooltip: state.playing ? l.pause : l.play,
      iconSize: large ? 36 : 28,
      style: large
          ? IconButton.styleFrom(fixedSize: const Size.square(64))
          : null,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (toggles) ShuffleToggle(playback: playback, state: state),
        IconButton(
          tooltip: l.previousTrack,
          icon: const Icon(Icons.skip_previous_rounded),
          onPressed: hasTrack ? playback.previous : null,
        ),
        play,
        next,
        if (toggles) RepeatToggle(playback: playback, state: state),
      ],
    );
  }
}

IconButton _toggle({
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

class ShuffleToggle extends StatelessWidget {
  final PlaybackController playback;
  final PlayerState state;

  const ShuffleToggle({super.key, required this.playback, required this.state});

  @override
  Widget build(BuildContext context) => _toggle(
    on: state.shuffle,
    tooltip: context.l10n.shuffle,
    icon: Icons.shuffle_rounded,
    onPressed: playback.toggleShuffle,
  );
}

class RepeatToggle extends StatelessWidget {
  final PlaybackController playback;
  final PlayerState state;

  const RepeatToggle({super.key, required this.playback, required this.state});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _toggle(
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
    );
  }
}
