// examples/player/lib/src/ui/molecules/dir_row.dart
//
// Uma pasta com música, numa lista: abre as faixas dela.
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/library_controller.dart';
import '../../library/models.dart';

class DirRow extends StatelessWidget {
  static const height = 64.0;

  final MusicDir dir;
  final VoidCallback onOpen;

  const DirRow({super.key, required this.dir, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final path = prettyPath(dir.path, Platform.environment['HOME']);
    return Semantics(
      button: true,
      label: path,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(Icons.folder_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        '${l.albumCount(dir.albums)} · ${l.fileCount(dir.tracks)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
