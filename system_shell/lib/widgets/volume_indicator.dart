// system_shell/lib/widgets/volume_indicator.dart
//
// Ícone de volume da top bar. Clique abre o painel; a roda ajusta.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:system_shell/l10n/l10n.dart';

import 'package:psito_services/audio_service.dart';

class VolumeIndicator extends StatelessWidget {
  final AudioState state;
  final VoidCallback? onTap;

  /// +1 para subir, -1 para descer, um passo por evento da roda.
  final ValueChanged<int>? onScroll;

  const VolumeIndicator({
    super.key,
    required this.state,
    this.onTap,
    this.onScroll,
  });

  static IconData iconFor(AudioState s) {
    if (s.muted) return Icons.volume_off;
    if (s.volume <= 0) return Icons.volume_mute;
    if (s.volume < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  static String percent(double volume) => '${(volume * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    if (!state.available) return const SizedBox.shrink();
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
          onScroll?.call(event.scrollDelta.dy < 0 ? 1 : -1);
        }
      },
      child: Tooltip(
        message: state.muted
            ? context.l10n.volumeMutedTooltip
            : context.l10n.volumeTooltip(percent(state.volume)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('volume-indicator'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            hoverColor: Colors.white12,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(iconFor(state), size: 16, color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}
