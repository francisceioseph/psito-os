// system_shell/lib/widgets/dock_menu.dart
//
// O menu de um ícone da dock (o clique direito), acima do ícone.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DockMenuItem {
  final String label;
  final VoidCallback onTap;

  /// Uma opção que liga e desliga: mostra a marca quando true. Null é uma
  /// ação.
  final bool? checked;

  const DockMenuItem(this.label, this.onTap, {this.checked});
}

class DockMenu extends StatelessWidget {
  /// O retângulo do ícone, nas coordenadas da tela.
  final Rect anchor;
  final String title;
  final List<DockMenuItem> items;
  final VoidCallback onClose;

  const DockMenu({
    super.key,
    required this.anchor,
    required this.title,
    required this.items,
    required this.onClose,
  });

  static const width = 260.0;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final left = (anchor.center.dx - width / 2).clamp(
      8.0,
      screen.width - width - 8,
    );
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
            Positioned(
              left: left,
              bottom: screen.height - anchor.top + 8,
              width: width,
              child: Material(
                color: const Color(0xFF1E252B),
                borderRadius: BorderRadius.circular(14),
                elevation: 12,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white60,
                          ),
                        ),
                      ),
                      for (final item in items)
                        ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          title: Text(item.label),
                          trailing: item.checked == true
                              ? const Icon(Icons.check, size: 18)
                              : null,
                          onTap: () {
                            onClose();
                            item.onTap();
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
