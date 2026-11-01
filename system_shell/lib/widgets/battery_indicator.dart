// system_shell/lib/widgets/battery_indicator.dart
//
// Bateria na top bar, como no macOS: some sem bateria (ex.: na VM), a
// porcentagem é opcional e o clique abre o painel com os detalhes.
import 'package:flutter/material.dart';
import 'package:system_shell/l10n/l10n.dart';

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
  static String formatDuration(SystemLocalizations l, Duration d) {
    if (d.inMinutes < 1) return l.durationUnderMinute;
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours == 0) return l.durationMinutes(minutes);
    return minutes == 0
        ? l.durationHours(hours)
        : l.durationHoursMinutes(hours, minutes);
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

  static String statusFor(SystemLocalizations l, BatteryState s) {
    if (s.full) return l.batteryFull;
    if (s.charging) return l.batteryCharging;
    return l.batteryDischarging;
  }

  /// Ex.: "3 h 20 min restantes"; null sem estimativa.
  static String? timeFor(SystemLocalizations l, BatteryState s) {
    if (s.full) return null;
    if (s.charging) {
      final t = s.timeToFull;
      return t == null ? null : l.batteryUntilFull(formatDuration(l, t));
    }
    final t = s.timeToEmpty;
    return t == null ? null : l.batteryRemaining(formatDuration(l, t));
  }

  static bool isLow(BatteryState s) => !s.charging && s.percentage <= 10;

  static String percent(BatteryState s) => '${s.percentage.round()}%';

  @override
  Widget build(BuildContext context) {
    if (!state.available || !state.present) return const SizedBox.shrink();
    final color = isLow(state) ? _low : Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: context.l10n.batteryTooltip(percent(state)),
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
