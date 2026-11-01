// shell/lib/disk_unlock_dialog.dart
//
// A senha de um disco criptografado. Fica no shell porque o app que pediu não
// pode ver a senha, nem tentar outras por conta própria.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/disks_service.dart';

import 'l10n/shell_localizations.dart';

/// Um pedido de senha, até a senha certa ou a desistência.
class DiskUnlockRequest extends ChangeNotifier {
  final String id;
  final String name;
  final Future<DiskUnlockResult> Function(String password) attempt;
  final _done = Completer<String?>();

  bool checking = false;
  bool wrong = false;

  /// Não era a senha: o disco é que não abriu.
  bool failed = false;

  DiskUnlockRequest({
    required this.id,
    required this.name,
    required this.attempt,
  });

  /// Onde montou. Null se a pessoa desistiu ou não deu.
  Future<String?> get done => _done.future;

  Future<void> submit(String password) async {
    if (password.isEmpty || checking || _done.isCompleted) return;
    checking = true;
    wrong = false;
    notifyListeners();
    final answer = await attempt(password);
    if (_done.isCompleted) return;
    switch (answer.result) {
      case PsitoDiskResult.ok:
        _done.complete(answer.mountPoint);
      case PsitoDiskResult.wrongPassword:
        checking = false;
        wrong = true;
        notifyListeners();
      case PsitoDiskResult.busy || PsitoDiskResult.failed:
        failed = true;
        _done.complete(null);
    }
  }

  void cancel() {
    if (!_done.isCompleted) _done.complete(null);
  }
}

/// O diálogo, na sobreposição com o teclado.
class DiskUnlockDialog extends StatefulWidget {
  final DiskUnlockRequest request;
  final ShellLocalizations l10n;

  const DiskUnlockDialog({
    super.key,
    required this.request,
    required this.l10n,
  });

  @override
  State<DiskUnlockDialog> createState() => _DiskUnlockDialogState();
}

class _DiskUnlockDialogState extends State<DiskUnlockDialog> {
  final _password = TextEditingController();
  bool _show = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() => unawaited(widget.request.submit(_password.text));

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
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 40,
                          color: palette.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l.diskUnlockTitle(request.name),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.diskUnlockBody,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: palette.textSecondary),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          key: const ValueKey('disk-password'),
                          controller: _password,
                          autofocus: true,
                          obscureText: !_show,
                          // Como no bloqueio: sem o foco, a próxima tentativa
                          // não teria onde entrar. O texto fica: uma frase
                          // longa com um erro só não se digita de novo
                          readOnly: request.checking,
                          onSubmitted: (_) => _submit(),
                          onEditingComplete: () {},
                          decoration: InputDecoration(
                            hintText: l.diskUnlockHint,
                            filled: true,
                            fillColor: palette.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: IconButton(
                              key: const ValueKey('disk-password-show'),
                              tooltip: _show
                                  ? l.diskUnlockHide
                                  : l.diskUnlockShow,
                              icon: Icon(
                                _show
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () => setState(() => _show = !_show),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 20,
                          child: request.wrong
                              ? Text(
                                  l.diskUnlockWrong,
                                  style: TextStyle(color: palette.danger),
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: request.checking
                                  ? null
                                  : request.cancel,
                              child: Text(l.diskUnlockCancel),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: request.checking ? null : _submit,
                              child: Text(l.diskUnlockAction),
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
