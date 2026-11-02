// examples/player/lib/src/ui/molecules/track_row.dart
//
// Uma faixa numa lista, com 56 px: o começo (o número ou a capa), título e artista,
// formato, letra, duração e o menu. Quanto menos largura, menos colunas.
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/models.dart';
import '../atoms/tag_chip.dart';
import '../format.dart';

class TrackRow extends StatelessWidget {
  /// Abaixo disto, ficam só o título e o que vem depois dele.
  static const detailsMinWidth = 420.0;

  final Track track;

  /// O começo da linha.
  final Widget? leading;

  /// É a faixa que está tocando.
  final bool current;
  final VoidCallback onTap;

  /// O que o menu oferece, ou null sem menu.
  final PopupMenuItemBuilder<VoidCallback>? menu;

  /// O botão de depois do menu, como tirar da fila.
  final Widget? trailing;

  const TrackRow({
    super.key,
    required this.track,
    required this.onTap,
    this.leading,
    this.current = false,
    this.menu,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context);
    final artist = artistName(track.artist, context);
    final foreground = current ? scheme.onPrimaryContainer : scheme.onSurface;
    return Material(
      color: current ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final details = constraints.maxWidth >= detailsMinWidth;
                return Row(
                  children: [
                    if (leading != null) ...[
                      SizedBox(width: 40, child: Center(child: leading)),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: '${track.title}, $artist',
                        excludeSemantics: true,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: foreground,
                              ),
                            ),
                            Text(
                              artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: current
                                    ? foreground
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (details) ...[
                      if (track.hasLyrics)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Tooltip(
                            message: l.hasLyrics,
                            child: Icon(
                              Icons.lyrics_rounded,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      if (track.format.isNotEmpty) TagChip(label: track.format),
                      SizedBox(
                        width: 56,
                        child: Text(
                          formatDuration(track.duration, locale),
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: foreground,
                          ),
                        ),
                      ),
                    ],
                    if (menu != null)
                      PopupMenuButton<VoidCallback>(
                        tooltip: l.moreOptions,
                        icon: const Icon(Icons.more_vert_rounded),
                        itemBuilder: menu!,
                        onSelected: (action) => action(),
                      ),
                    ?trailing,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
