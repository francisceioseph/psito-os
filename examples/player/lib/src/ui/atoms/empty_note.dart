// examples/player/lib/src/ui/atoms/empty_note.dart
//
// O aviso de uma lista sem nada.
import 'package:flutter/material.dart';

class EmptyNote extends StatelessWidget {
  final String text;

  const EmptyNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
