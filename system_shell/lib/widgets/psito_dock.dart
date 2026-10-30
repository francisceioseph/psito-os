// system_shell/lib/widgets/psito_dock.dart
import 'package:flutter/material.dart';

import '../models/psito_app_item.dart';

class PsitoDock extends StatefulWidget {
  final Function(PsitoAppItem app) onAppTap;

  const PsitoDock({super.key, required this.onAppTap});

  @override
  State<PsitoDock> createState() => _PsitoDockState();
}

class _PsitoDockState extends State<PsitoDock> {
  // Índice do item com foco do mouse (-1 se nenhum)
  int? _hoveredIndex;

  final List<PsitoAppItem> _apps = const [
    PsitoAppItem(
      id: 'buddy',
      name: 'Psito Buddy',
      icon: Icons.smart_toy_rounded,
      color: Color(0xFFFF5722), // Laranja bochecha
    ),
    PsitoAppItem(
      id: 'calculator',
      name: 'Calculator',
      icon: Icons.calculate_outlined,
      color: Color(0xFF2196F3), // Azul
    ),
    PsitoAppItem(
      id: 'clock',
      name: 'Clock',
      icon: Icons.access_time_rounded,
      color: Color(0xFFFF9800), // Laranja
    ),
    PsitoAppItem(
      id: 'notepad',
      name: 'Notepad',
      icon: Icons.edit_note_rounded,
      color: Color(0xFF4CAF50), // Verde
    ),
    PsitoAppItem(
      id: 'files',
      name: 'Files',
      icon: Icons.folder_open_rounded,
      color: Color(0xFFFFC107), // Amarelo Calopsita
    ),
    PsitoAppItem(
      id: 'browser',
      name: 'Browser',
      icon: Icons.language_rounded,
      color: Color(0xFF00BCD4), // Ciano moderno
    ),
  ];

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
        children: List.generate(_apps.length, (index) {
          final app = _apps[index];
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
