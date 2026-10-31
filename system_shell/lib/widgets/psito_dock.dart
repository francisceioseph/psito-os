// system_shell/lib/widgets/psito_dock.dart
import 'package:flutter/material.dart';

import '../shell/app_entry.dart';

class PsitoDock extends StatefulWidget {
  final List<AppEntry> apps;

  /// Apps com pelo menos uma janela aberta: ganham um ponto embaixo do ícone.
  final Set<String> runningAppIds;
  final void Function(AppEntry app) onAppTap;

  /// O lado de cada ícone (o `dockIconSize` das configurações).
  final double iconSize;

  /// O ícone sob o mouse cresce.
  final bool magnification;

  const PsitoDock({
    super.key,
    required this.apps,
    this.runningAppIds = const {},
    required this.onAppTap,
    this.iconSize = 52,
    this.magnification = true,
  });

  @override
  State<PsitoDock> createState() => _PsitoDockState();
}

class _PsitoDockState extends State<PsitoDock> {
  // Índice do item com foco do mouse (-1 se nenhum)
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.apps.length, (index) {
          final app = widget.apps[index];
          final isHovered = _hoveredIndex == index;

          // Efeito de zoom estilo macOS (aumenta o ícone se o mouse estiver em cima)
          final containerSize = isHovered && widget.magnification
              ? widget.iconSize * 1.25
              : widget.iconSize;

          return MouseRegion(
            onEnter: (_) => setState(() => _hoveredIndex = index),
            onExit: (_) => setState(() => _hoveredIndex = null),
            child: GestureDetector(
              onTap: () => widget.onAppTap(app),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: containerSize,
                height: containerSize,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: app.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(containerSize * 0.3),
                  border: Border.all(
                    color: isHovered ? app.color : Colors.white24,
                    width: isHovered ? 2.0 : 1.0,
                  ),
                  boxShadow: isHovered
                      ? [
                          BoxShadow(
                            color: app.color.withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    app.icon(containerSize * 0.55),
                    if (widget.runningAppIds.contains(app.id))
                      Positioned(
                        bottom: containerSize * 0.06,
                        child: Container(
                          key: ValueKey('running-${app.id}'),
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: app.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
