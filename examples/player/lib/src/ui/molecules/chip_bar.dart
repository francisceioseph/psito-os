// examples/player/lib/src/ui/molecules/chip_bar.dart
//
// Os filtros de uma tela: um escolhido de cada vez, rolando quando não cabem.
import 'package:flutter/material.dart';

class ChipBar<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  const ChipBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final (value, label) in options)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: value == selected,
              onSelected: (_) => onSelected(value),
            ),
          ),
      ],
    ),
  );
}
