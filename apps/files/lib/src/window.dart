// apps/files/lib/src/window.dart
//
// A janela do Files: a barra lateral, a barra de cima, as abas, o conteúdo e
// a barra de status, e o teclado do Finder (o Enter renomeia, o Espaço
// pré-visualiza, o Ctrl+O e o Ctrl+↓ abrem, o Ctrl+↑ sobe).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:psito_fs/psito_fs.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'controller.dart';
import 'dialogs.dart';
import 'env.dart';
import 'items.dart';
import 'menu.dart';
import 'sidebar.dart';
import 'tab.dart';
import 'toolbar.dart';
import 'views.dart';

class FilesWindow extends StatefulWidget {
  final FilesController controller;

  const FilesWindow({super.key, required this.controller});

  @override
  State<FilesWindow> createState() => _FilesWindowState();
}

class _FilesWindowState extends State<FilesWindow> {
  final _focus = FocusNode(debugLabel: 'files');
  final _search = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'busca');
  final _menu = MenuController();
  final _anchorKey = GlobalKey();
  List<Widget> _menuChildren = const [];
  bool? _sidebarOpen;

  FilesController get controller => widget.controller;
  FilesTab get tab => controller.tab;

  @override
  void initState() {
    super.initState();
    controller.onConflict = (conflict) => showConflict(context, conflict);
    controller.onError = _showError;
    controller.onConfirm = (q, d, a) => showConfirm(context, q, d, a);
    controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      _openQuickLook();
    });
  }

  void _openQuickLook() {
    if (mounted && controller.takeQuickLook()) {
      unawaited(showQuickLook(context, controller));
    }
  }

  FilesLocation? _lastLocation;

  void _changed() {
    // A busca que a aba deixou (voltar, outra aba) limpa o campo
    final location = tab.location;
    if (location != _lastLocation) {
      _lastLocation = location;
      final query = location is SearchLocation ? location.query : '';
      if (_search.text != query) _search.text = query;
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _openQuickLook());
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontSize: 12)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    _focus.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _showMenu(Offset global, FsEntry? entry) async {
    var apps = const <PsitoAppChoice>[];
    if (entry != null && !entry.isDirectory) {
      // O shell responde rápido; sem ele, o menu abre sem a lista
      apps = await controller
          .appsFor(entry.mimeType)
          .timeout(
            const Duration(milliseconds: 400),
            onTimeout: () => const [],
          );
    }
    if (!mounted) return;
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(
      () => _menuChildren = contextMenu(context, controller, entry, apps),
    );
    _menu.open(position: box.globalToLocal(global));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (tab.renaming != null || _searchFocus.hasFocus) {
      return KeyEventResult.ignored;
    }
    final keys = HardwareKeyboard.instance;
    final ctrl = keys.isControlPressed;
    final shift = keys.isShiftPressed;
    final alt = keys.isAltPressed;
    final key = event.logicalKey;
    final selected = tab.selectedEntries;
    final paths = [for (final e in selected) e.path];
    final inFolder = tab.location is FolderLocation;
    final inTrash = tab.location is TrashLocation;
    bool handled(void Function() action) {
      action();
      return true;
    }

    final done = switch (key) {
      // Navegar
      LogicalKeyboardKey.arrowUp when ctrl => handled(tab.up),
      LogicalKeyboardKey.arrowDown when ctrl => handled(
        () => controller.open(selected),
      ),
      LogicalKeyboardKey.keyO when ctrl => handled(
        () => controller.open(selected),
      ),
      LogicalKeyboardKey.arrowLeft when alt => handled(tab.back),
      LogicalKeyboardKey.arrowRight when alt => handled(tab.forward),
      LogicalKeyboardKey.bracketLeft when ctrl => handled(tab.back),
      LogicalKeyboardKey.bracketRight when ctrl => handled(tab.forward),
      LogicalKeyboardKey.backspace when !ctrl && inFolder => handled(tab.back),
      // Abas (o Ctrl+Tab é do compositor: alternar janelas na VM)
      LogicalKeyboardKey.keyT when ctrl => handled(() => controller.newTab()),
      LogicalKeyboardKey.keyW when ctrl => handled(controller.closeTab),
      LogicalKeyboardKey.pageDown when ctrl => handled(
        () => controller.nextTab(1),
      ),
      LogicalKeyboardKey.pageUp when ctrl => handled(
        () => controller.nextTab(-1),
      ),
      // Modos
      LogicalKeyboardKey.digit1 when ctrl => handled(
        () => tab.setMode(ViewMode.icons),
      ),
      LogicalKeyboardKey.digit2 when ctrl => handled(
        () => tab.setMode(ViewMode.list),
      ),
      LogicalKeyboardKey.digit3 when ctrl && inFolder => handled(
        () => tab.setMode(ViewMode.columns),
      ),
      LogicalKeyboardKey.keyH when ctrl => handled(
        () => controller.config.setShowHidden(!controller.config.showHidden),
      ),
      LogicalKeyboardKey.keyF when ctrl => handled(_searchFocus.requestFocus),
      // Ações
      LogicalKeyboardKey.keyA when ctrl => handled(tab.selectAll),
      LogicalKeyboardKey.keyN when ctrl && shift && inFolder => handled(
        controller.newFolder,
      ),
      LogicalKeyboardKey.keyC when ctrl && !inTrash => handled(
        () => controller.copy(paths),
      ),
      LogicalKeyboardKey.keyX when ctrl && inFolder => handled(
        () => controller.copy(paths, cut: true),
      ),
      LogicalKeyboardKey.keyV when ctrl && inFolder => handled(
        controller.paste,
      ),
      LogicalKeyboardKey.keyD when ctrl && !inTrash => handled(
        () => controller.duplicate(paths),
      ),
      LogicalKeyboardKey.keyZ when ctrl => handled(controller.undo),
      LogicalKeyboardKey.keyI when ctrl && selected.length == 1 => handled(
        () => showInfo(context, controller, selected.single),
      ),
      LogicalKeyboardKey.delete when inTrash => handled(
        () => controller.deleteForeverAsked(paths),
      ),
      LogicalKeyboardKey.delete => handled(() => controller.moveToTrash(paths)),
      LogicalKeyboardKey.backspace when ctrl && !inTrash => handled(
        () => controller.moveToTrash(paths),
      ),
      // O Finder: o Enter renomeia
      LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter
          when selected.length == 1 && inFolder =>
        handled(() => tab.startRename(selected.single.path)),
      LogicalKeyboardKey.space when tab.cursor != null => handled(
        () => showQuickLook(context, controller),
      ),
      LogicalKeyboardKey.escape => handled(tab.clearSelection),
      // As setas
      LogicalKeyboardKey.arrowUp => handled(
        () => _arrow(-1, vertical: true, shift: shift),
      ),
      LogicalKeyboardKey.arrowDown => handled(
        () => _arrow(1, vertical: true, shift: shift),
      ),
      LogicalKeyboardKey.arrowLeft => handled(
        () => _arrow(-1, vertical: false, shift: shift),
      ),
      LogicalKeyboardKey.arrowRight => handled(
        () => _arrow(1, vertical: false, shift: shift),
      ),
      LogicalKeyboardKey.home => handled(
        () => tab.moveCursor(-1 << 30, extend: shift),
      ),
      LogicalKeyboardKey.end => handled(
        () => tab.moveCursor(1 << 30, extend: shift),
      ),
      _ => false,
    };
    if (done) return KeyEventResult.handled;
    // Digitar o começo do nome
    final char = event.character;
    if (!ctrl && !alt && char != null && char.trim().isNotEmpty) {
      tab.typeAhead(char);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// As setas em cada modo: na grade, cima e baixo andam uma linha; nas
  /// colunas, esquerda e direita trocam de coluna.
  void _arrow(int delta, {required bool vertical, required bool shift}) {
    switch (tab.mode) {
      case ViewMode.icons:
        final width = _contentWidth ?? 600;
        final columns = IconsView.columnsFor(width, controller.config.iconSize);
        tab.moveCursor(vertical ? delta * columns : delta, extend: shift);
      case ViewMode.list:
        if (vertical) {
          tab.moveCursor(delta, extend: shift);
        } else {
          // Na lista, a direita abre a pasta em árvore e a esquerda fecha
          final current = tab.cursor == null ? null : tab.entryAt(tab.cursor!);
          if (current != null &&
              current.isDirectory &&
              tab.expanded.contains(current.path) == (delta < 0)) {
            tab.toggleExpanded(current.path);
          }
        }
      case ViewMode.columns:
        if (vertical) {
          tab.moveCursor(delta, extend: shift);
        } else if (delta > 0) {
          final current = tab.cursor == null ? null : tab.entryAt(tab.cursor!);
          if (current != null && current.isDirectory) {
            tab.go(FolderLocation(current.path), record: false);
            unawaited(
              Future<void>.delayed(
                const Duration(milliseconds: 60),
                () => tab.moveCursor(1),
              ),
            );
          }
        } else if (tab.folder != tab.columnBase && tab.folder != null) {
          final folder = tab.folder!;
          tab.go(
            FolderLocation(dirName(folder)),
            record: false,
            select: folder,
          );
        }
    }
  }

  double? _contentWidth;

  @override
  Widget build(BuildContext context) {
    return FilesScope(
      controller: controller,
      showMenu: _showMenu,
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: MenuAnchor(
          key: _anchorKey,
          controller: _menu,
          menuChildren: _menuChildren,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Numa janela estreita a barra lateral some, como no Finder
              final roomy = constraints.maxWidth >= 480;
              final sidebar = _sidebarOpen ?? roomy;
              final tall = constraints.maxHeight >= 260;
              return Column(
                children: [
                  Toolbar(
                    search: _search,
                    searchFocus: _searchFocus,
                    onToggleSidebar: constraints.maxWidth >= 300
                        ? () => setState(() => _sidebarOpen = !sidebar)
                        : null,
                  ),
                  const TabStrip(),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (sidebar && constraints.maxWidth >= 300)
                          const Sidebar(),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, inner) {
                              _contentWidth = inner.maxWidth;
                              return Listener(
                                // Clicar no conteúdo devolve o teclado à
                                // pasta (tira da busca)
                                onPointerDown: (_) {
                                  if (tab.renaming == null) {
                                    _focus.requestFocus();
                                  }
                                },
                                behavior: HitTestBehavior.translucent,
                                child: ListenableBuilder(
                                  listenable: tab,
                                  builder: (context, _) =>
                                      FolderContent(tab: tab),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const JobsBar(),
                  if (tall) const StatusBar(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
