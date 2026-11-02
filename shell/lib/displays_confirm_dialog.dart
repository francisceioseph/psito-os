// shell/lib/displays_confirm_dialog.dart
//
// "Manter esta configuração?" depois de mudar os monitores. Fica no shell porque
// as Configurações podem ter fechado, ou estar numa tela que apagou. O foco
// começa em "Voltar": o Enter de quem não enxerga a tela não pode manter.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'displays.dart';
import 'l10n/shell_localizations.dart';

class DisplaysConfirmDialog extends StatelessWidget {
  final DisplaysConfirm request;
  final ShellLocalizations l10n;

  const DisplaysConfirmDialog({
    super.key,
    required this.request,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): request.revert,
      },
      child: ColoredBox(
        color: palette.scrim,
        child: Center(
          child: Material(
            color: palette.panel,
            borderRadius: BorderRadius.circular(20),
            elevation: 16,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monitor_outlined,
                      size: 40,
                      color: palette.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.displaysConfirmTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListenableBuilder(
                      listenable: request,
                      builder: (context, _) => Text(
                        l10n.displaysConfirmBody(request.secondsLeft),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          key: const ValueKey('displays-revert'),
                          autofocus: true,
                          onPressed: request.revert,
                          child: Text(l10n.displaysConfirmRevert),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          key: const ValueKey('displays-keep'),
                          onPressed: request.keep,
                          child: Text(l10n.displaysConfirmKeep),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
