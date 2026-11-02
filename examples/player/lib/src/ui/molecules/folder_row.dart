// examples/player/lib/src/ui/molecules/folder_row.dart
//
// Uma pasta da biblioteca: caminho, contagens, situação, atualizar e remover.
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/library_controller.dart';
import '../../library/models.dart';
import '../atoms/tag_chip.dart';
import '../format.dart';

/// Quando a leitura foi, em relação a agora.
String scannedAgo(int? at, int now, BuildContext context) {
  final l = context.l10n;
  if (at == null) return l.notScanned;
  final elapsed = Duration(milliseconds: now - at);
  if (elapsed.inMinutes < 1) return l.scannedJustNow;
  if (elapsed.inHours < 1) return l.scannedMinutes(elapsed.inMinutes);
  if (elapsed.inDays < 1) return l.scannedHours(elapsed.inHours);
  return l.scannedDays(elapsed.inDays);
}

class FolderRow extends StatelessWidget {
  /// Abaixo disto, a situação sai da linha.
  static const statusMinWidth = 560.0;

  final MusicFolder folder;
  final bool missing;

  /// O que mudou na pasta e ainda não foi lido.
  final int changes;
  final int now;
  final VoidCallback onUpdate;
  final VoidCallback onRemove;

  const FolderRow({
    super.key,
    required this.folder,
    required this.missing,
    this.changes = 0,
    required this.now,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context);
    final path = prettyPath(folder.path, Platform.environment['HOME']);
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Icon(
                missing ? Icons.folder_off_rounded : Icons.folder_rounded,
                color: missing ? scheme.error : scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      '${l.albumCount(folder.albums)} · '
                      '${l.trackCount(folder.tracks)} · '
                      '${formatSize(folder.size, locale)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (constraints.maxWidth >= statusMinWidth) ...[
                const SizedBox(width: 8),
                missing
                    ? TagChip(
                        label: l.folderMissing,
                        icon: Icons.warning_rounded,
                        warning: true,
                      )
                    : changes > 0
                    ? TagChip(
                        label: l.folderChanges(changes),
                        icon: Icons.fiber_new_rounded,
                        warning: true,
                      )
                    : TagChip(
                        label: scannedAgo(folder.scannedAt, now, context),
                        icon: Icons.check_circle_outline_rounded,
                      ),
              ],
              IconButton(
                tooltip: l.updateFolder,
                icon: const Icon(Icons.refresh_rounded),
                onPressed: onUpdate,
              ),
              PopupMenuButton<VoidCallback>(
                tooltip: l.moreOptions,
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (action) => action(),
                itemBuilder: (_) => [
                  PopupMenuItem(value: onRemove, child: Text(l.removeFolder)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
