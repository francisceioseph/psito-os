import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/l10n/l10n.dart';

class DesktopBackground extends StatelessWidget {
  final PsitoWallpaper wallpaper;

  const DesktopBackground({super.key, required this.wallpaper});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final colors = wallpaper.colors;

    return DecoratedBox(
      key: ValueKey('wallpaper-${wallpaper.id}'),
      decoration: BoxDecoration(
        color: colors.first,
        gradient: colors.length > 1
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              )
            : null,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              onTap: () {
                debugPrint('🦜 O Psito foi clicado!');
              },
              borderRadius: BorderRadius.circular(16),
              hoverColor: context.palette.lineSoft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Icon(Icons.flutter_dash, size: 120, color: accent),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Psito OS v0.0.1',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.tagline,
              style: TextStyle(fontSize: 16, color: context.palette.textQuiet),
            ),
          ],
        ),
      ),
    );
  }
}
