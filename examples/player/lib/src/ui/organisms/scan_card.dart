// examples/player/lib/src/ui/organisms/scan_card.dart
//
// A leitura em andamento: progresso, pasta atual, tempo restante, pausar, cancelar
// e os contadores.
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/library_controller.dart';
import '../../library/scanner.dart';
import '../atoms/tag_chip.dart';

class ScanCard extends StatelessWidget {
  final ScanProgress scan;

  /// O que falta, se já dá para estimar.
  final Duration? remaining;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  const ScanCard({
    super.key,
    required this.scan,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final folder = scan.currentFolder;
    final subtle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final left = remaining;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.scanning, style: theme.textTheme.titleSmall),
                      if (folder != null)
                        Text(
                          prettyPath(folder, Platform.environment['HOME']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: subtle,
                        ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(l.scanFiles(scan.done, scan.total)),
                        if (left != null)
                          Text(
                            left.inMinutes < 1
                                ? l.scanLessThanMinute
                                : l.scanMinutesLeft(left.inMinutes),
                            style: subtle,
                          ),
                      ],
                    ),
                    scan.paused
                        ? FilledButton.tonalIcon(
                            onPressed: onResume,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(l.resumeScan),
                          )
                        : FilledButton.tonalIcon(
                            onPressed: onPause,
                            icon: const Icon(Icons.pause_rounded),
                            label: Text(l.pauseScan),
                          ),
                    TextButton(onPressed: onCancel, child: Text(l.cancelScan)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              label: l.scanning,
              child: LinearProgressIndicator(
                value: scan.total == 0 ? null : scan.done / scan.total,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TagChip(
                  label: l.albumCount(scan.albums),
                  icon: Icons.album_rounded,
                ),
                TagChip(
                  label: l.trackCount(scan.tracks),
                  icon: Icons.music_note_rounded,
                ),
                TagChip(
                  label: l.coversFound(scan.covers),
                  icon: Icons.image_rounded,
                ),
                TagChip(
                  label: l.filesSkipped(scan.skipped),
                  icon: Icons.warning_amber_rounded,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l.scanKeepsGoing, style: subtle),
          ],
        ),
      ),
    );
  }
}
