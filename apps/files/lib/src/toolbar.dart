// apps/files/lib/src/toolbar.dart
//
// A barra de cima (voltar e avançar, o nome da pasta com o caminho num menu,
// os modos de ver, o menu de ações e a busca), as abas, e embaixo os
// trabalhos em andamento e a barra de status.
import 'package:psito_sdk/psito_sdk.dart';
import 'package:flutter/material.dart';
import 'package:psito_files_ui/psito_files_ui.dart';
import 'package:psito_fs/psito_fs.dart';

import 'controller.dart';
import 'env.dart';
import 'format.dart';
import 'items.dart';
import 'tab.dart';

import 'package:psito_files/l10n/l10n.dart';

class Toolbar extends StatelessWidget {
  final TextEditingController search;
  final FocusNode searchFocus;
  final VoidCallback? onToggleSidebar;

  const Toolbar({
    super.key,
    required this.search,
    required this.searchFocus,
    this.onToggleSidebar,
  });

  @override
  Widget build(BuildContext context) {
    final controller = FilesScope.of(context).controller;
    final tab = controller.tab;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 520;
        final medium = constraints.maxWidth >= 360;
        return Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          color: context.palette.shadow.withValues(alpha: 0.3),
          child: Row(
            children: [
              if (onToggleSidebar != null)
                _Button(
                  Icons.view_sidebar_outlined,
                  context.l10n.sidebar,
                  onToggleSidebar,
                ),
              _Button(
                Icons.chevron_left_rounded,
                context.l10n.back,
                tab.canGoBack ? tab.back : null,
              ),
              _Button(
                Icons.chevron_right_rounded,
                context.l10n.forward,
                tab.canGoForward ? tab.forward : null,
              ),
              const SizedBox(width: 4),
              Expanded(child: _Title(tab: tab)),
              if (medium && tab.location is TrashLocation)
                TextButton(
                  onPressed: tab.items.isEmpty
                      ? null
                      : controller.emptyTrashAsked,
                  child: Text(
                    context.l10n.empty,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              if (wide) _Modes(tab: tab),
              const _ActionsMenu(),
              if (medium)
                SizedBox(
                  width: wide ? 180 : 120,
                  child: _SearchField(controller: search, focus: searchFocus),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Button extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  const _Button(this.icon, this.tooltip, this.onPressed, {this.active = false});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 18),
    tooltip: tooltip,
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
    padding: EdgeInsets.zero,
    color: active
        ? Theme.of(context).colorScheme.primary
        : context.palette.textSecondary,
  );
}

/// O nome da pasta; o clique mostra o caminho até ela, como o Finder.
class _Title extends StatelessWidget {
  final FilesTab tab;

  const _Title({required this.tab});

  @override
  Widget build(BuildContext context) {
    final controller = FilesScope.of(context).controller;
    final env = controller.env;
    final folder = tab.folder;
    final ancestors = <String>[];
    if (folder != null) {
      for (var p = folder; ; p = dirName(p)) {
        ancestors.add(p);
        if (p == '/') break;
      }
    }
    final title = Text(
      tab.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
    );
    if (ancestors.length < 2 || tab.location is! FolderLocation) return title;
    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<String>(
        tooltip: folder,
        onSelected: (path) => tab.go(FolderLocation(path)),
        itemBuilder: (_) => [
          for (final path in ancestors.skip(1))
            PopupMenuItem(
              value: path,
              height: 32,
              child: Row(
                children: [
                  ThemedIcon(
                    [env.knownFolder(path)?.$1 ?? 'folder', 'folder'],
                    fallback: Icons.folder_rounded,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    env.knownFolder(path)?.$2 ?? baseName(path),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: title,
        ),
      ),
    );
  }
}

class _Modes extends StatelessWidget {
  final FilesTab tab;

  const _Modes({required this.tab});

  @override
  Widget build(BuildContext context) {
    final mode = tab.mode;
    final columns = tab.location is FolderLocation;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Button(
          Icons.grid_view_rounded,
          context.l10n.viewIconsTip,
          () => tab.setMode(ViewMode.icons),
          active: mode == ViewMode.icons,
        ),
        _Button(
          Icons.view_list_rounded,
          context.l10n.viewListTip,
          () => tab.setMode(ViewMode.list),
          active: mode == ViewMode.list,
        ),
        _Button(
          Icons.view_column_rounded,
          context.l10n.viewColumnsTip,
          columns ? () => tab.setMode(ViewMode.columns) : null,
          active: mode == ViewMode.columns,
        ),
      ],
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu();

  @override
  Widget build(BuildContext context) {
    final controller = FilesScope.of(context).controller;
    final tab = controller.tab;
    final config = controller.config;
    final sort = config.sort;
    final inFolder = tab.location is FolderLocation;
    Widget check(bool on, String label) => Row(
      children: [
        SizedBox(
          width: 22,
          child: on ? const Icon(Icons.check, size: 16) : null,
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          onPressed: inFolder ? controller.newFolder : null,
          shortcut: null,
          child: Text(context.l10n.newFolderTip),
        ),
        MenuItemButton(
          onPressed: () => controller.newTab(),
          child: Text(context.l10n.newTabTip),
        ),
        MenuItemButton(
          onPressed: controller.canUndo ? controller.undo : null,
          child: Text(
            controller.canUndo
                ? context.l10n.undoTooltip(controller.undoLabel!)
                : context.l10n.undoTip,
          ),
        ),
        const Divider(height: 8),
        SubmenuButton(
          menuChildren: [
            for (final (mode, label) in [
              (ViewMode.icons, context.l10n.viewIcons),
              (ViewMode.list, context.l10n.viewList),
              (ViewMode.columns, context.l10n.viewColumns),
            ])
              MenuItemButton(
                onPressed: mode == ViewMode.columns && !inFolder
                    ? null
                    : () => tab.setMode(mode),
                child: check(tab.mode == mode, label),
              ),
          ],
          child: Text(context.l10n.viewAs),
        ),
        SubmenuButton(
          menuChildren: [
            for (final (key, label) in [
              (FsSortKey.name, context.l10n.sortName),
              (FsSortKey.modified, context.l10n.sortModified),
              (FsSortKey.size, context.l10n.size),
              (FsSortKey.kind, context.l10n.kind),
            ])
              MenuItemButton(
                onPressed: () => config.setSort(sort.copyWith(key: key)),
                child: check(sort.key == key, label),
              ),
            const Divider(height: 8),
            MenuItemButton(
              onPressed: () =>
                  config.setSort(sort.copyWith(ascending: !sort.ascending)),
              child: check(!sort.ascending, context.l10n.reverseOrder),
            ),
            MenuItemButton(
              onPressed: () => config.setSort(
                sort.copyWith(foldersFirst: !sort.foldersFirst),
              ),
              child: check(sort.foldersFirst, context.l10n.foldersFirst),
            ),
          ],
          child: Text(context.l10n.sortBy),
        ),
        MenuItemButton(
          onPressed: () => config.setShowHidden(!config.showHidden),
          child: check(config.showHidden, context.l10n.showHiddenTip),
        ),
      ],
      builder: (context, menu, _) => _Button(
        Icons.more_horiz_rounded,
        context.l10n.actions,
        () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;

  const _SearchField({required this.controller, required this.focus});

  @override
  Widget build(BuildContext context) {
    final files = FilesScope.of(context).controller;
    final tab = files.tab;
    return TextField(
      controller: controller,
      focusNode: focus,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        isDense: true,
        hintText: context.l10n.search,
        prefixIcon: const Icon(Icons.search_rounded, size: 16),
        prefixIconConstraints: const BoxConstraints(minWidth: 28),
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        filled: true,
        fillColor: context.palette.shadow.withValues(alpha: 0.35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (text) {
        final query = text.trim();
        final location = tab.location;
        final root = location is SearchLocation
            ? location.root
            : tab.folder ?? files.env.home;
        if (query.isEmpty) {
          if (location is SearchLocation) tab.back();
          return;
        }
        // Cada letra troca a busca, sem encher o voltar
        tab.go(
          SearchLocation(root, query),
          record: location is! SearchLocation,
        );
      },
    );
  }
}

/// As abas, quando há mais de uma. Soltar arquivos numa aba leva para a
/// pasta dela.
class TabStrip extends StatelessWidget {
  const TabStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = FilesScope.of(context).controller;
    if (controller.tabs.length < 2) return const SizedBox.shrink();
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      height: 28,
      color: context.palette.shadow.withValues(alpha: 0.2),
      child: Row(
        children: [
          for (final (i, tab) in controller.tabs.indexed)
            Expanded(
              child: ListenableBuilder(
                listenable: tab,
                builder: (context, _) {
                  final active = i == controller.activeIndex;
                  final label = Row(
                    children: [
                      Expanded(
                        child: Text(
                          tab.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: active
                                ? context.palette.text
                                : context.palette.textQuiet,
                          ),
                        ),
                      ),
                      Tooltip(
                        message: context.l10n.close,
                        child: InkWell(
                          onTap: () => controller.closeTab(i),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: context.palette.textDisabled,
                          ),
                        ),
                      ),
                    ],
                  );
                  final body = InkWell(
                    onTap: () => controller.selectTab(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? context.palette.text.withValues(alpha: 0.08)
                            : null,
                        border: Border(
                          bottom: BorderSide(
                            color: active ? primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: label,
                    ),
                  );
                  final folder = tab.location is FolderLocation
                      ? tab.folder
                      : null;
                  return folder == null
                      ? body
                      : FolderDropTarget(path: folder, child: body);
                },
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 16),
            tooltip: context.l10n.newTabTip,
            visualDensity: VisualDensity.compact,
            onPressed: () => controller.newTab(),
          ),
        ],
      ),
    );
  }
}

/// Os trabalhos em andamento, com o progresso e o cancelar.
class JobsBar extends StatelessWidget {
  const JobsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = FilesScope.of(context).controller;
    if (controller.jobs.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final running in controller.jobs)
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: context.palette.shadow.withValues(alpha: 0.35),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    _jobText(context, running),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.palette.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: running.progress.totalItems == 0
                        ? null
                        : running.progress.fraction,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 14),
                  tooltip: context.l10n.cancel,
                  visualDensity: VisualDensity.compact,
                  onPressed: running.job.cancel,
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _jobText(BuildContext context, RunningJob running) {
    final l = context.l10n;
    final p = running.progress;
    final label = FilesUiLocalizations.of(context).jobLabel(running.job.kind);
    final what = p.current == null ? '' : ' "${p.current}"';
    final amount = p.totalBytes > 0
        ? ' ${l.jobAmount(formatSize(l, p.doneBytes), formatSize(l, p.totalBytes))}'
        : '';
    return '$label$what$amount';
  }
}

/// A contagem de itens e da seleção, e o tamanho dos ícones no modo ícones.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = FilesScope.of(context).controller;
    final tab = controller.tab;
    final config = controller.config;
    final selected = tab.selection.length;
    final l = context.l10n;
    final text = selected > 0
        ? l.itemsSelected(tab.items.length, selected)
        : l.itemCount(tab.items.length);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: context.palette.shadow.withValues(alpha: 0.25),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tab.searching ? l.statusSearching(text) : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: context.palette.textQuiet),
            ),
          ),
          if (tab.mode == ViewMode.icons)
            SizedBox(
              width: 120,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5,
                  ),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: config.iconSize,
                  min: FilesConfig.minIconSize,
                  max: FilesConfig.maxIconSize,
                  onChanged: config.setIconSize,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
