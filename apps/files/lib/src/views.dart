// apps/files/lib/src/views.dart
//
// Os três modos de ver uma pasta, como no Finder: ícones (a grade, com o
// tamanho regulável), lista (as colunas ordenáveis, com as pastas abrindo em
// árvore) e colunas (as colunas de Miller, com a pré-visualização no fim).
// No fundo: soltar arquivos na pasta, o menu de contexto e o retângulo de
// seleção.
import 'package:flutter/gestures.dart'
    show kPrimaryButton, kSecondaryMouseButton;
import 'package:psito_sdk/psito_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:psito_files_ui/psito_files_ui.dart';
import 'package:psito_fs/psito_fs.dart';

import 'env.dart';
import 'format.dart';
import 'items.dart';
import 'tab.dart';

import 'package:psito_files/l10n/l10n.dart';

/// O conteúdo da aba no modo dela, ou o estado (carregando, erro, vazia).
class FolderContent extends StatelessWidget {
  final FilesTab tab;

  const FolderContent({super.key, required this.tab});

  @override
  Widget build(BuildContext context) {
    final mode = tab.mode;
    if (tab.error != null) return _Message(tab.error!, error: true);
    if (tab.items.isEmpty && !tab.loading && mode != ViewMode.columns) {
      return _Background(
        tab: tab,
        child: _Message(switch (tab.location) {
          TrashLocation() => context.l10n.emptyTrashFolder,
          SearchLocation() when tab.searching => context.l10n.searching,
          SearchLocation() => context.l10n.nothingFound,
          FolderLocation() => context.l10n.emptyFolder,
        }),
      );
    }
    return switch (mode) {
      ViewMode.icons => IconsView(tab: tab),
      ViewMode.list => ListModeView(tab: tab),
      ViewMode.columns => ColumnsView(tab: tab),
    };
  }
}

class _Message extends StatelessWidget {
  final String text;
  final bool error;

  const _Message(this.text, {this.error = false});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: error ? context.palette.danger : context.palette.textDisabled,
        ),
      ),
    ),
  );
}

/// O fundo de uma vista: clicar limpa a seleção, o botão direito abre o menu
/// da pasta, soltar arquivos traz para a pasta, e arrastar desenha o
/// retângulo de seleção ([hits] diz quais itens ele cobre, nas coordenadas
/// do conteúdo).
class _Background extends StatefulWidget {
  final FilesTab tab;
  final Widget child;
  final Iterable<String> Function(Rect rect)? hits;
  final ScrollController? scroll;

  const _Background({
    required this.tab,
    required this.child,
    this.hits,
    this.scroll,
  });

  @override
  State<_Background> createState() => _BackgroundState();
}

class _BackgroundState extends State<_Background> {
  Offset? _start;
  Offset? _end;
  Set<String> _base = const {};

  double get _offset =>
      (widget.scroll?.hasClients ?? false) ? widget.scroll!.offset : 0;

  Rect? get _rect {
    final start = _start, end = _end;
    if (start == null || end == null) return null;
    return Rect.fromPoints(start, end.translate(0, _offset));
  }

