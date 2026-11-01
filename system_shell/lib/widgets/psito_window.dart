// system_shell/lib/widgets/psito_window.dart
import 'package:psito_sdk/psito_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../shell/window_manager.dart';

import 'package:system_shell/l10n/l10n.dart';

/// Moldura de uma janela: barra de título, botões e bordas de redimensionar.
/// O estado fica todo no [WindowManager].
class PsitoWindow extends StatelessWidget {
  final ShellWindow window;
  final WindowManager manager;
  final bool focused;

  const PsitoWindow({
    super.key,
    required this.window,
    required this.manager,
    required this.focused,
  });

  static const _edge = 6.0;
  static const _corner = 14.0;

  @override
  Widget build(BuildContext context) {
    final app = window.app;
    final snapped = window.snap != null;
    final radius = snapped ? 0.0 : 16.0;

    final frame = Container(
      decoration: BoxDecoration(
        color: context.palette.panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: focused ? app.color : context.palette.line,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: context.palette.shadow.withValues(
              alpha: focused ? 0.6 : 0.35,
            ),
            blurRadius: focused ? 25 : 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius == 0 ? 0 : radius - 1),
        child: Column(
          children: [
            _TitleBar(window: window, manager: manager, focused: focused),
            // Material transparente: realces e ink dos apps pintam dentro da
            // janela, não no Scaffold por baixo dela
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: app.build(window.context),
              ),
            ),
          ],
        ),
      ),
    );

    // Listener não entra na disputa de gestos: o clique ainda chega ao app.
    return Listener(
      onPointerDown: (_) => manager.focus(window.id),
      child: Stack(
        children: [
          Positioned.fill(child: frame),
          if (window.snap != SnapMode.maximized) ..._resizeHandles(),
        ],
      ),
    );
  }

  List<Widget> _resizeHandles() {
    Widget handle(ResizeEdge edge) => GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanUpdate: (d) => manager.resize(window.id, edge, d.delta),
    );

    return [
      Positioned(
        top: 0,
        left: _corner,
        right: _corner,
        height: _edge,
        child: handle(ResizeEdge.top),
      ),
      Positioned(
        bottom: 0,
        left: _corner,
        right: _corner,
        height: _edge,
        child: handle(ResizeEdge.bottom),
      ),
      Positioned(
        left: 0,
        top: _corner,
        bottom: _corner,
        width: _edge,
        child: handle(ResizeEdge.left),
      ),
      Positioned(
        right: 0,
        top: _corner,
        bottom: _corner,
        width: _edge,
        child: handle(ResizeEdge.right),
      ),
      for (final (edge, top, left) in const [
        (ResizeEdge.topLeft, true, true),
        (ResizeEdge.topRight, true, false),
        (ResizeEdge.bottomLeft, false, true),
        (ResizeEdge.bottomRight, false, false),
      ])
        Positioned(
          top: top ? 0 : null,
          bottom: top ? null : 0,
          left: left ? 0 : null,
          right: left ? null : 0,
          width: _corner,
          height: _corner,
          child: handle(edge),
        ),
    ];
  }
}

class _TitleBar extends StatelessWidget {
  final ShellWindow window;
  final WindowManager manager;
  final bool focused;

  const _TitleBar({
    required this.window,
    required this.manager,
    required this.focused,
  });

  @override
  Widget build(BuildContext context) {
    final app = window.app;
    final maximized = window.snap == SnapMode.maximized;

    // Os botões ficam fora do GestureDetector: o reconhecedor de duplo
    // clique seguraria cada clique neles por 300 ms.
    return Container(
      height: WindowManager.titleBarHeight,
      padding: const EdgeInsets.only(right: 4),
      color: context.palette.shadow.withValues(alpha: focused ? 0.3 : 0.45),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onDoubleTap: () => manager.toggleMaximize(window.id),
              onPanStart: (d) => manager.beginMove(window.id, d.globalPosition),
              onPanUpdate: (d) =>
                  manager.move(window.id, d.delta, pointer: d.globalPosition),
              onPanEnd: (_) => manager.endMove(window.id),
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  children: [
                    Icon(app.icon, size: 18, color: app.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        window.title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: focused
                              ? context.palette.text
                              : context.palette.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _button(context, Icons.remove, context.l10n.minimize, () {
            manager.minimize(window.id);
          }),
          _button(
            context,
            maximized ? Icons.filter_none : Icons.crop_square,
            maximized ? context.l10n.restore : context.l10n.maximize,
            () => manager.toggleMaximize(window.id),
          ),
          _button(
            context,
            Icons.close,
            context.l10n.close,
            () => manager.close(window.id),
          ),
        ],
      ),
    );
  }

  Widget _button(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return IconButton(
      icon: Icon(icon, size: 16),
      tooltip: tooltip,
      onPressed: onPressed,
      color: context.palette.textSecondary,
      visualDensity: VisualDensity.compact,
    );
  }
}
