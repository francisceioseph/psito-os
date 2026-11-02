// examples/player/lib/src/ui/pages/empty_library_page.dart
//
// A biblioteca sem nenhuma pasta. Arrastar uma pasta para a janela ainda não dá:
// um app no sandbox não vê o que soltam nele (DECISOES.md, item 7c).
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/library_controller.dart';
import '../../library/scanner.dart';
import '../atoms/tag_chip.dart';

class EmptyLibraryPage extends StatelessWidget {
  /// A pasta de música da pessoa, se existe.
  final String? musicDir;
  final VoidCallback onAddFolder;
  final ValueChanged<String> onUseFolder;

  const EmptyLibraryPage({
    super.key,
    required this.onAddFolder,
    required this.onUseFolder,
    this.musicDir,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final music = musicDir;
    final formats = [for (final e in audioExtensions) e.substring(1)]..sort();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.library_music_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l.emptyTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(l.emptyBody, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: onAddFolder,
                    icon: const Icon(Icons.create_new_folder_rounded),
                    label: Text(l.addMusicFolder),
                  ),
                  if (music != null)
                    FilledButton.tonal(
                      onPressed: () => onUseFolder(music),
                      child: Text(
                        l.useFolder(
                          prettyPath(music, Platform.environment['HOME']),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(l.acceptedFormats, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  for (final format in formats)
                    TagChip(label: format.toUpperCase()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
