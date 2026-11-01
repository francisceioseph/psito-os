// system_shell/lib/widgets/volume_osd.dart
//
// Aviso rápido do volume ao mudar pelo teclado.
import 'package:flutter/material.dart';

import 'package:psito_services/audio_service.dart';

import 'volume_indicator.dart';

import 'package:system_shell/l10n/l10n.dart';

class VolumeOsd extends StatelessWidget {
  final AudioState state;

  const VolumeOsd({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: Material(
        color: const Color(0xEE1E262A),
        borderRadius: BorderRadius.circular(16),
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(VolumeIndicator.iconFor(state), color: Colors.white),
              const SizedBox(width: 14),
              SizedBox(
                width: 160,
                child: LinearProgressIndicator(
                  value: state.muted ? 0 : state.volume,
                  color: accent,
                  backgroundColor: Colors.white12,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 40,
                child: Text(
                  state.muted
                      ? context.l10n.muted
                      : VolumeIndicator.percent(state.volume),
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
