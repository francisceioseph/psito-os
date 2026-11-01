// apps/files/lib/src/items.dart
//
// O que os três modos de ver têm em comum em cada item: o clique (com o Ctrl
// e o Shift), o duplo clique que abre, o menu de contexto, arrastar (os
// selecionados vão juntos, e para fora da janela pelo psito/dnd), soltar
// numa pasta (de dentro ou de outro app) e o nome em edição.
import 'package:flutter/gestures.dart'
    show kPrimaryButton, kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:psito_files_ui/psito_files_ui.dart';
import 'package:psito_fs/psito_fs.dart';
import 'package:psito_runtime/psito_runtime.dart';

import 'controller.dart';
import 'env.dart';

/// O que a janela oferece aos widgets de dentro.
class FilesScope extends InheritedWidget {
  final FilesController controller;

  /// O menu de contexto em [position] (global), de um item ou do fundo.
  final void Function(Offset position, FsEntry? entry) showMenu;

  const FilesScope({
    super.key,
    required this.controller,
    required this.showMenu,
    required super.child,
  });

  static FilesScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FilesScope>()!;

  /// Sempre: a janela só se reconstrói quando o controlador muda (aba nova,
  /// trabalho andando, pasta carregada), e as barras são `const`.
  @override
  bool updateShouldNotify(FilesScope old) => true;
}

/// Os caminhos que estão sendo arrastados.
class DragFiles {
  final List<String> paths;

  const DragFiles(this.paths);
}

bool get _ctrl => HardwareKeyboard.instance.isControlPressed;
bool get _shift => HardwareKeyboard.instance.isShiftPressed;

/// Os gestos de um item e, nas pastas, soltar dentro dela.
class ItemGestures extends StatelessWidget {
  final FsEntry entry;
  final Widget child;

  /// Como o item aparece embaixo do ponteiro enquanto é arrastado.
  final double feedbackSize;

  /// O clique seleciona. As colunas selecionam por conta própria.
  final bool selectOnTap;

  const ItemGestures({
    super.key,
    required this.entry,
    required this.child,
    this.feedbackSize = 48,
    this.selectOnTap = true,
  });

  @override
  Widget build(BuildContext context) {
    final scope = FilesScope.of(context);
    final controller = scope.controller;
    final tab = controller.tab;
    // O Listener e não o onTapDown: com o duplo clique no mesmo item, o
    // GestureDetector só decide o clique 300 ms depois, e a seleção não pode
    // esperar
    final gestures = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        // O fundo, que também recebe o clique, sabe que foi num item
        controller.claimedPointer = event.pointer;
        if (event.buttons == kSecondaryMouseButton) {
          if (!tab.selection.contains(entry.path)) tab.tap(entry.path);
          scope.showMenu(event.position, entry);
          return;
        }
        if (event.buttons != kPrimaryButton) return;
        if (!selectOnTap || tab.renaming == entry.path) return;
        // Clicar num selecionado sem modificador mantém a seleção (para
        // arrastar todos); o soltar decide
        if (!_ctrl && !_shift && tab.selection.contains(entry.path)) {
          tab.cursor = entry.path;
          controller.pendingCollapse = entry.path;
          return;
        }
        tab.tap(entry.path, toggle: _ctrl, extend: _shift);
      },
      onPointerUp: (_) {
        if (controller.pendingCollapse == entry.path) tab.tap(entry.path);
        controller.pendingCollapse = null;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => controller.open([entry], newTab: _ctrl),
        child: child,
      ),
    );
    final data = DragFiles(
      tab.selection.contains(entry.path) ? [...tab.selection] : [entry.path],
    );
    final draggable = Draggable<DragFiles>(
      data: data,
      onDragStarted: () {
        controller.pendingCollapse = null;
        if (!tab.selection.contains(entry.path)) tab.tap(entry.path);
      },
      // Fora da janela, o arrastar continua pelo sistema, para outros apps
      // e a dock; o Draggable segue vivo e solta se voltar
      onDragUpdate: (details) {
        if (controller.outsideDrag.value) return;
        final view = View.of(context);
        final bounds = Offset.zero & view.physicalSize / view.devicePixelRatio;
        if (bounds.contains(details.globalPosition)) return;
        controller.outsideDrag.value = true;
        PsitoDnd.instance.startDrag(view.viewId, data.paths);
      },
      onDragEnd: (_) => controller.outsideDrag.value = false,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: ValueListenableBuilder(
        valueListenable: controller.outsideDrag,
        builder: (context, outside, child) =>
            outside ? const SizedBox.shrink() : child!,
        child: _DragFeedback(
          entry: entry,
          count: tab.selection.contains(entry.path) ? tab.selection.length : 1,
          size: feedbackSize,
          env: controller.env,
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.5, child: gestures),
      child: gestures,
    );
    if (!entry.isDirectory) return draggable;
    return FolderDropTarget(path: entry.path, child: draggable);
  }
}

