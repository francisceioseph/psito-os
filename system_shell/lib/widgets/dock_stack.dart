// system_shell/lib/widgets/dock_stack.dart
//
// Uma pasta da dock aberta como pilha, acima do ícone: em leque com poucos
// itens, em grade com mais. Os mais novos ficam mais perto da dock (no
// leque) ou primeiro (na grade).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:psito_sdk/psito_sdk.dart';

import '../shell/app_entry.dart';
import 'dock_menu.dart';

import 'package:system_shell/l10n/l10n.dart';

class DockStackEntry {
  /// Identifica o item no [DockStack.onOpen] (o caminho, no shell).
  final String key;
  final AppEntry entry;

  const DockStackEntry(this.key, this.entry);
}

class DockStack extends StatelessWidget {
  /// O retângulo do ícone da pasta, nas coordenadas da tela.
  final Rect anchor;
  final String title;

  /// Os mais novos primeiro.
  final List<DockStackEntry> entries;
  final void Function(String key) onOpen;

  /// O "Abrir no Files".
  final VoidCallback onOpenFolder;
  final VoidCallback onClose;

  /// A borda da dock. O leque só existe embaixo; dos lados é a grade.
  final PsitoDockPosition position;

  const DockStack({
    super.key,
    required this.anchor,
    required this.title,
    required this.entries,
    required this.onOpen,
    required this.onOpenFolder,
    required this.onClose,
    this.position = PsitoDockPosition.bottom,
  });

  /// Até quantos itens a pilha é um leque.
  static const fanLimit = 8;
  static const columns = 5;
  static const cell = 104.0;

  bool get fan =>
      position == PsitoDockPosition.bottom &&
      entries.isNotEmpty &&
      entries.length <= fanLimit;

  void _open(String key) {
    onClose();
    onOpen(key);
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    // O primeiro quadro da sobreposição pode vir antes do tamanho dela
    if (screen.width < cell * 2 || screen.height < cell * 2) {
      return const SizedBox.shrink();
    }
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose},
      child: FocusScope(
        autofocus: true,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: onClose,
                onSecondaryTap: onClose,
                behavior: HitTestBehavior.opaque,
              ),
            ),
            if (fan) _fan(context, screen) else _grid(context, screen),
          ],
        ),
      ),
    );
  }

  /// Uma coluna em arco acima do ícone, com o nome à esquerda de cada um.
  Widget _fan(BuildContext context, Size screen) {
    const icon = 48.0;
    final rows = [
      _FanRow(
        label: context.l10n.openInFiles,
        onTap: () {
          onClose();
          onOpenFolder();
        },
        child: const SizedBox.square(
          dimension: icon,
          child: Icon(Icons.open_in_new, color: Colors.white70),
        ),
      ),
      for (final item in entries.reversed)
        _FanRow(
          key: ValueKey('stack-${item.key}'),
          label: item.entry.name,
          onTap: () => _open(item.key),
          child: item.entry.icon(icon),
        ),
    ];
    final count = rows.length;
    return Positioned(
      right: screen.width - anchor.center.dx - icon / 2,
      bottom: screen.height - anchor.top + 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, row) in rows.indexed)
            // Mais alto, mais para a direita e mais inclinado
            Transform.translate(
              offset: Offset(math.pow(count - 1 - i, 2) * 1.6, 0),
              child: Transform.rotate(
                angle: (count - 1 - i) * 0.025,
                alignment: Alignment.centerRight,
                child: row,
              ),
            ),
        ],
      ),
    );
  }

  Widget _grid(BuildContext context, Size screen) {
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: DockPopupLayout(anchor, position, columns * cell + 24),
        child: Material(
          color: const Color(0xFF1E252B),
          borderRadius: BorderRadius.circular(18),
          elevation: 12,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        onClose();
                        onOpenFolder();
                      },
                      child: Text(context.l10n.openInFiles),
                    ),
                  ],
                ),
                if (entries.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      context.l10n.folderEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: math.max(
                        120,
                        math.min(
                          420,
                          position == PsitoDockPosition.bottom
                              ? anchor.top - 120
                              : screen.height - 160,
                        ),
                      ),
                    ),
                    child: GridView.extent(
                      maxCrossAxisExtent: cell,
                      shrinkWrap: true,
                      children: [
                        for (final item in entries)
                          _GridCell(
                            key: ValueKey('stack-${item.key}'),
                            entry: item.entry,
                            onTap: () => _open(item.key),
                          ),
                      ],
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

class _FanRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Widget child;

  const _FanRow({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          child,
        ],
      ),
    ),
  );
}

class _GridCell extends StatelessWidget {
  final AppEntry entry;
  final VoidCallback onTap;

  const _GridCell({super.key, required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          entry.icon(48),
          const SizedBox(height: 6),
          Text(
            entry.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
