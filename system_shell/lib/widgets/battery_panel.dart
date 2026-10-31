// system_shell/lib/widgets/battery_panel.dart
//
// Painel do ícone de bateria: porcentagem, estado, tempo e fonte de energia.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/battery_service.dart';
import 'battery_indicator.dart';
import 'top_bar.dart';

class BatteryPanel extends StatelessWidget {
  final ValueListenable<BatteryState> state;
  final VoidCallback onClose;

  const BatteryPanel({super.key, required this.state, required this.onClose});

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
              width: 260,
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

  Widget _buildPanel(BuildContext context, BatteryState s) {
    final time = BatteryIndicator.timeFor(s);
    final pluggedIn = s.charging || s.full;
    return Material(
      color: const Color(0xFF1E252B),
      borderRadius: BorderRadius.circular(18),
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Bateria',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  BatteryIndicator.percent(s),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [BatteryIndicator.statusFor(s), ?time].join(' · '),
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
            const Divider(height: 24, color: Colors.white12),
            Row(
              children: [
                Icon(
                  pluggedIn ? Icons.power : Icons.battery_std,
                  size: 16,
                  color: Colors.white54,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fonte de energia: ${pluggedIn ? 'Adaptador' : 'Bateria'}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
