// examples/player/lib/src/ui/molecules/sort_menu.dart
//
// O ordenar de uma tela: o ícone, a ordem atual e o menu.
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

class SortMenu<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  const SortMenu({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final label = options.firstWhere((o) => o.$1 == selected).$2;
    return PopupMenuButton<T>(
      tooltip: context.l10n.sortBy,
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final (value, text) in options)
          PopupMenuItem(value: value, child: Text(text)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 18),
            const SizedBox(width: 8),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}
