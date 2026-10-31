// system_shell/lib/widgets/power_confirm_dialog.dart
//
// Confirmação de desligar ou reiniciar, que age sozinha no fim da contagem.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PowerConfirmDialog extends StatefulWidget {
  /// "Desligar" ou "Reiniciar".
  final String action;

  /// "Desligando" ou "Reiniciando".
  final String progressive;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  static const countdown = 10;

  const PowerConfirmDialog({
    super.key,
    required this.action,
    required this.progressive,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<PowerConfirmDialog> createState() => _PowerConfirmDialogState();
}

class _PowerConfirmDialogState extends State<PowerConfirmDialog> {
  int _remaining = PowerConfirmDialog.countdown;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _remaining--);
      if (_remaining > 0) return;
      timer.cancel();
      widget.onConfirm();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _confirm() {
    _timer.cancel();
    widget.onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel,
      },
      child: FocusScope(
        autofocus: true,
        child: ColoredBox(
          color: Colors.black54,
          child: Center(
            child: Material(
              color: const Color(0xFF1E252B),
              borderRadius: BorderRadius.circular(20),
              elevation: 16,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.action} o Psito OS?',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.progressive} em $_remaining s…',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: widget.onCancel,
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          autofocus: true,
                          onPressed: _confirm,
                          child: Text('${widget.action} agora'),
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
