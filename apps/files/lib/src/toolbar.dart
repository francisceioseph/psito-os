// apps/files/lib/src/toolbar.dart
//
// A barra de cima (voltar e avançar, o nome da pasta com o caminho num menu,
// os modos de ver, o menu de ações e a busca), as abas, e embaixo os
// trabalhos em andamento e a barra de status.
import 'package:flutter/material.dart';
import 'package:psito_fs/psito_fs.dart';

import 'controller.dart';
import 'env.dart';
import 'file_icon.dart';
import 'format.dart';
import 'items.dart';
import 'tab.dart';

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
          color: Colors.black.withValues(alpha: 0.3),
          child: Row(
            children: [
              if (onToggleSidebar != null)
                _Button(
                  Icons.view_sidebar_outlined,
                  'Barra lateral',
                  onToggleSidebar,
                ),
              _Button(
                Icons.chevron_left_rounded,
                'Voltar (Alt+←)',
                tab.canGoBack ? tab.back : null,
              ),
              _Button(
                Icons.chevron_right_rounded,
                'Avançar (Alt+→)',
                tab.canGoForward ? tab.forward : null,
              ),
              const SizedBox(width: 4),
              Expanded(child: _Title(tab: tab)),
              if (medium && tab.location is TrashLocation)
                TextButton(
                  onPressed: tab.items.isEmpty
                      ? null
                      : controller.emptyTrashAsked,
                  child: const Text('Esvaziar', style: TextStyle(fontSize: 12)),
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
    color: active ? Theme.of(context).colorScheme.primary : Colors.white70,
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
          'Ícones (Ctrl+1)',
          () => tab.setMode(ViewMode.icons),
          active: mode == ViewMode.icons,
        ),
        _Button(
          Icons.view_list_rounded,
          'Lista (Ctrl+2)',
          () => tab.setMode(ViewMode.list),
          active: mode == ViewMode.list,
        ),
        _Button(
          Icons.view_column_rounded,
          'Colunas (Ctrl+3)',
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
          child: const Text('Nova pasta (Ctrl+Shift+N)'),
        ),
        MenuItemButton(
          onPressed: () => controller.newTab(),
          child: const Text('Nova aba (Ctrl+T)'),
        ),
        MenuItemButton(
          onPressed: controller.canUndo ? controller.undo : null,
          child: Text(
            controller.canUndo
                ? 'Desfazer ${controller.undoLabel} (Ctrl+Z)'
                : 'Desfazer (Ctrl+Z)',
          ),
        ),
        const Divider(height: 8),
        SubmenuButton(
          menuChildren: [
            for (final (mode, label) in [
              (ViewMode.icons, 'Ícones'),
              (ViewMode.list, 'Lista'),
              (ViewMode.columns, 'Colunas'),
            ])
              MenuItemButton(
                onPressed: mode == ViewMode.columns && !inFolder
                    ? null
                    : () => tab.setMode(mode),
                child: check(tab.mode == mode, label),
              ),
          ],
          child: const Text('Ver como'),
        ),
        SubmenuButton(
          menuChildren: [
            for (final (key, label) in [
              (FsSortKey.name, 'Nome'),
              (FsSortKey.modified, 'Data de modificação'),
              (FsSortKey.size, 'Tamanho'),
              (FsSortKey.kind, 'Tipo'),
            ])
              MenuItemButton(
                onPressed: () => config.setSort(sort.copyWith(key: key)),
                child: check(sort.key == key, label),
              ),
            const Divider(height: 8),
            MenuItemButton(
              onPressed: () =>
                  config.setSort(sort.copyWith(ascending: !sort.ascending)),
              child: check(!sort.ascending, 'Ordem inversa'),
            ),
            MenuItemButton(
              onPressed: () => config.setSort(
                sort.copyWith(foldersFirst: !sort.foldersFirst),
              ),
              child: check(sort.foldersFirst, 'Pastas primeiro'),
            ),
          ],
          child: const Text('Ordenar por'),
        ),
        MenuItemButton(
          onPressed: () => config.setShowHidden(!config.showHidden),
          child: check(config.showHidden, 'Mostrar ocultos (Ctrl+H)'),
        ),
      ],
      builder: (context, menu, _) => _Button(
        Icons.more_horiz_rounded,
        'Ações',
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
        hintText: 'Buscar',
        prefixIcon: const Icon(Icons.search_rounded, size: 16),
        prefixIconConstraints: const BoxConstraints(minWidth: 28),
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.35),
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
      color: Colors.black.withValues(alpha: 0.2),
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
                            color: active ? Colors.white : Colors.white54,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => controller.closeTab(i),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.white38,
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
                            ? Colors.white.withValues(alpha: 0.08)
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
            tooltip: 'Nova aba (Ctrl+T)',
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
            color: Colors.black.withValues(alpha: 0.35),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    _jobText(running),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
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
                  tooltip: 'Cancelar',
                  visualDensity: VisualDensity.compact,
                  onPressed: running.job.cancel,
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _jobText(RunningJob running) {
    final p = running.progress;
    final what = p.current == null ? '' : ' "${p.current}"';
    final amount = p.totalBytes > 0
        ? ' (${formatSize(p.doneBytes)} de ${formatSize(p.totalBytes)})'
        : '';
    return '${running.label}$what$amount';
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
    final text = selected > 0
        ? '$selected de ${formatCount(tab.items.length, 'item', 'itens')} selecionados'
        : formatCount(tab.items.length, 'item', 'itens');
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.black.withValues(alpha: 0.25),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tab.searching ? '$text, buscando...' : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
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
