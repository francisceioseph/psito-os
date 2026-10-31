// system_shell/lib/widgets/network_panel.dart
//
// Painel do ícone de rede: conexão atual e o interruptor geral.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'network_indicator.dart';
import 'top_bar.dart';

class NetworkPanel extends StatelessWidget {
  final ValueListenable<PsitoNetworkState> state;
  final ValueChanged<bool> onSetEnabled;
  final VoidCallback onClose;

  const NetworkPanel({
    super.key,
    required this.state,
    required this.onSetEnabled,
    required this.onClose,
  });

  static String connectivityLabel(PsitoConnectivity c) => switch (c) {
    PsitoConnectivity.full => 'Internet',
    PsitoConnectivity.limited || PsitoConnectivity.none => 'Sem internet',
    PsitoConnectivity.portal => 'Portal de acesso',
    PsitoConnectivity.unknown => 'Verificando…',
  };

  static String kindLabel(PsitoNetworkKind kind) => switch (kind) {
    PsitoNetworkKind.ethernet => 'Cabo',
    PsitoNetworkKind.wifi => 'Wi-Fi',
    PsitoNetworkKind.other => 'Rede',
  };

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose},
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            // Clicar fora fecha. A top bar fica de fora: clicar em outro
            // ícone dela troca de painel em vez de só fechar este
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
                builder: (context, s, _) => _buildPanel(context, s),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context, PsitoNetworkState s) {
    final primary = s.primary;
    final (icon, _, color) =
        NetworkIndicator.describe(s) ?? (Icons.link_off, '', null);
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
                Icon(icon, size: 28, color: color ?? Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        primary?.connection ??
                            (s.enabled ? 'Desconectado' : 'Rede desativada'),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (primary != null)
                        Text(
                          '${kindLabel(primary.kind)} · '
                          '${connectivityLabel(s.connectivity)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (primary?.ipv4 case final ip?) ...[
              const SizedBox(height: 12),
              Text(
                'IPv4  $ip',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
            const Divider(height: 24, color: Colors.white12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Rede'),
              value: s.enabled,
              onChanged: onSetEnabled,
            ),
          ],
        ),
      ),
    );
  }
}
