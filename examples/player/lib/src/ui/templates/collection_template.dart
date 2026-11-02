// examples/player/lib/src/ui/templates/collection_template.dart
//
// A tela de uma coleção de faixas (álbum, artista, gênero, pasta, playlist): voltar,
// a arte ao lado dos dados, e o conteúdo.
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import 'page_template.dart';

class CollectionTemplate extends StatelessWidget {
  /// A partir desta largura, a arte fica ao lado dos dados.
  static const artMinWidth = 420.0;
  static const artSize = 180.0;

  final String title;
  final VoidCallback onBack;
  final Widget art;
  final Widget details;
  final List<Widget> slivers;

  const CollectionTemplate({
    super.key,
    required this.title,
    required this.onBack,
    required this.art,
    required this.details,
    required this.slivers,
  });

  @override
  Widget build(BuildContext context) => PageTemplate(
    title: title,
    back: TextButton.icon(
      onPressed: onBack,
      icon: const Icon(Icons.arrow_back_rounded),
      label: Text(context.l10n.back),
    ),
    slivers: [
      SliverToBoxAdapter(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < artMinWidth) return details;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: artSize, height: artSize, child: art),
                const SizedBox(width: 20),
                Expanded(child: details),
              ],
            );
          },
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ...slivers,
    ],
  );
}
