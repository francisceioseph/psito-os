// examples/player/lib/src/ui/pages/folders_page.dart
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/library_controller.dart';
import '../format.dart';
import '../molecules/folder_row.dart';
import '../organisms/scan_card.dart';
import '../templates/page_template.dart';

class FoldersPage extends StatelessWidget {
  final LibraryController library;
  final VoidCallback onAddFolder;

  const FoldersPage({
    super.key,
    required this.library,
    required this.onAddFolder,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context);
    final folders = library.folders;
    final totals = library.totals;
    final scan = library.scan;
    final now = DateTime.now().millisecondsSinceEpoch;
    return PageTemplate(
      title: l.folders,
      subtitle:
          '${l.folderCount(folders.length)} · '
          '${l.albumCount(totals.albums)} · '
          '${formatSize(totals.size, locale)}',
      actions: [
        FilledButton.tonalIcon(
          onPressed: library.scan == null && folders.isNotEmpty
              ? library.startScan
              : null,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l.updateAll),
        ),
        FilledButton.icon(
          onPressed: onAddFolder,
          icon: const Icon(Icons.create_new_folder_rounded),
          label: Text(l.addFolder),
        ),
      ],
      slivers: [
        if (scan != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ScanCard(
                scan: scan,
                remaining: library.scanRemaining,
                onPause: library.pauseScan,
                onResume: library.resumeScan,
                onCancel: library.cancelScan,
              ),
            ),
          ),
        SliverList.separated(
          itemCount: folders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => FolderRow(
            folder: folders[i],
            missing: library.missing.contains(folders[i].path),
            now: now,
            onUpdate: () => library.startScan([folders[i]]),
            onRemove: () => library.removeFolder(folders[i]),
          ),
        ),
      ],
    );
  }
}
