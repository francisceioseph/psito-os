// system_shell/lib/widgets/network_indicator.dart
//
// Ícone de rede da top bar. Some quando não há gerenciador de rede.
import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

class NetworkIndicator extends StatelessWidget {
  final PsitoNetworkState state;
  final VoidCallback? onTap;

  const NetworkIndicator({super.key, required this.state, this.onTap});

  static const _warning = Color(0xFFFF9800);

  /// Ícone e texto do estado; null quando não há o que mostrar.
  static (IconData, String, Color?)? describe(PsitoNetworkState s) {
    if (!s.available) return null;
    if (!s.enabled) {
      return (Icons.signal_wifi_off, 'Rede desativada', Colors.white38);
    }
    if (s.connecting) return (Icons.sync, 'Conectando…', null);
    final primary = s.primary;
    if (primary == null) return (Icons.link_off, 'Desconectado', null);

    final icon = switch (primary.kind) {
      PsitoNetworkKind.wifi => switch (primary.wifiStrength ?? 100) {
        > 66 => Icons.wifi,
        > 33 => Icons.wifi_2_bar,
        _ => Icons.wifi_1_bar,
      },
      PsitoNetworkKind.ethernet => Icons.lan,
      PsitoNetworkKind.other => Icons.settings_ethernet,
    };
    final noInternet =
        s.connectivity == PsitoConnectivity.limited ||
        s.connectivity == PsitoConnectivity.portal;
    if (noInternet) return (icon, 'Conectado, sem internet', _warning);
    return (icon, primary.connection ?? primary.interface, null);
  }

  @override
  Widget build(BuildContext context) {
    final described = describe(state);
    if (described == null) return const SizedBox.shrink();
    final (icon, tooltip, color) = described;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('network-indicator'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: Colors.white12,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icon, size: 16, color: color ?? Colors.white70),
          ),
        ),
      ),
    );
  }
}
