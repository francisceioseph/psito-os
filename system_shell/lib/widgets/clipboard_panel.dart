// system_shell/lib/widgets/clipboard_panel.dart
//
// O applet da área de transferência: o ícone da top bar, o painel com as
// últimas cópias e o aviso de quando um atalho copia de novo.
import 'dart:async';

import 'package:psito_sdk/psito_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shell/clipboard_history.dart';
import 'top_bar.dart';

import 'package:system_shell/l10n/l10n.dart';

IconData _iconFor(ClipKind kind) => switch (kind) {
  ClipKind.text => Icons.notes_rounded,
  ClipKind.image => Icons.image_outlined,
  ClipKind.files => Icons.insert_drive_file_outlined,
  ClipKind.other => Icons.data_object_rounded,
};

/// O atalho de re-copiar a posição [index], como a tabela de atalhos mostra.
/// Essa combinação funciona na VM e fora dela.
String clipboardShortcutLabel(int index) => 'Alt+Shift+${index + 1}';

class ClipboardIndicator extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const ClipboardIndicator({super.key, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: count == 0
        ? context.l10n.clipboardTitle
        : context.l10n.clipboardTooltip(count),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('clipboard-indicator'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: context.palette.lineSoft,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.content_paste_rounded,
            size: 16,
            color: count == 0
                ? context.palette.textDisabled
                : context.palette.textSecondary,
          ),
        ),
      ),
    ),
  );
}

class ClipboardPanel extends StatefulWidget {
  final ClipboardHistory history;

  /// O item escolhido, pela posição. O painel fecha a seguir.
  final ValueChanged<int> onPick;
  final VoidCallback onClose;

  const ClipboardPanel({
    super.key,
    required this.history,
    required this.onPick,
    required this.onClose,
  });

  @override
  State<ClipboardPanel> createState() => _ClipboardPanelState();
}

class _ClipboardPanelState extends State<ClipboardPanel> {
  // Só para "há 3 min" andar com o painel aberto
  late final Timer _ticker = Timer.periodic(
    const Duration(seconds: 30),
    (_) => setState(() {}),
  );

  @override
  void initState() {
    super.initState();
    _ticker;
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  String _age(ClipEntry entry) {
    final minutes = widget.history.now().difference(entry.copiedAt).inMinutes;
    return minutes == 0
        ? context.l10n.timeNow
        : context.l10n.timeMinutesAgo(minutes);
  }

  void _pick(int index) {
    if (index < widget.history.entries.length) widget.onPick(index);
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      for (final (i, key) in const [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
      ].indexed)
        SingleActivator(key): () => _pick(i),
    },
    child: Focus(
      autofocus: true,
      child: Stack(
        children: [
          Positioned.fill(
            top: TopBar.height,
            child: GestureDetector(
              excludeFromSemantics: true,
              onTap: widget.onClose,
              behavior: HitTestBehavior.opaque,
            ),
          ),
          Positioned(
            top: 48,
            right: 12,
            width: 360,
            child: ListenableBuilder(
              listenable: widget.history,
              builder: (context, _) => _panel(context),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _panel(BuildContext context) {
    final entries = widget.history.entries;
    return Material(
      color: context.palette.panel,
      borderRadius: BorderRadius.circular(18),
      elevation: 12,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.clipboardTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (entries.isNotEmpty)
                    TextButton(
                      onPressed: widget.history.clear,
                      child: Text(
                        context.l10n.clear,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            if (entries.isEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Text(
                  context.l10n.clipboardEmpty,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.textQuiet,
                  ),
                ),
              ),
            for (final (i, entry) in entries.indexed) _row(i, entry),
          ],
        ),
      ),
    );
  }

  Widget _row(int index, ClipEntry entry) => InkWell(
    key: ValueKey('clipboard-item-$index'),
    onTap: () => _pick(index),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 36,
            child: entry.image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(
                      entry.image!,
                      fit: BoxFit.cover,
                      cacheWidth: 72,
                      errorBuilder: (_, _, _) => Icon(
                        _iconFor(entry.kind),
                        color: context.palette.textQuiet,
                      ),
                    ),
                  )
                : Icon(_iconFor(entry.kind), color: context.palette.textQuiet),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.text(context.l10n),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  _age(entry),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.palette.textQuiet,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: context.l10n.orShortcut('Super+${index + 1}'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: context.palette.hover,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                clipboardShortcutLabel(index),
                style: TextStyle(
                  fontSize: 11,
                  color: context.palette.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// O aviso de que um atalho copiou de novo: o atalho não mostra mais nada.
class ClipboardOsd extends StatelessWidget {
  final ClipEntry entry;

  const ClipboardOsd({super.key, required this.entry});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Material(
      color: context.palette.panelGlass,
      borderRadius: BorderRadius.circular(16),
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconFor(entry.kind), color: context.palette.text),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  context.l10n.copied(entry.text(context.l10n)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.palette.textSecondary,
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
