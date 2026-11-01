// system_shell/lib/widgets/power_panel.dart
//
// Menu do botão de energia: suspender, reiniciar e desligar.
import 'package:psito_sdk/psito_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:system_shell/l10n/l10n.dart';
import 'package:flutter/services.dart';

import 'package:psito_services/session_service.dart';

import 'top_bar.dart';

class PowerPanel extends StatelessWidget {
  final ValueListenable<SessionCapabilities> capabilities;
  final VoidCallback onSuspend;
  final VoidCallback onReboot;
  final VoidCallback onPowerOff;
  final VoidCallback onClose;

  const PowerPanel({
    super.key,
    required this.capabilities,
    required this.onSuspend,
    required this.onReboot,
    required this.onPowerOff,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose},
      child: FocusScope(
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
              width: 220,
              child: ValueListenableBuilder(
                valueListenable: capabilities,
                builder: (context, can, _) => _buildPanel(context, can),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context, SessionCapabilities can) {
    final items = [
      (Icons.bedtime_outlined, context.l10n.suspend, can.canSuspend, onSuspend),
      (Icons.restart_alt, context.l10n.reboot, can.canReboot, onReboot),
      (
        Icons.power_settings_new,
        context.l10n.powerOff,
        can.canPowerOff,
        onPowerOff,
      ),
    ];
    final firstEnabled = items.indexWhere((item) => item.$3);
    return Material(
      color: context.palette.panel,
      borderRadius: BorderRadius.circular(18),
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, (icon, label, enabled, onTap)) in items.indexed)
              ListTile(
                dense: true,
                autofocus: i == firstEnabled,
                enabled: enabled,
                leading: Icon(icon, size: 20),
                title: Text(label),
                onTap: onTap,
              ),
          ],
        ),
      ),
    );
  }
}
