// examples/player/lib/src/ui/templates/page_template.dart
//
// O desenho de toda tela: título, linha de resumo, ações, e o conteúdo rolando em
// slivers, para as listas grandes só construírem o que aparece.
import 'package:flutter/material.dart';

class PageTemplate extends StatelessWidget {
  static const padding = 16.0;

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Um voltar acima do título.
  final Widget? back;
  final List<Widget> slivers;

  const PageTemplate({
    super.key,
    required this.title,
    required this.slivers,
    this.subtitle,
    this.actions = const [],
    this.back,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(padding, padding, padding, 8),
          sliver: SliverToBoxAdapter(
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ?back,
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                if (actions.isNotEmpty)
                  Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ),
          ),
        ),
        for (final sliver in slivers)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: padding),
            sliver: sliver,
          ),
        const SliverToBoxAdapter(child: SizedBox(height: padding)),
      ],
    );
  }
}
