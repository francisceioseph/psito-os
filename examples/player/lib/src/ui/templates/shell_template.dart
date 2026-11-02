// examples/player/lib/src/ui/templates/shell_template.dart
//
// A janela: a navegação, o conteúdo, o painel ao lado e a barra do player, que dá
// lugar ao painel. Decide o que cabe, até o mínimo de 240x160 do Psito, em que só a
// barra fica.
import 'package:flutter/material.dart';

class ShellTemplate extends StatelessWidget {
  /// A partir daqui, a barra lateral. Abaixo, a navegação compacta.
  static const railMinWidth = 560.0;
  static const railMinHeight = 560.0;

  /// Abaixo desta altura, a barra do player ocupa tudo.
  static const contentMinHeight = 260.0;

  /// A partir daqui, o painel fica ao lado do conteúdo. Abaixo, no lugar dele.
  static const panelSideMinWidth = 900.0;
  static const panelWidth = 340.0;

  final Widget rail;
  final Widget compactNav;
  final Widget content;

  /// O painel ao lado, ou null fechado.
  final Widget? panel;
  final Widget bar;

  const ShellTemplate({
    super.key,
    required this.rail,
    required this.compactNav,
    required this.content,
    required this.bar,
    this.panel,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final showContent = c.maxHeight >= contentMinHeight;
      final showRail =
          c.maxWidth >= railMinWidth && c.maxHeight >= railMinHeight;
      final panel = this.panel;
      final panelBeside = panel != null && c.maxWidth >= panelSideMinWidth;
      return Row(
        children: [
          if (showRail) rail,
          Expanded(
            child: Column(
              children: [
                if (showContent) ...[
                  if (!showRail) compactNav,
                  Expanded(
                    child: panel == null || panelBeside ? content : panel,
                  ),
                ] else
                  const Spacer(),
                if (panel == null || !showContent) bar,
              ],
            ),
          ),
          if (showContent && panelBeside)
            SizedBox(width: panelWidth, child: panel),
        ],
      );
    },
  );
}
