// system_shell/lib/widgets/battery_indicator.dart
//
// Bateria na top bar, como no macOS: some sem bateria (ex.: na VM), a
// porcentagem é opcional e o clique abre o painel com os detalhes.
import 'package:flutter/material.dart';

import 'package:psito_services/battery_service.dart';

class BatteryIndicator extends StatelessWidget {
  final BatteryState state;
  final bool showPercentage;
  final VoidCallback? onTap;

  const BatteryIndicator({
    super.key,
    required this.state,
    this.showPercentage = true,
    this.onTap,
  });

  static const _low = Color(0xFFF44336);

  /// Ex.: "menos de 1 min", "40 min", "3 h 20 min".
  static String formatDuration(Duration d) {
    if (d.inMinutes < 1) return 'menos de 1 min';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours == 0) return '$minutes min';
    return minutes == 0 ? '$hours h' : '$hours h $minutes min';
  }

  static IconData iconFor(BatteryState s) {
    if (s.charging) return Icons.battery_charging_full;
    final p = s.percentage;
    if (p >= 95) return Icons.battery_full;
    if (p <= 10) return Icons.battery_alert;
    const bars = [
      Icons.battery_1_bar,
      Icons.battery_2_bar,
      Icons.battery_3_bar,
      Icons.battery_4_bar,
      Icons.battery_5_bar,
      Icons.battery_6_bar,
    ];
    // 10–95% dividido em seis faixas
    final index = ((p - 10) / (85 / 6)).floor().clamp(0, 5);
    return bars[index];
  }

  static String statusFor(BatteryState s) {
    if (s.full) return 'Carregada';
    if (s.charging) return 'Carregando';
    return 'Na bateria';
  }

  /// Ex.: "3 h 20 min restantes"; null sem estimativa.
  static String? timeFor(BatteryState s) {
    if (s.full) return null;
    if (s.charging) {
      final t = s.timeToFull;
      return t == null ? null : '${formatDuration(t)} até completar';
    }
    final t = s.timeToEmpty;
    return t == null ? null : '${formatDuration(t)} restantes';
  }

  static bool isLow(BatteryState s) => !s.charging && s.percentage <= 10;

  static String percent(BatteryState s) => '${s.percentage.round()}%';

  @override
  Widget build(BuildContext context) {
    if (!state.available || !state.present) return const SizedBox.shrink();
    final color = isLow(state) ? _low : Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: 'Bateria: ${percent(state)}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('battery-indicator'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: Colors.white12,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconFor(state), size: 16, color: color),
                if (showPercentage) ...[
                  const SizedBox(width: 4),
                  Text(
                    percent(state),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