  @override
  Widget build(BuildContext context) {
    final scope = FilesScope.of(context);
    final folder = widget.tab.location is FolderLocation
        ? widget.tab.folder
        : null;
    final controller = scope.controller;
    Widget content = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.pointer == controller.claimedPointer) return;
        if (event.buttons == kSecondaryMouseButton) {
          widget.tab.clearSelection();
          scope.showMenu(event.position, null);
        } else if (!HardwareKeyboard.instance.isControlPressed) {
          widget.tab.clearSelection();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: widget.hits == null
            ? null
            : (d) {
                _base = HardwareKeyboard.instance.isControlPressed
                    ? {...widget.tab.selection}
                    : const {};
                setState(() {
                  _start = d.localPosition.translate(0, _offset);
                  _end = d.localPosition;
                });
              },
        onPanUpdate: widget.hits == null
            ? null
            : (d) {
                setState(() => _end = d.localPosition);
                final rect = _rect;
                if (rect != null) {
                  widget.tab.selectPaths(widget.hits!(rect), base: _base);
                }
              },
        onPanEnd: (_) => setState(() => _start = _end = null),
        onPanCancel: () => setState(() => _start = _end = null),
        child: Stack(
          children: [
            Positioned.fill(child: widget.child),
            if (_rect case final rect?)
              Positioned.fromRect(
                rect: rect.translate(0, -_offset),
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.15),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (folder != null) {
      content = FolderDropTarget(
        path: folder,
        highlight: false,
        child: content,
      );
    }
    return content;
  }
}

// Ícones

class IconsView extends StatefulWidget {
  final FilesTab tab;

  const IconsView({super.key, required this.tab});

  /// Quantas colunas a grade tem numa largura (para as setas de cima e de
  /// baixo andarem uma linha).
  static int columnsFor(double width, double iconSize) =>
      ((width - 2 * _padding) / tileWidth(iconSize)).floor().clamp(1, 1000);

  static double tileWidth(double iconSize) => iconSize + 48;
  static double tileHeight(double iconSize) => iconSize + 44;
  static const _padding = 8.0;

  @override
  State<IconsView> createState() => _IconsViewState();
}

class _IconsViewState extends State<IconsView> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = FilesScope.of(context).controller;
    final tab = widget.tab;
    final size = controller.config.iconSize;
    final tileW = IconsView.tileWidth(size), tileH = IconsView.tileHeight(size);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = IconsView.columnsFor(constraints.maxWidth, size);
        // Os itens sob o retângulo, pela conta da grade
        Iterable<String> hits(Rect rect) sync* {
          for (final (i, e) in tab.items.indexed) {
            final r = Rect.fromLTWH(
              IconsView._padding + (i % columns) * tileW,
              IconsView._padding + (i ~/ columns) * tileH,
              tileW,
              tileH,
            ).deflate(6);
            if (r.overlaps(rect)) yield e.path;
          }
        }

        return _Background(
          tab: tab,
          hits: hits,
          scroll: _scroll,
          child: GridView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(IconsView._padding),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: tileH,
              childAspectRatio: 1,
            ),
            itemCount: tab.items.length,
            itemBuilder: (context, i) {
              final entry = tab.items[i];
              return SizedBox(
                width: tileW,
                child: _IconTile(
                  entry: entry,
                  tab: tab,
                  size: size,
                  cut:
                      controller.clipboardCut &&
                      controller.clipboard.contains(entry.path),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _IconTile extends StatelessWidget {
  final FsEntry entry;
  final FilesTab tab;
  final double size;
  final bool cut;

  const _IconTile({
    required this.entry,
    required this.tab,
    required this.size,
    required this.cut,
  });

  @override
  Widget build(BuildContext context) {
    final env = FilesScope.of(context).controller.env;
    final selected = tab.selection.contains(entry.path);
    final renaming = tab.renaming == entry.path;
    return ItemGestures(
      entry: entry,
      feedbackSize: size,
      child: Opacity(
        opacity: cut || entry.hidden ? 0.5 : 1,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: selectionDecoration(context, selected),
                child: FileIcon(entry: entry, env: env, size: size),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: renaming
                    ? EntryRenameField(
                        entry: entry,
                        textAlign: TextAlign.center,
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: selected
                                ? context.palette.shadow
                                : context.palette.text,
                            fontStyle: entry.isLink
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Lista

enum _ListColumn { name, modified, size, kind, where }

class ListModeView extends StatefulWidget {
  final FilesTab tab;

  const ListModeView({super.key, required this.tab});

  static const rowHeight = 26.0;

  @override
  State<ListModeView> createState() => _ListModeViewState();
}

class _ListModeViewState extends State<ListModeView> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// As colunas que cabem na largura; a lixeira e a busca mostram de onde
  /// cada item é.
  List<_ListColumn> _columns(double width) {
    final where = widget.tab.location is! FolderLocation;
    return [
      _ListColumn.name,
      if (width >= 420) _ListColumn.modified,
      if (width >= 320) _ListColumn.size,
      if (width >= 540) where ? _ListColumn.where : _ListColumn.kind,
    ];
  }

  static double _width(_ListColumn c) => switch (c) {
    _ListColumn.name => 0,
    _ListColumn.modified => 150,
    _ListColumn.size => 80,
    _ListColumn.kind || _ListColumn.where => 150,
  };

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columns(constraints.maxWidth);
        final rows = tab.treeRows;
        Iterable<String> hits(Rect rect) sync* {
          for (final (i, (e, _)) in rows.indexed) {
            final top = i * ListModeView.rowHeight;
            if (top < rect.bottom && top + ListModeView.rowHeight > rect.top) {
              yield e.path;
            }
          }
        }

        return Column(
          children: [
            _Header(tab: tab, columns: columns),
            Expanded(
              child: _Background(
                tab: tab,
                hits: hits,
                scroll: _scroll,
                child: ListView.builder(
                  controller: _scroll,
                  itemExtent: ListModeView.rowHeight,
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final (entry, depth) = rows[i];
                    return _ListRow(
                      entry: entry,
                      depth: depth,
                      tab: tab,
                      columns: columns,
                      odd: i.isOdd,
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final FilesTab tab;
  final List<_ListColumn> columns;

  const _Header({required this.tab, required this.columns});

  @override
  Widget build(BuildContext context) {
    final config = FilesScope.of(context).controller.config;
    final sort = config.sort;
    Widget cell(_ListColumn c) {
      final key = switch (c) {
        _ListColumn.name => FsSortKey.name,
        _ListColumn.modified => FsSortKey.modified,
        _ListColumn.size => FsSortKey.size,
        _ListColumn.kind => FsSortKey.kind,
        _ListColumn.where => null,
      };
      final label = switch (c) {
        _ListColumn.name => context.l10n.sortName,
        _ListColumn.modified =>
          tab.location is TrashLocation
              ? context.l10n.deletedAt
              : context.l10n.modified,
        _ListColumn.size => context.l10n.size,
        _ListColumn.kind => context.l10n.kind,
        _ListColumn.where =>
          tab.location is TrashLocation
              ? context.l10n.wherefrom
              : context.l10n.where,
      };
      final active = key != null && sort.key == key;
      final text = InkWell(
        onTap: key == null
            ? null
            : () => config.setSort(
                active
                    ? sort.copyWith(ascending: !sort.ascending)
                    : sort.copyWith(key: key, ascending: true),
              ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    color: context.palette.textTertiary,
                  ),
                ),
              ),
              if (active)
                Icon(
                  sort.ascending
                      ? Icons.arrow_drop_up_rounded
                      : Icons.arrow_drop_down_rounded,
                  size: 16,
                  color: context.palette.textTertiary,
                ),
            ],
          ),
        ),
      );
      final width = _ListModeViewState._width(c);
      return width == 0
          ? Expanded(child: text)
          : SizedBox(width: width, child: text);
    }

    return Container(
      height: 24,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.palette.lineSoft)),
      ),
      child: Row(children: [for (final c in columns) cell(c)]),
    );
  }
}

class _ListRow extends StatelessWidget {
  final FsEntry entry;
  final int depth;
  final FilesTab tab;
  final List<_ListColumn> columns;
  final bool odd;

  const _ListRow({
    required this.entry,
    required this.depth,
    required this.tab,
    required this.columns,
    required this.odd,
  });

  @override
  Widget build(BuildContext context) {
    final controller = FilesScope.of(context).controller;
    final env = controller.env;
    final now = controller.ctx.now();
    final selected = tab.selection.contains(entry.path);
    final trashItem = tab.trashItems[entry.path];
    final cut =
        controller.clipboardCut && controller.clipboard.contains(entry.path);
    Widget text(String value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: selected
              ? context.palette.shadow
              : context.palette.textTertiary,
        ),
      ),
    );
    Widget cell(_ListColumn c) {
      final width = _ListModeViewState._width(c);
      final child = switch (c) {
        _ListColumn.name => Row(
          children: [
            SizedBox(width: 4 + depth * 16.0),
            SizedBox(
              width: 18,
              child: entry.isDirectory && tab.location is FolderLocation
                  ? GestureDetector(
                      onTap: () => tab.toggleExpanded(entry.path),
                      child: Icon(
                        tab.expanded.contains(entry.path)
                            ? Icons.arrow_drop_down_rounded
                            : Icons.arrow_right_rounded,
                        size: 18,
                        color: selected
                            ? context.palette.scrim
                            : context.palette.textQuiet,
                      ),
                    )
                  : null,
            ),
            FileIcon(entry: entry, env: env, size: 18, thumbnail: false),
            const SizedBox(width: 6),
            Expanded(
              child: tab.renaming == entry.path
                  ? EntryRenameField(entry: entry)
                  : Text(
                      trashItem?.name ?? entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: selected
                            ? context.palette.shadow
                            : context.palette.text,
                        fontStyle: entry.isLink
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
            ),
          ],
        ),
        _ListColumn.modified => text(
          trashItem?.deletedAt != null
              ? formatLocalDate(context.l10n, trashItem!.deletedAt!, now)
              : formatDate(context.l10n, entry.modified, now),
        ),
        _ListColumn.size => text(
          entry.isDirectory ? '--' : formatSize(context.l10n, entry.size),
        ),
        _ListColumn.kind => text(env.describe(entry.mimeType)),
        _ListColumn.where => text(
          trashItem != null
              ? dirName(trashItem.originalPath)
              : dirName(entry.path).replaceFirst(env.home, '~'),
        ),
      };
      return width == 0
          ? Expanded(child: child)
          : SizedBox(width: width, child: child);
    }

    return ItemGestures(
      entry: entry,
      feedbackSize: 32,
      child: Opacity(
        opacity: cut || entry.hidden ? 0.5 : 1,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : odd
                ? context.palette.text.withValues(alpha: 0.03)
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(children: [for (final c in columns) cell(c)]),
        ),
      ),
    );
  }
}

// Colunas

class ColumnsView extends StatefulWidget {
  final FilesTab tab;

  const ColumnsView({super.key, required this.tab});

  static const columnWidth = 220.0;

  @override
  State<ColumnsView> createState() => _ColumnsViewState();
}

class _ColumnsViewState extends State<ColumnsView> {
  final _scroll = ScrollController();
  int _lastCount = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    final chain = tab.columnChain;
    for (final path in chain) {
      if (path != tab.folder && !tab.listings.containsKey(path)) {
        tab.ensureListing(path);
      }
    }
    final selected = tab.selectedEntries;
    final preview = selected.length == 1 && !selected.single.isDirectory
        ? selected.single
        : null;
    final count = chain.length + (preview != null ? 1 : 0);
    if (count != _lastCount) {
      _lastCount = count;
      // A coluna nova aparece: rola até o fim
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Numa janela estreita, uma coluna ocupa a largura toda
        final width = constraints.maxWidth < ColumnsView.columnWidth * 1.5
            ? constraints.maxWidth
            : ColumnsView.columnWidth;
        return ListView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          children: [
            for (final (i, path) in chain.indexed)
              SizedBox(
                width: width,
                child: _Column(
                  tab: tab,
                  path: path,
                  entries: path == tab.folder
                      ? tab.items
                      : tab.listings[path] ?? const [],
                  highlighted: i + 1 < chain.length ? chain[i + 1] : null,
                  last: i == chain.length - 1,
                ),
              ),
            if (preview != null)
              SizedBox(
                width: width < ColumnsView.columnWidth ? width : 260,
                child: PreviewPane(entry: preview),
              ),
          ],
        );
      },
    );
  }
}

class _Column extends StatelessWidget {
  final FilesTab tab;
  final String path;
  final List<FsEntry> entries;

  /// A pasta da próxima coluna, destacada nesta.
  final String? highlighted;
  final bool last;

  const _Column({
    required this.tab,
    required this.path,
    required this.entries,
    required this.highlighted,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final env = FilesScope.of(context).controller.env;
    final primary = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: context.palette.lineSoft)),
      ),
      child: FolderDropTarget(
        path: path,
        highlight: false,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          // Clicar no fundo de uma coluna volta para ela
          onPointerDown: (event) {
            final controller = FilesScope.of(context).controller;
            if (event.pointer == controller.claimedPointer) return;
            if (path != tab.folder) tab.go(FolderLocation(path), record: false);
          },
          child: ListView.builder(
            itemExtent: ListModeView.rowHeight,
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final entry = entries[i];
              final selected = last
                  ? tab.selection.contains(entry.path)
                  : entry.path == highlighted;
              final row = Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? (last ? primary : primary.withValues(alpha: 0.35))
                      : null,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    FileIcon(
                      entry: entry,
                      env: env,
                      size: 16,
                      thumbnail: false,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: tab.renaming == entry.path
                          ? EntryRenameField(entry: entry)
                          : Text(
                              entry.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: selected && last
                                    ? context.palette.shadow
                                    : context.palette.text,
                              ),
                            ),
                    ),
                    if (entry.isDirectory)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: selected && last
                            ? context.palette.scrim
                            : context.palette.textDisabled,
                      ),
                  ],
                ),
              );
              return _ColumnItem(
                tab: tab,
                entry: entry,
                column: path,
                child: row,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Um item das colunas: o clique numa pasta abre a próxima coluna, e num
/// arquivo mostra a pré-visualização.
class _ColumnItem extends StatelessWidget {
  final FilesTab tab;
  final FsEntry entry;
  final String column;
  final Widget child;

  const _ColumnItem({
    required this.tab,
    required this.entry,
    required this.column,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (event.buttons != kPrimaryButton) return;
        final ctrl = HardwareKeyboard.instance.isControlPressed;
        final shift = HardwareKeyboard.instance.isShiftPressed;
        if (column != tab.folder) {
          // Numa coluna de antes: ela vira a atual
          tab.go(FolderLocation(column), record: false, select: entry.path);
        } else if (!ctrl && !shift) {
          tab.tap(entry.path);
        }
        if (entry.isDirectory && !ctrl && !shift) {
          tab.go(FolderLocation(entry.path), record: false);
        }
      },
      child: ItemGestures(
        entry: entry,
        feedbackSize: 32,
        selectOnTap: false,
        child: child,
      ),
    );
  }
}

/// A última coluna do modo colunas: o arquivo grande, com o tipo, o tamanho
/// e as datas.
class PreviewPane extends StatelessWidget {
  final FsEntry entry;

  const PreviewPane({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final controller = FilesScope.of(context).controller;
    final env = controller.env;
    final now = controller.ctx.now();
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11,
                color: context.palette.textDisabled,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                color: context.palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          FileIcon(entry: entry, env: env, size: 128),
          const SizedBox(height: 8),
          Text(
            entry.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          line(context.l10n.kind, env.describe(entry.mimeType)),
          line(context.l10n.size, formatSize(context.l10n, entry.size)),
          line(
            context.l10n.modified,
            formatDate(context.l10n, entry.modified, now),
          ),
          line(
            context.l10n.accessed,
            formatDate(context.l10n, entry.accessed, now),
          ),
        ],
      ),
    );
  }
}
