import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'package:psito_services/audio_service.dart';
import 'package:psito_services/battery_service.dart';

import 'battery_indicator.dart';
import 'clipboard_panel.dart';
import 'network_indicator.dart';
import 'transfer_indicator.dart';
import 'volume_indicator.dart';

import 'package:system_shell/l10n/l10n.dart';

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

  /// Quantos itens o histórico da área de transferência tem.
  final int clipboardCount;

  /// O applet da área de transferência. Null: sem applet (no laboratório, que
  /// não tem o histórico).
  final VoidCallback? onClipboardTap;

  /// O que a mesa está copiando ou movendo. Null: nada.
  final TransferStatus? transfer;
  final VoidCallback? onCancelTransfer;

  /// Botão de energia: abre e fecha o menu de energia.
  final VoidCallback? onPowerTap;

  /// Hora local no fuso do sistema (o TimeService), não o DateTime.now().
  final DateTime Function() now;

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
    this.clipboardCount = 0,
    this.onClipboardTap,
    this.transfer,
    this.onCancelTransfer,
    this.onPowerTap,
    this.now = DateTime.now,
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
      color: context.palette.shadow.withValues(alpha: 0.65),
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
                  hoverColor: context.palette.lineSoft,
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
                          context.l10n.menu,
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
              if (transfer case final status?) ...[
                TransferIndicator(status: status, onCancel: onCancelTransfer),
                const SizedBox(width: 8),
              ],
              if (onClipboardTap != null) ...[
                ClipboardIndicator(
                  count: clipboardCount,
                  onTap: onClipboardTap,
                ),
                const SizedBox(width: 8),
              ],
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

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('|', style: TextStyle(color: context.palette.line)),
              ),

              _buildBell(context, accent),
              const SizedBox(width: 8),

              // Relógio / Data completa estilo Cinnamon
              StreamBuilder<DateTime>(
                stream: Stream.periodic(
                  const Duration(seconds: 1),
                  (_) => now(),
                ),
                builder: (context, snapshot) {
                  final time = snapshot.data ?? now();

                  // Formatação amigável da data (ex.: sáb., 12 de set., 16:41)
                  final formattedDateTime = formatClock(
                    time,
                    Localizations.localeOf(context).toString(),
                    use24h: use24h,
                    showSeconds: showSeconds,
                  );

                  return GestureDetector(
                    onTap: onNotificationsTap,
                    child: Text(
                      formattedDateTime,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.palette.text,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildPowerButton(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPowerButton(BuildContext context) {
    return Tooltip(
      message: context.l10n.power,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('power-button'),
          onTap: onPowerTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: context.palette.lineSoft,
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Icon(
              Icons.power_settings_new,
              size: 16,
              color: context.palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBell(BuildContext context, Color accent) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('notifications-bell'),
        onTap: onNotificationsTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: context.palette.lineSoft,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text('$unreadCount'),
            backgroundColor: context.palette.cheek,
            child: Icon(
              doNotDisturb
                  ? Icons.notifications_off
                  : unreadCount > 0
                  ? Icons.notifications_active
                  : Icons.notifications_none,
              size: 16,
              color: unreadCount > 0 ? accent : context.palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  /// Ex.: "Sáb, 12 de set, 16:41" ou, em 12h com segundos,
  /// "sáb., 12 de set., 16:41:07", no idioma de [locale].
  static String formatClock(
    DateTime dt,
    String locale, {
    bool use24h = true,
    bool showSeconds = false,
  }) {
    final date = DateFormat.MMMEd(locale).format(dt);
    final time = switch ((use24h, showSeconds)) {
      (true, true) => DateFormat.Hms(locale),
      (true, false) => DateFormat.Hm(locale),
      (false, true) => DateFormat('h:mm:ss a', locale),
      (false, false) => DateFormat('h:mm a', locale),
    }.format(dt);
    return '$date, $time';
  }
}
