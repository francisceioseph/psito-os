// system_shell/lib/widgets/dock_menu.dart
//
// O menu de um ícone da dock (o clique direito), acima do ícone.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/l10n/l10n.dart';

class DockMenuItem {
  final String label;
  final VoidCallback onTap;

  /// Uma opção que liga e desliga: mostra a marca quando true. Null é uma
  /// ação.
  final bool? checked;

  /// Um traço antes, separando de um grupo (as janelas, das ações).
  final bool separated;

  /// Apagada, sem responder ao clique.
  final bool enabled;

  /// O menu fica aberto: o [onTap] troca as opções (um "Abrir com…").
  final bool keepsOpen;

  const DockMenuItem(
    this.label,
    this.onTap, {
    this.checked,
    this.separated = false,
    this.enabled = true,
    this.keepsOpen = false,
  });
}

/// Põe o menu da mesa no ponteiro ([at]), para baixo e para a direita, e para
/// o outro lado se não couber.
class PointerPopupLayout extends SingleChildLayoutDelegate {
  final Offset at;
  final double width;

  const PointerPopupLayout(this.at, this.width);

  static const margin = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.max(
          0,
          math.min(width, constraints.maxWidth - 2 * margin),
        ),
        maxHeight: math.max(0, constraints.maxHeight - 2 * margin),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double fit(double value, double extent, double space) {
      final start = value + extent > space - margin ? value - extent : value;
      return start.clamp(margin, math.max(margin, space - extent - margin));
    }

    return Offset(
      fit(at.dx, childSize.width, size.width),
      fit(at.dy, childSize.height, size.height),
    );
  }

  @override
  bool shouldRelayout(PointerPopupLayout old) =>
      old.at != at || old.width != width;
}

/// Põe um painel da dock (o menu, a pilha) ao lado do ícone [anchor], do
/// lado de dentro da tela: acima com a dock embaixo, à direita com ela na
/// esquerda, à esquerda com ela na direita. Ele fica inteiro na tela.
class DockPopupLayout extends SingleChildLayoutDelegate {
  final Rect anchor;
  final PsitoDockPosition position;

  /// A largura do painel.
  final double width;

  const DockPopupLayout(this.anchor, this.position, this.width);

  static const gap = 8.0;
  static const margin = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.max(
          0,
          math.min(width, constraints.maxWidth - 2 * margin),
        ),
        maxHeight: math.max(0, constraints.maxHeight - 2 * margin),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double fit(double value, double extent, double space) =>
        value.clamp(margin, math.max(margin, space - extent - margin));
    return switch (position) {
      PsitoDockPosition.bottom => Offset(
        fit(
          anchor.center.dx - childSize.width / 2,
          childSize.width,
          size.width,
        ),
        fit(anchor.top - gap - childSize.height, childSize.height, size.height),
      ),
      PsitoDockPosition.left => Offset(
        fit(anchor.right + gap, childSize.width, size.width),
        fit(
          anchor.center.dy - childSize.height / 2,
          childSize.height,
          size.height,
        ),
      ),
      PsitoDockPosition.right => Offset(
        fit(anchor.left - gap - childSize.width, childSize.width, size.width),
        fit(
          anchor.center.dy - childSize.height / 2,
          childSize.height,
          size.height,
        ),
      ),
    };
  }

  @override
  bool shouldRelayout(DockPopupLayout old) =>
      old.anchor != anchor || old.position != position || old.width != width;
}

class DockMenu extends StatelessWidget {
  /// O retângulo do ícone, nas coordenadas da tela.
  final Rect anchor;
  final String title;
  final List<DockMenuItem> items;
  final VoidCallback onClose;

  /// A borda da dock: o menu abre do lado de dentro.
  final PsitoDockPosition position;

  /// Abre aqui, em vez de ao lado do [anchor] (o menu da mesa e o do
  /// launcher, que não saem de um ícone da dock).
  final Offset? at;

  const DockMenu({
    super.key,
    this.anchor = Rect.zero,
    required this.title,
    required this.items,
    required this.onClose,
    this.position = PsitoDockPosition.bottom,
    this.at,
  });

  static const width = 260.0;

  @override
  Widget build(BuildContext context) {
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
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: at != null
                    ? PointerPopupLayout(at!, width)
                    : DockPopupLayout(anchor, position, width),
                child: Material(
                  color: const Color(0xFF1E252B),
                  borderRadius: BorderRadius.circular(14),
                  elevation: 12,
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
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
                        for (final item in items) ...[
                          if (item.separated)
                            const Divider(
                              height: 9,
                              indent: 12,
                              endIndent: 12,
                              color: Colors.white12,
                            ),
                          ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            enabled: item.enabled,
                            title: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: item.checked == true
                                ? const Icon(Icons.check, size: 18)
                                : null,
                            onTap: () {
                              if (!item.keepsOpen) onClose();
                              item.onTap();
                            },
                          ),
                        ],
                      ],
                    ),
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

/// A confirmação de uma opção do menu que não se desfaz (o "Esvaziar a
/// lixeira").
class DockConfirm extends StatelessWidget {
  final String title;
  final String message;
  final String action;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const DockConfirm({
    super.key,
    required this.title,
    required this.message,
    required this.action,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.escape): onCancel},
    child: FocusScope(
      autofocus: true,
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Material(
            color: const Color(0xFF1E252B),
            borderRadius: BorderRadius.circular(20),
            elevation: 16,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          autofocus: true,
                          onPressed: onCancel,
                          child: Text(context.l10n.cancel),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: () {
                            onCancel();
                            onConfirm();
                          },
                          child: Text(action),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
