import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

import '../services/audio_service.dart';
import '../services/battery_service.dart';
import 'battery_indicator.dart';
import 'network_indicator.dart';
import 'volume_indicator.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  /// Botão do Menu Psito: abre e fecha o launcher.
  final VoidCallback? onMenuTap;

  /// Sino e relógio: abrem e fecham o painel de notificações.
  final VoidCallback? onNotificationsTap;
  final int unreadCount;

  /// Formato do relógio e "Não perturbe", das Configurações.
  final bool use24h;
  final bool showSeconds;
  final bool doNotDisturb;

  final PsitoNetworkState network;

  /// Ícone de rede: abre e fecha o painel de rede.
  final VoidCallback? onNetworkTap;

  final AudioState audio;

  /// Ícone de volume: abre e fecha o painel de volume.
  final VoidCallback? onVolumeTap;

  /// Roda do mouse sobre o ícone de volume: +1 sobe, -1 desce.
  final ValueChanged<int>? onVolumeScroll;

  final BatteryState battery;
  final bool showBatteryPercentage;

  /// Ícone de bateria: abre e fecha o painel da bateria.
  final VoidCallback? onBatteryTap;

  /// Botão de energia: abre e fecha o menu de energia.
  final VoidCallback? onPowerTap;

  const TopBar({
    super.key,
    this.onMenuTap,
    this.onNotificationsTap,
    this.unreadCount = 0,
    this.use24h = true,
    this.showSeconds = false,
    this.doNotDisturb = false,
    this.network = PsitoNetworkState.unavailable,
    this.onNetworkTap,
    this.audio = AudioState.unavailable,
    this.onVolumeTap,
    this.onVolumeScroll,
    this.battery = BatteryState.unavailable,
    this.showBatteryPercentage = true,
    this.onBatteryTap,
    this.onPowerTap,
  });

  static const height = 40.0;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.black.withValues(alpha: 0.65),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Lado Esquerdo: Espaço reservado para janelas ativas ou app launcher futuro
          Row(
            children: [
              const SizedBox(width: 4),

              // Menu Psito (Botão do Passarinho à Direita)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onMenuTap,
                  borderRadius: BorderRadius.circular(6),
                  hoverColor: Colors.white12,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.flutter_dash, size: 20, color: accent),
                        const SizedBox(width: 6),
                        Text(
                          'Menu',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Lado Direito: Status do Sistema, Menu Psito e Data/Hora (Estilo Cinnamon)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicadores de Periféricos / Status
              NetworkIndicator(state: network, onTap: onNetworkTap),
              const SizedBox(width: 8),
              VolumeIndicator(
                state: audio,
                onTap: onVolumeTap,
                onScroll: onVolumeScroll,
              ),
              const SizedBox(width: 12),

              BatteryIndicator(
                state: battery,
                showPercentage: showBatteryPercentage,
                onTap: onBatteryTap,
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('|', style: TextStyle(color: Colors.white24)),
              ),

              _buildBell(accent),
              const SizedBox(width: 8),

              // Relógio / Data completa estilo Cinnamon
              StreamBuilder<DateTime>(
                stream: Stream.periodic(
                  const Duration(seconds: 1),
                  (_) => DateTime.now(),
                ),
                builder: (context, snapshot) {
                  final now = snapshot.data ?? DateTime.now();

                  // Formatação amigável da data em português (ex: Sáb, 12 de set, 16:41)
                  final formattedDateTime = formatClock(
                    now,
                    use24h: use24h,
                    showSeconds: showSeconds,
                  );

                  return GestureDetector(
                    onTap: onNotificationsTap,
                    child: Text(
                      formattedDateTime,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildPowerButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPowerButton() {
    return Tooltip(
      message: 'Energia',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('power-button'),
          onTap: onPowerTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: Colors.white12,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(
              Icons.power_settings_new,
              size: 16,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBell(Color accent) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('notifications-bell'),
        onTap: onNotificationsTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: Colors.white12,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text('$unreadCount'),
            backgroundColor: const Color(0xFFFF5722),
            child: Icon(
              doNotDisturb
                  ? Icons.notifications_off
                  : unreadCount > 0
                  ? Icons.notifications_active
                  : Icons.notifications_none,
              size: 16,
              color: unreadCount > 0 ? accent : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  /// Ex.: "Sáb, 12 de set, 16:41" ou, em 12h com segundos,
  /// "Sáb, 12 de set, 4:41:07 PM".
  static String formatClock(
    DateTime dt, {
    bool use24h = true,
    bool showSeconds = false,
  }) {
    const weekdays = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    const months = [
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez',
    ];

    final weekDay = weekdays[dt.weekday % 7];
    final day = dt.day;
    final month = months[dt.month - 1];
    final minute = dt.minute.toString().padLeft(2, '0');
    final seconds = showSeconds
        ? ':${dt.second.toString().padLeft(2, '0')}'
        : '';

    if (use24h) {
      final hour = dt.hour.toString().padLeft(2, '0');
      return '$weekDay, $day de $month, $hour:$minute$seconds';
    }
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$weekDay, $day de $month, $hour:$minute$seconds $period';
  }
}
