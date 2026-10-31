// system_shell/lib/widgets/volume_panel.dart
//
// Painel do ícone de volume: mudo e slider.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/audio_service.dart';
import 'top_bar.dart';
import 'volume_indicator.dart';

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
                builder: (context, s, _) => _buildPanel(s),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel(AudioState s) {
    return Material(
      color: const Color(0xFF1E252B),
      borderRadius: BorderRadius.circular(18),
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
        child: Row(
          children: [
            IconButton(
              tooltip: s.muted ? 'Ativar som' : 'Silenciar',
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
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
