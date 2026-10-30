// system_shell/lib/widgets/psito_dock.dart
import 'package:flutter/material.dart';

import 'package:psito_sdk/psito_sdk.dart';

class PsitoDock extends StatefulWidget {
  final List<PsitoApp> apps;
  final void Function(PsitoApp app) onAppTap;

  const PsitoDock({super.key, required this.apps, required this.onAppTap});

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
          double iconSize = isHovered ? 48.0 : 36.0;
          double containerSize = isHovered ? 64.0 : 52.0;

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
                  borderRadius: BorderRadius.circular(16),
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
                child: Center(
                  child: Icon(
                    app.icon,
                    size: iconSize * 0.75,
                    color: app.color,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
