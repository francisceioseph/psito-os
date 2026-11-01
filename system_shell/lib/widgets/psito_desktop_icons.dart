// system_shell/lib/widgets/psito_desktop_icons.dart
//
// Os ícones da mesa, por cima do papel de parede. As células contam do canto
// de cima à direita da área livre (a tela sem a top bar e a dock). Quem
// decide a célula de cada um é o modelo (o psito_desktop).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:psito_desktop/psito_desktop.dart';

class DeskIcon {
  /// Identifica o item ([PsitoDesktopIcons.cells]).
  final String key;
  final String name;
  final Widget Function(double size) icon;

  const DeskIcon({required this.key, required this.name, required this.icon});
}

class PsitoDesktopIcons extends StatelessWidget {
  final List<DeskIcon> icons;
  final Map<String, DeskCell> cells;
  final double iconSize;

  /// O que a top bar e a dock tiram da tela.
  final EdgeInsets insets;
  final String? selected;

  /// Null: o clique foi na mesa vazia.
  final ValueChanged<String?> onSelect;
  final ValueChanged<String> onOpen;

  const PsitoDesktopIcons({
    super.key,
    required this.icons,
    required this.cells,
    required this.iconSize,
    required this.insets,
    this.selected,
    required this.onSelect,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cell = deskCellSize(iconSize);
    // O selecionado por último: o nome inteiro passa por cima dos vizinhos
    final ordered = [
      for (final icon in icons)
        if (icon.key != selected) icon,
      for (final icon in icons)
        if (icon.key == selected) icon,
    ];
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              if (event.buttons & kPrimaryButton != 0) onSelect(null);
            },
          ),
        ),
        for (final icon in ordered)
          if (cells[icon.key] case final at?)
            Positioned(
              key: ValueKey('desk-${icon.key}'),
              right: insets.right + at.column * cell.width,
              top: insets.top + at.row * cell.height,
              width: cell.width,
              height: cell.height,
              child: _Item(
                icon: icon,
                iconSize: iconSize,
                selected: icon.key == selected,
                onSelect: () => onSelect(icon.key),
                onOpen: () => onOpen(icon.key),
              ),
            ),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  final DeskIcon icon;
  final double iconSize;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  const _Item({
    required this.icon,
    required this.iconSize,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
  });

  static const _shadow = [
    Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1)),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    // Seleciona já no apertar: um onTapDown esperaria o tempo do duplo clique
    return Listener(
      onPointerDown: (event) {
        if (event.buttons & kPrimaryButton != 0) onSelect();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: onOpen,
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: selected ? accent.withValues(alpha: 0.28) : null,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: icon.icon(iconSize),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? accent.withValues(alpha: 0.85) : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    icon.name,
                    maxLines: selected ? null : 2,
                    overflow: selected ? null : TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      shadows: selected ? null : _shadow,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
