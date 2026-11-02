import 'package:flutter/widgets.dart';
import 'package:psito_sdk/psito_sdk.dart';

class DesktopBackground extends StatelessWidget {
  final PsitoWallpaper wallpaper;

  const DesktopBackground({super.key, required this.wallpaper});

  @override
  Widget build(BuildContext context) => PsitoWallpaperView(
    key: ValueKey('wallpaper-${wallpaper.id}'),
    wallpaper: wallpaper,
  );
}
