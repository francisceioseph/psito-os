// shell/lib/dock.dart
//
// A dock do psito_dock com os tipos do shell (os `.desktop` e as janelas do
// foreign-toplevel), e o que a mexe com o mouse: arrastar para pôr, mover e
// tirar, soltar arquivos e o menu do clique direito. A view da dock e a da
// sobreposição leem este mesmo estado.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:psito_dock/psito_dock.dart';
import 'package:system_shell/shell/app_entry.dart';
import 'package:system_shell/widgets/dock_menu.dart';
import 'package:system_shell/widgets/psito_dock.dart';

import 'app_icon.dart';
import 'desktop_entries.dart';
import 'shell_state.dart';
import 'toplevels.dart';

typedef DockSlot = DockAppSlot<DesktopEntry, Toplevel>;

extension DockSlotName on DockSlot {
  /// Sem `.desktop`, o título da janela.
  String get name => app?.name ?? (windows.isEmpty ? id : windows.last.title);
}

/// De onde veio o ícone arrastado.
enum DockDragSource { dock, launcher }

@immutable
class DockDrag {
  final DockItem item;
  final DockDragSource source;

  /// O ponteiro, na tela.
  final Offset position;

  const DockDrag(this.item, this.source, this.position);
}

@immutable
class DockMenuRequest {
  final DockItem item;

  /// O ícone, na tela.
  final Rect anchor;

  const DockMenuRequest(this.item, this.anchor);
}

/// Um ícone na fileira da dock: um app (com o [slot]) ou uma pasta ou um
/// arquivo.
class DockRowItem {
  final DockItem item;
  final DockSlot? slot;

  const DockRowItem(this.item, [this.slot]);
}

/// A fileira como a dock desenha: os apps fixados, os abertos e as pastas e
/// os arquivos, com um separador antes de cada seção que não seja a
/// primeira. O ícone arrastado da dock fica de fora.
class DockRow {
  final List<DockRowItem> items;
  final Set<int> separators;

  /// Quantos apps fixados (o começo da fileira).
  final int pinned;

  /// Onde começam as pastas e os arquivos.
  final int paths;

  const DockRow(this.items, this.separators, this.pinned, this.paths);
}

class DockController {
  DockController(this.state);

  final ShellState state;

  final drag = ValueNotifier<DockDrag?>(null);
  final menu = ValueNotifier<DockMenuRequest?>(null);

  /// A tela, e o tamanho da superfície da dock (centrada na base). A view
  /// da dock avisa os dois.
  Size screen = const Size(1440, 900);
  Size surface = Size.zero;

  /// O último ponto do ponteiro na sobreposição, onde começa o arrastar do
  /// launcher.
  Offset lastPointer = Offset.zero;

  /// Os ícones do tema de uma pasta ou de um arquivo (o main põe os do tipo
  /// MIME e das pastas do usuário).
  List<String> Function(DockPath item) iconsFor = (item) => [
    if (item is DockFolder) 'folder' else 'text-x-generic',
  ];

  /// O nome, a cor e o ícone de [item]. As pastas e os arquivos ficam
  /// num cinza neutro, para não competir com a cor dos apps.
  AppEntry visual(DockItem item) => switch (item) {
    DockApp(:final id) => state.appFor(id),
    DockPath() => pathEntry(keyOf(item), item.name, iconsFor(item), pathColor),
  };

  static const pathColor = Color(0xFF90A4AE);

  /// Um nome único de [item], para as chaves dos widgets.
  static String keyOf(DockItem item) => switch (item) {
    DockApp(:final id) => 'app:$id',
    DockFolder(:final path) => 'folder:$path',
    DockFile(:final path) => 'file:$path',
  };

  /// Onde o canto da superfície da dock fica na tela.
  Offset get origin => Offset(
    (screen.width - surface.width) / 2,
    screen.height - surface.height,
  );

  DockRow get row {
    final sections = state.dockSections;
    final dragged = drag.value?.source == DockDragSource.dock
        ? drag.value!.item
        : null;
    final pinned = [
      for (final slot in sections.pinned)
        if (slot.item != dragged) DockRowItem(slot.item, slot),
    ];
    final running = [
      for (final slot in sections.running)
        if (slot.item != dragged) DockRowItem(slot.item, slot),
    ];
    final paths = [
      for (final path in sections.paths)
        if (path != dragged) DockRowItem(path),
    ];
    final apps = pinned.length + running.length;
    return DockRow(
      [...pinned, ...running, ...paths],
      {
        if (running.isNotEmpty && pinned.isNotEmpty) pinned.length,
        if (paths.isNotEmpty && apps > 0) apps,
      },
      pinned.length,
      apps,
    );
  }

