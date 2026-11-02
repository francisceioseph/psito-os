// examples/player/lib/src/ui/atoms/tag_chip.dart
//
// A etiqueta pequena e com contorno: formato do arquivo, contadores, situação.
import 'package:flutter/material.dart';

class TagChip extends StatelessWidget {
  final String label;
  final IconData? icon;

  /// Pinta com a cor de erro, para o que pede atenção.
  final bool warning;

  const TagChip({
    super.key,
    required this.label,
    this.icon,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = warning ? scheme.onErrorContainer : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: warning ? scheme.errorContainer : null,
        borderRadius: BorderRadius.circular(8),
        border: warning ? null : Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
