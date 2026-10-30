// system_shell/lib/widgets/window_switcher_overlay.dart
//
// Faixa do Alt+Tab / Ctrl+Tab: um cartão por janela, a escolhida em destaque.
import 'package:flutter/material.dart';

import '../shell/window_switcher.dart';

class WindowSwitcherOverlay extends StatelessWidget {
  final WindowSwitcher switcher;

  /// Clique num cartão: foca a janela e fecha o seletor.
  final ValueChanged<String> onPick;

  const WindowSwitcherOverlay({
    super.key,
    required this.switcher,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final selected = switcher.windows[switcher.index];
    return Center(
      child: Material(
        color: const Color(0xEE1E262A),
        borderRadius: BorderRadius.circular(20),
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final w in switcher.windows)
                    _Card(
                      key: ValueKey('switcher-${w.id}'),
                      icon: w.app.icon,
                      color: w.app.color,
                      minimized: w.minimized,
                      selected: w == selected,
                      accent: accent,
                      onTap: () => onPick(w.id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Text(
                  selected.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool minimized;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _Card({
    super.key,
    required this.icon,
    required this.color,
    required this.minimized,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Opacity(
          opacity: minimized ? 0.5 : 1,
          child: Icon(icon, size: 40, color: color),
        ),
      ),
    );
  }
}
