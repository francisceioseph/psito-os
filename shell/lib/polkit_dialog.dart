import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'l10n/shell_localizations.dart';
import 'polkit_agent.dart';

/// O diálogo da senha de administrador, na sobreposição com o teclado.
class PolkitDialog extends StatefulWidget {
  final PolkitRequest request;
  final ShellLocalizations l10n;

  const PolkitDialog({super.key, required this.request, required this.l10n});

  @override
  State<PolkitDialog> createState() => _PolkitDialogState();
}

class _PolkitDialogState extends State<PolkitDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    widget.request.answer(_password.text);
    _password.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l10n;
    final palette = context.palette;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.request.cancel,
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
                child: ListenableBuilder(
                  listenable: widget.request,
                  builder: (context, _) {
                    final request = widget.request;
                    final checking = request.prompt == null;
                    final notice = request.wrong
                        ? l.polkitWrongPassword
                        : request.info;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 40,
                          color: palette.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l.polkitTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          request.message,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: palette.textSecondary),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          key: const ValueKey('polkit-password'),
                          controller: _password,
                          autofocus: true,
                          obscureText: true,
                          // Como no bloqueio: sem o foco, a próxima tentativa
                          // não teria onde entrar
                          readOnly: checking,
                          onSubmitted: (_) => _submit(),
                          onEditingComplete: () {},
                          decoration: InputDecoration(
                            hintText: l.polkitPasswordOf(request.user),
                            filled: true,
                            fillColor: palette.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 20,
                          child: notice == null
                              ? null
                              : Text(
                                  notice,
                                  style: TextStyle(color: palette.danger),
                                ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: request.cancel,
                              child: Text(l.polkitCancel),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: checking ? null : _submit,
                              child: Text(l.polkitAuthenticate),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