  /// Onde o arrastado cai na [row] (o índice do espaço que abre), ou null
  /// longe da dock. Um app cai entre os fixados; uma pasta ou um arquivo,
  /// entre os seus.
  int? dropIndex(DockRow row, DockDrag drag) {
    final size = state.settings.value.dockIconSize;
    final position = drag.position;
    if (position.dy < screen.height - surface.height - size * 0.75) {
      return null;
    }
    final centers = PsitoDock.centers(
      count: row.items.length,
      separators: row.separators,
      iconSize: size,
      centerX: screen.width / 2,
    );
    final reach = PsitoDock.span(size) * 1.5;
    final left = (centers.firstOrNull ?? screen.width / 2) - reach;
    final right = (centers.lastOrNull ?? screen.width / 2) + reach;
    if (position.dx < left || position.dx > right) return null;
    final (start, end) = drag.item is DockApp
        ? (0, row.pinned)
        : (row.paths, row.items.length);
    var index = start;
    while (index < end && centers[index] < position.dx) {
      index++;
    }
    return index;
  }

  void startDrag(DockItem item, DockDragSource source, Offset position) {
    menu.value = null;
    drag.value = DockDrag(item, source, position);
    // O launcher fecha, mas a sobreposição fica, com o ponteiro
    if (source == DockDragSource.launcher) state.closeOverlay();
  }

  void moveDrag(Offset position) {
    final current = drag.value;
    if (current == null) return;
    drag.value = DockDrag(current.item, current.source, position);
  }

  /// Soltar sobre a dock fixa no lugar do espaço aberto; soltar longe tira
  /// o que veio da dock.
  Future<void> endDrag() async {
    final current = drag.value;
    if (current == null) return;
    final row = this.row;
    final index = dropIndex(row, current);
    drag.value = null;
    if (index != null) {
      await state.dock.pin(
        current.item,
        before: index < row.items.length ? row.items[index].item : null,
      );
    } else if (current.source == DockDragSource.dock) {
      await state.dock.unpin(current.item);
    }
  }

  void cancelDrag() => drag.value = null;

  void tap(DockItem item) {
    switch (item) {
      case DockApp():
        for (final slot in state.dockSections.apps) {
          if (slot.item == item) state.tapDock(slot);
        }
      case DockPath(:final path):
        _open(path);
    }
  }

  void _open(String path) {
    final open = state.openPaths;
    if (open == null) return;
    unawaited(
      open([
        path,
      ]).catchError((Object e) => debugPrint('🦜 dock: sem abrir $path ($e)')),
    );
  }

  /// Arquivos e pastas soltos na dock viram itens, no fim.
  Future<bool> dropPaths(List<String> paths) async {
    for (final path in paths) {
      await state.dock.pin(
        FileSystemEntity.isDirectorySync(path)
            ? DockFolder(path)
            : DockFile(path),
      );
    }
    return paths.isNotEmpty;
  }

  void openMenu(DockItem item, Rect rect) =>
      menu.value = DockMenuRequest(item, rect.shift(origin));

  void closeMenu() => menu.value = null;

  String title(DockItem item) => switch (item) {
    DockApp(:final id) =>
      [
            for (final slot in state.dockSections.apps)
              if (slot.id == id) slot.name,
          ].firstOrNull ??
          id,
    DockPath() => item.name,
  };

  /// As opções do menu de [item].
  List<DockMenuItem> menuItems(DockItem item) {
    final pinned = state.dock.contains(item);
    final keep = pinned
        ? DockMenuItem('Remover da Dock', () => state.dock.unpin(item))
        : DockMenuItem('Manter na Dock', () => state.dock.pin(item));
    switch (item) {
      case DockApp(:final id):
        final app = state.installed(id);
        final autostart = state.autostart;
        return [
          if (app != null && autostart != null)
            DockMenuItem(
              'Abrir ao iniciar a sessão',
              () => unawaited(autostart.set(app, !autostart.enabled(id))),
              checked: autostart.enabled(id),
            ),
          keep,
        ];
      case DockPath(:final path):
        final parent = File(path).parent.path;
        return [
          DockMenuItem('Abrir', () => tap(item)),
          DockMenuItem('Mostrar no Files', () => _open(parent)),
          keep,
        ];
    }
  }
}
