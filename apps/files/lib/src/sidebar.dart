// apps/files/lib/src/sidebar.dart
//
// A barra lateral do Finder: os Favoritos (o home, as pastas do usuário e as
// que o usuário arrastar para ali, na ordem que ele quiser), os Discos externos,
// os Locais (o computador) e a Lixeira. Soltar uma pasta no título dos Favoritos põe ela
// ali; soltar arquivos num favorito move para ele.
import 'dart:async';
import 'dart:io';

import 'package:psito_sdk/psito_sdk.dart';
import 'package:flutter/material.dart';
import 'package:psito_files_ui/psito_files_ui.dart';
import 'package:psito_fs/psito_fs.dart';

import 'format.dart';
import 'items.dart';
import 'tab.dart';

import 'package:psito_files/l10n/l10n.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  static const width = 180.0;

  @override
  Widget build(BuildContext context) {
    final controller = FilesScope.of(context).controller;
    final config = controller.config;
    final tab = controller.tab;
    final env = controller.env;
    final current = tab.location;
    bool isCurrent(String path) =>
        current is FolderLocation && current.path == path;

    return Container(
      width: width,
      color: context.palette.shadow.withValues(alpha: 0.25),
      child: ListenableBuilder(
        listenable: config,
        builder: (context, _) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: DragTarget<DragFiles>(
                onWillAcceptWithDetails: (d) => d.data.paths.any(_isFolder),
                onAcceptWithDetails: (d) {
                  for (final path in d.data.paths.where(_isFolder)) {
                    config.addFavorite(path);
                  }
                },
                builder: (context, candidates, _) => _Section(
                  context.l10n.favorites,
                  highlight: candidates.isNotEmpty,
                ),
              ),
            ),
            SliverReorderableList(
              itemCount: config.favorites.length,
              onReorderItem: config.moveFavorite,
              itemBuilder: (context, i) {
                final path = config.favorites[i];
                final known = env.knownFolder(path);
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(path),
                  index: i,
                  child: FolderDropTarget(
                    path: path,
                    child: _Item(
                      icon: [known?.$1 ?? 'folder', 'folder'],
                      fallback: Icons.folder_rounded,
                      label: known?.$2 ?? baseName(path),
                      selected: isCurrent(path),
                      onTap: () => tab.go(FolderLocation(path)),
                      menu: [
                        PopupMenuItem(
                          onTap: () => config.removeFavorite(path),
                          child: Text(context.l10n.removeFromSidebar),
                        ),
                        PopupMenuItem(
                          onTap: () => controller.newTab(FolderLocation(path)),
                          child: Text(context.l10n.openInNewTab),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(
              child: ValueListenableBuilder(
                valueListenable: controller.volumes.volumes,
                builder: (context, volumes, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (volumes.isNotEmpty) _Section(context.l10n.volumes),
                    for (final volume in volumes) _volume(context, volume),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: _Section(context.l10n.places)),
            SliverToBoxAdapter(
              child: FolderDropTarget(
                path: '/',
                child: _Item(
                  icon: const ['drive-harddisk', 'computer'],
                  fallback: Icons.computer_rounded,
                  label: context.l10n.placeComputer,
                  selected: isCurrent('/'),
                  onTap: () => tab.go(const FolderLocation('/')),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: DragTarget<DragFiles>(
                onWillAcceptWithDetails: (d) => current is! TrashLocation,
                onAcceptWithDetails: (d) =>
                    controller.moveToTrash(d.data.paths),
                builder: (context, candidates, _) => _Item(
                  icon: const ['user-trash'],
                  fallback: Icons.delete_outline_rounded,
                  label: context.l10n.placeTrash,
                  selected: current is TrashLocation,
                  highlight: candidates.isNotEmpty,
                  onTap: () => tab.go(const TrashLocation()),
                  menu: [
                    PopupMenuItem(
                      onTap: controller.emptyTrashAsked,
                      child: Text(context.l10n.emptyTrashEllipsis),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _volume(BuildContext context, PsitoVolume volume) {
    final controller = FilesScope.of(context).controller;
    final mount = volume.mountPoint;
    final current = controller.tab.location;
    final item = _Item(
      key: ValueKey('volume-${volume.id}'),
      icon: const ['drive-removable-media', 'drive-harddisk'],
      fallback: Icons.usb_rounded,
      label: volume.label.isNotEmpty
          ? volume.label
          : context.l10n.volumeUnnamed(formatSize(context.l10n, volume.size)),
      selected: current is FolderLocation && current.path == mount,
      onTap: () => unawaited(controller.openVolume(volume)),
      trailing: volume.canEject && !volume.locked
          ? IconButton(
              key: ValueKey('eject-${volume.id}'),
              tooltip: context.l10n.volumeEject,
              icon: const Icon(Icons.eject_rounded, size: 14),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: EdgeInsets.zero,
              color: context.palette.textSecondary,
              onPressed: () => unawaited(controller.ejectVolume(volume)),
            )
          : null,
    );
    return mount == null ? item : FolderDropTarget(path: mount, child: item);
  }

  static bool _isFolder(String path) => FileSystemEntity.isDirectorySync(path);
}

class _Section extends StatelessWidget {
  final String title;
  final bool highlight;

  const _Section(this.title, {this.highlight = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
    color: highlight
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
        : null,
    child: Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: context.palette.textDisabled,
      ),
    ),
  );
}

class _Item extends StatelessWidget {
  final List<String> icon;
  final IconData fallback;
  final String label;
  final bool selected;
  final bool highlight;
  final VoidCallback onTap;
  final List<PopupMenuEntry<void>> menu;

  /// Junto da linha, à direita.
  final Widget? trailing;

  const _Item({
    super.key,
    required this.icon,
    required this.fallback,
    required this.label,
    required this.selected,
    required this.onTap,
    this.highlight = false,
    this.menu = const [],
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return MergeSemantics(
      child: GestureDetector(
        onSecondaryTapDown: menu.isEmpty
            ? null
            : (d) => showMenu<void>(
                context: context,
                position: RelativeRect.fromLTRB(
                  d.globalPosition.dx,
                  d.globalPosition.dy,
                  d.globalPosition.dx,
                  d.globalPosition.dy,
                ),
                items: menu,
              ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: selected
                    ? context.palette.text.withValues(alpha: 0.12)
                    : highlight
                    ? primary.withValues(alpha: 0.25)
                    : null,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  ThemedIcon(
                    icon,
                    fallback: fallback,
                    size: 16,
                    color: primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.palette.text,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
