// examples/player/lib/src/ui/organisms/continue_card.dart
//
// O começo da tela Início: continuar de onde parou, e tudo em aleatório.
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/models.dart';
import '../atoms/cover_art.dart';
import '../format.dart';

class ContinueCard extends StatelessWidget {
  /// A faixa onde parou, ou null se não há o que continuar.
  final Track? track;
  final Duration position;
  final VoidCallback onContinue;
  final VoidCallback onShuffleAll;

  const ContinueCard({
    super.key,
    required this.track,
    required this.position,
    required this.onContinue,
    required this.onShuffleAll,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context);
    final track = this.track;
    final shuffle = FilledButton.tonalIcon(
      onPressed: onShuffleAll,
      icon: const Icon(Icons.shuffle_rounded),
      label: Text(l.shuffleAll),
    );
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (track != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CoverArt(
                      path: track.coverPath,
                      seed: '${track.album}|${track.artist}',
                      size: 56,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.continueListening.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                            ),
                          ),
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            l.stoppedAt(
                              artistName(track.artist, context),
                              formatDuration(position, locale),
                              formatDuration(track.duration, locale),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (track != null)
                  FilledButton.icon(
                    onPressed: onContinue,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(l.continuePlaying),
                  ),
                shuffle,
              ],
            ),
          ],
        ),
      ),
    );
  }
}
