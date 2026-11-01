// system_shell/lib/widgets/transfer_indicator.dart
//
// O que a mesa está copiando ou movendo, na top bar: a mesa fica atrás das
// janelas, e uma cópia longa precisa aparecer e poder parar.
import 'package:flutter/material.dart';

@immutable
class TransferStatus {
  /// "Copiando", com o nome do item que está indo.
  final String text;

  /// De 0 a 1. Null: ainda contando.
  final double? fraction;

  const TransferStatus(this.text, this.fraction);

  @override
  bool operator ==(Object other) =>
      other is TransferStatus &&
      other.text == text &&
      other.fraction == fraction;

  @override
  int get hashCode => Object.hash(text, fraction);
}

class TransferIndicator extends StatelessWidget {
  final TransferStatus status;
  final VoidCallback? onCancel;

  const TransferIndicator({super.key, required this.status, this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(
            value: status.fraction,
            strokeWidth: 2,
          ),
        ),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            status.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ),
        InkWell(
          key: const ValueKey('transfer-cancel'),
          onTap: onCancel,
          borderRadius: BorderRadius.circular(6),
          hoverColor: Colors.white12,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.close_rounded, size: 14, color: Colors.white70),
          ),
        ),
      ],
    );
  }
}
