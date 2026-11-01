// system_shell/lib/widgets/volume_panel.dart
//
// Painel do ícone de volume: mudo e slider.
import 'package:psito_sdk/psito_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:psito_services/audio_service.dart';

import 'top_bar.dart';
import 'volume_indicator.dart';

import 'package:system_shell/l10n/l10n.dart';

class VolumePanel extends StatelessWidget {
  final ValueListenable<AudioState> state;
  final ValueChanged<double> onVolume;
  final ValueChanged<bool> onMuted;
  final VoidCallback onClose;

  const VolumePanel({
    super.key,
    required this.state,
    required this.onVolume,
    required this.onMuted,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose},
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            // Clicar fora fecha; a top bar fica de fora para trocar de painel
            Positioned.fill(
              top: TopBar.height,
              child: GestureDetector(
                excludeFromSemantics: true,
                onTap: onClose,
                behavior: HitTestBehavior.opaque,
              ),
            ),
            Positioned(
              top: 48,
              right: 12,
              width: 300,
              child: ValueListenableBuilder(
                valueListenable: state,
                builder: (context, s, _) => _buildPanel(context, s),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context, AudioState s) {
    return Material(
      color: context.palette.panel,
      borderRadius: BorderRadius.circular(18),
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
        child: Row(
          children: [
            IconButton(
              tooltip: s.muted ? context.l10n.unmute : context.l10n.mute,
              icon: Icon(VolumeIndicator.iconFor(s)),
              onPressed: () => onMuted(!s.muted),
            ),
            Expanded(
              child: Slider(value: s.volume, onChanged: onVolume),
            ),
            SizedBox(
              width: 40,
              child: Text(
                VolumeIndicator.percent(s.volume),
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 12,
                  color: context.palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