class _DragFeedback extends StatelessWidget {
  final FsEntry entry;
  final int count;
  final double size;
  final FilesEnv env;

  const _DragFeedback({
    required this.entry,
    required this.count,
    required this.size,
    required this.env,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(-size / 2, -size / 2),
      child: Opacity(
        opacity: 0.85,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            FileIcon(entry: entry, env: env, size: size),
            if (count > 1)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Soltar arquivos em [path]: move, ou copia com o Ctrl. O que vem de outro
/// app é copiado. Uma pasta não aceita a si mesma nem o que já está nela.
class FolderDropTarget extends StatelessWidget {
  final String path;
  final Widget child;

  /// Desenha o destaque de quando algo está em cima.
  final bool highlight;

  const FolderDropTarget({
    super.key,
    required this.path,
    required this.child,
    this.highlight = true,
  });

  bool _accepts(List<String> paths) =>
      paths.every((p) => p != path && !isWithin(p, path));

  @override
  Widget build(BuildContext context) {
    final controller = FilesScope.of(context).controller;
    return PsitoDropTarget(
      onWillAccept: (paths) => _accepts(paths) ? DropAction.copy : null,
      onAccept: (paths, action) {
        controller.transfer(paths, path, move: action == DropAction.move);
        return true;
      },
      builder: (context, outside) => DragTarget<DragFiles>(
        onWillAcceptWithDetails: (d) => _accepts(d.data.paths),
        onAcceptWithDetails: (d) =>
            controller.transfer(d.data.paths, path, move: !_ctrl),
        builder: (context, candidates, _) =>
            _highlighted(context, outside || candidates.isNotEmpty),
      ),
    );
  }

  Widget _highlighted(BuildContext context, bool hovering) {
    if (!highlight || !hovering) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      child: child,
    );
  }
}

/// O nome em edição: o Enter grava, o Esc desiste, e clicar fora grava (como
/// no Finder). Começa com o nome sem a extensão selecionado.
class RenameField extends StatefulWidget {
  final FsEntry entry;
  final TextAlign textAlign;
  final int? maxLines;

  const RenameField({
    super.key,
    required this.entry,
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
  });

  @override
  State<RenameField> createState() => _RenameFieldState();
}

class _RenameFieldState extends State<RenameField> {
  late final _controller = TextEditingController(text: widget.entry.name);
  final _focus = FocusNode();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final (stem, _) = splitExtension(
      widget.entry.name,
      isDirectory: widget.entry.isDirectory,
    );
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: stem.length,
    );
    _focus.addListener(() {
      if (!_focus.hasFocus) _submit();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _submit() {
    if (_done) return;
    _done = true;
    final controller = FilesScope.of(context).controller;
    final name = _controller.text.trim();
    if (name.isEmpty || name == widget.entry.name) {
      controller.tab.stopRename();
    } else {
      controller.rename(widget.entry.path, name);
    }
  }

  void _cancel() {
    _done = true;
    FilesScope.of(context).controller.tab.stopRename();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancel},
    child: TextField(
      controller: _controller,
      focusNode: _focus,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(fontSize: 12, color: Colors.white),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
      ),
      onSubmitted: (_) => _submit(),
    ),
  );
}

/// O fundo de um item selecionado.
BoxDecoration selectionDecoration(BuildContext context, bool selected) =>
    BoxDecoration(
      color: selected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.28)
          : null,
      borderRadius: BorderRadius.circular(6),
    );
