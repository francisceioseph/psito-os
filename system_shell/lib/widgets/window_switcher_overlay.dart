// system_shell/lib/widgets/window_switcher_overlay.dart
//
// Faixa do Alt+Tab / Ctrl+Tab: um cartão por janela, a escolhida em destaque.
import 'package:psito_sdk/psito_sdk.dart';
import 'package:flutter/material.dart';

import '../shell/app_entry.dart';
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
        color: context.palette.panelGlass,
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
                      app: w.app,
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.palette.text,
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
  final AppEntry app;
  final bool minimized;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _Card({
    super.key,
    required this.app,
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
              : context.palette.text.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Opacity(
          opacity: minimized ? 0.5 : 1,
          child: Center(child: app.icon(40)),
        ),
      ),
    );
  }
}
