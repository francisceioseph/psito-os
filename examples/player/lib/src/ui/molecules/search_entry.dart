// examples/player/lib/src/ui/molecules/search_entry.dart
//
// O campo de busca do alto das telas. A digitação acontece na tela Buscar: aqui é
// só o caminho até ela, junto com o Ctrl K.
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

class SearchEntry extends StatelessWidget {
  static const width = 280.0;

  final String hint;
  final VoidCallback onTap;

  const SearchEntry({super.key, required this.hint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Semantics(
      button: true,
      label: hint,
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                width: constraints.maxWidth < width
                    ? constraints.maxWidth
                    : width - 32,
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                    ),
                    Text(
                      context.l10n.searchShortcut,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
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
