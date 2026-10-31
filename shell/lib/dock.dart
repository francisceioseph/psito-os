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
import 'package:psito_fs/psito_fs.dart';
import 'package:psito_runtime/psito_runtime.dart';
import 'package:system_shell/shell/app_entry.dart';
import 'package:system_shell/widgets/dock_menu.dart';
import 'package:system_shell/widgets/dock_stack.dart';
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

/// Uma pasta aberta como pilha.
@immutable
class DockStackRequest {
  final DockFolder folder;

  /// O ícone, na tela.
  final Rect anchor;

  /// O conteúdo, os mais novos primeiro.
  final List<DockPath> entries;

  const DockStackRequest(this.folder, this.anchor, this.entries);
}

/// Um ícone na fileira da dock: um app (com o [slot]), uma pasta, um
/// arquivo ou a lixeira.
class DockRowItem {
  final DockItem item;
  final DockSlot? slot;

  const DockRowItem(this.item, [this.slot]);
}

/// A fileira como a dock desenha: os apps fixados, os abertos e as pastas e
/// os arquivos com a lixeira no fim, com um separador antes de cada seção
/// que não seja a primeira. O ícone arrastado da dock fica de fora.
class DockRow {
  final List<DockRowItem> items;
  final Set<int> separators;

  /// Quantos apps fixados (o começo da fileira).
  final int pinned;

  /// Onde começam as pastas e os arquivos (a lixeira é o último).
  final int paths;

  const DockRow(this.items, this.separators, this.pinned, this.paths);
}

class DockController {
  DockController(this.state);

  final ShellState state;

  final drag = ValueNotifier<DockDrag?>(null);
  final menu = ValueNotifier<DockMenuRequest?>(null);
  final stack = ValueNotifier<DockStackRequest?>(null);

  /// A confirmação do "Esvaziar a lixeira" está aberta.
  final askEmptyTrash = ValueNotifier(false);

  /// A lixeira do usuário (o main põe). Null: sem lixeira (testes).
  Trash? trash;

  /// Se a lixeira tem algo, para o ícone cheio.
  final trashFull = ValueNotifier(false);

  /// Se o app abre todos os [paths] (o `MimeType=` do `.desktop`, pelo
  /// Opener no main).
  bool Function(String appId, List<String> paths) appAccepts = (_, _) => false;

  /// O conteúdo de uma pasta para a pilha, os mais novos primeiro.
  Future<List<DockPath>> Function(String dir) listFolder = _listFolder;

  /// Até quantos itens a pilha mostra.
  static const stackLimit = 200;

  /// Os apps abrindo pela dock, cujo ícone pula.
  final launching = ValueNotifier<Set<String>>(const {});
  final _launchTimers = <String, Timer>{};
  final _launchBase = <String, int>{};

  /// Quanto o ícone pula, no máximo, esperando a janela.
  Duration bounceLimit = const Duration(seconds: 10);

  int _windowCount(String id) =>
      state.toplevels.windows.where((w) => w.appId == id).length;

  /// O ícone de [id] pula até aparecer uma janela nova dele, ou até o
  /// [bounceLimit].
  void startBounce(String id) {
    _launchBase[id] = _windowCount(id);
    _launchTimers.remove(id)?.cancel();
    _launchTimers[id] = Timer(bounceLimit, () => _stopBounce(id));
    launching.value = {...launching.value, id};
  }

  void _stopBounce(String id) {
    _launchTimers.remove(id)?.cancel();
    _launchBase.remove(id);
    launching.value = {...launching.value}..remove(id);
  }

  /// As janelas mudaram: o app que ganhou uma para de pular.
  void windowsChanged() {
    for (final id in launching.value) {
      if (_windowCount(id) > (_launchBase[id] ?? 0)) _stopBounce(id);
    }
  }

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
    DockTrash() => pathEntry(keyOf(item), 'Lixeira', [
      if (trashFull.value) 'user-trash-full' else 'user-trash',
    ], pathColor),
  };

  static const pathColor = Color(0xFF90A4AE);

  /// Um nome único de [item], para as chaves dos widgets.
  static String keyOf(DockItem item) => switch (item) {
    DockApp(:final id) => 'app:$id',
    DockFolder(:final path) => 'folder:$path',
    DockFile(:final path) => 'file:$path',
    DockTrash() => 'trash',
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
      [...pinned, ...running, ...paths, const DockRowItem(DockTrash())],
      {
        if (running.isNotEmpty && pinned.isNotEmpty) pinned.length,
        if (apps > 0) apps,
      },
      pinned.length,
      apps,
    );
  }

  /// Onde o arrastado cai na [row] (o índice do espaço que abre), ou null
  /// longe da dock. Um app cai entre os fixados; uma pasta ou um arquivo,
  /// entre os seus, antes da lixeira.
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
        : (row.paths, row.items.length - 1);
    var index = start;
    while (index < end && centers[index] < position.dx) {
      index++;
    }
    return index;
  }

  void startDrag(DockItem item, DockDragSource source, Offset position) {
    if (item is DockTrash) return;
    menu.value = null;
    stack.value = null;
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

  /// O clique. Uma pasta abre a pilha acima do ícone ([rect], na view da
  /// dock); sem ele, abre no Files.
  void tap(DockItem item, [Rect? rect]) {
    switch (item) {
      case DockApp():
        for (final slot in state.dockSections.apps) {
          if (slot.item == item) state.tapDock(slot);
        }
      case DockFolder() when rect != null:
        unawaited(openStack(item, rect));
      case DockPath(:final path):
        _open([path]);
      case DockTrash():
        unawaited(openTrash());
    }
  }

  void _open(List<String> paths, {String? withApp}) {
    final open = state.openPaths;
    if (open == null) return;
    unawaited(
      open(
        paths,
        withApp: withApp,
      ).catchError((Object e) => debugPrint('🦜 dock: sem abrir $paths ($e)')),
    );
  }

  /// A lixeira no Files (que reconhece a pasta `Trash/files`).
  Future<void> openTrash() async {
    final trash = this.trash;
    if (trash == null) return;
    try {
      await Directory(trash.filesDir).create(recursive: true);
    } on FileSystemException catch (e) {
      debugPrint('🦜 dock: sem a lixeira ($e)');
      return;
    }
    _open([trash.filesDir]);
  }

  Future<void> openStack(DockFolder folder, Rect rect) async {
    menu.value = null;
    List<DockPath> entries;
    try {
      entries = await listFolder(folder.path);
    } on FileSystemException catch (e) {
      debugPrint('🦜 dock: sem listar ${folder.path} ($e)');
      entries = const [];
    }
    stack.value = DockStackRequest(folder, rect.shift(origin), entries);
  }

  void closeStack() => stack.value = null;

  /// O conteúdo da pilha como o DockStack desenha.
  List<DockStackEntry> stackEntries(DockStackRequest request) => [
    for (final path in request.entries) DockStackEntry(path.path, visual(path)),
  ];

  /// Abre um item da pilha: uma pasta no Files, um arquivo no app padrão.
  void openFromStack(String path) => _open([path]);

  static Future<List<DockPath>> _listFolder(String dir) async {
    final found = <(DockPath, DateTime)>[];
    await for (final entity in Directory(dir).list()) {
      final name = entity.uri.pathSegments.lastWhere(
        (part) => part.isNotEmpty,
        orElse: () => '',
      );
      if (name.startsWith('.')) continue;
      final stat = await entity.stat();
      found.add((
        stat.type == FileSystemEntityType.directory
            ? DockFolder(entity.path)
            : DockFile(entity.path),
        stat.modified,
      ));
    }
    // Do mesmo segundo, pelo nome
    found.sort((a, b) {
      final byDate = b.$2.compareTo(a.$2);
      return byDate != 0 ? byDate : a.$1.path.compareTo(b.$1.path);
    });
    return [for (final (path, _) in found.take(stackLimit)) path];
  }

  /// Vigia a `Trash/files`, para o ícone cheio ou vazio.
  Future<void> watchTrash() async {
    final trash = this.trash;
    if (trash == null) return;
    final dir = Directory(trash.filesDir);
    try {
      await dir.create(recursive: true);
    } on FileSystemException {
      return;
    }
    await refreshTrash();
    dir.watch().listen((_) => unawaited(refreshTrash()));
  }

  Future<void> refreshTrash() async {
    final trash = this.trash;
    if (trash == null) return;
    trashFull.value = !await trash.isEmpty();
  }

  Future<void> emptyTrash() async {
    try {
      await trash?.empty();
    } on FileSystemException catch (e) {
      debugPrint('🦜 dock: sem esvaziar a lixeira ($e)');
    }
    await refreshTrash();
  }

  /// Com que ação [item] aceita os arquivos soltos nele: um app abre os
  /// que ele abre, a lixeira leva. Null recusa.
  DropAction? dropAction(DockItem item, List<String> paths) {
    if (paths.isEmpty) return null;
    return switch (item) {
      DockApp(:final id)
          when state.installed(id) != null && appAccepts(id, paths) =>
        DropAction.copy,
      DockTrash() when trash != null => DropAction.move,
      _ => null,
    };
  }

  /// Os arquivos soltos sobre [item].
  Future<bool> dropOn(DockItem item, List<String> paths) async {
    if (dropAction(item, paths) == null) return false;
    switch (item) {
      case DockApp(:final id):
        _open(paths, withApp: id);
      case DockTrash():
        for (final path in paths) {
          try {
            await trash!.trash(path);
          } on FileSystemException catch (e) {
            debugPrint('🦜 dock: sem levar $path para a lixeira ($e)');
          }
        }
        await refreshTrash();
      case DockPath():
        return false;
    }
    return true;
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

  /// Fecha o menu e a pilha (o launcher ou um painel abriu).
  void closePopups() {
    menu.value = null;
    stack.value = null;
  }

  String title(DockItem item) => switch (item) {
    DockApp(:final id) =>
      [
            for (final slot in state.dockSections.apps)
              if (slot.id == id) slot.name,
          ].firstOrNull ??
          id,
    DockPath() => item.name,
    DockTrash() => 'Lixeira',
  };

  /// O menu de um app, em grupos: as janelas (a mais recente primeiro),
  /// abrir de novo, a sessão e a dock, e ocultar e fechar.
  List<DockMenuItem> _appMenu(String id, DockMenuItem keep) {
    final app = state.installed(id);
    final autostart = state.autostart;
    final windows = [
      for (final slot in state.dockSections.apps)
        if (slot.id == id) ...slot.windows.reversed,
    ];
    final newWindow = app?.actions.where((a) => a.id == 'new-window');
    final toplevels = state.toplevels;
    final groups = [
      [
        for (final window in windows)
          DockMenuItem(
            window.title.isEmpty ? title(DockApp(id)) : window.title,
            () => unawaited(toplevels.activate(window.id)),
            checked: window.activated && !window.minimized ? true : null,
          ),
      ],
      [
        if (app != null) ...[
          DockMenuItem(
            windows.isEmpty ? 'Abrir' : 'Nova janela',
            () => state.launchFromDock(
              app,
              command: newWindow?.firstOrNull?.command,
            ),
          ),
          for (final action in app.actions)
            if (action.id != 'new-window')
              DockMenuItem(
                action.name,
                () => state.launchFromDock(app, command: action.command),
              ),
        ],
      ],
      [
        if (app != null && autostart != null)
          DockMenuItem(
            'Abrir ao iniciar a sessão',
            () => unawaited(autostart.set(app, !autostart.enabled(id))),
            checked: autostart.enabled(id),
          ),
        keep,
      ],
      if (windows.isNotEmpty)
        [
          DockMenuItem('Ocultar', () {
            for (final window in windows) {
              if (!window.minimized) unawaited(toplevels.minimize(window.id));
            }
          }),
          DockMenuItem(
            windows.length > 1 ? 'Fechar ${windows.length} janelas' : 'Fechar',
            () {
              for (final window in windows) {
                unawaited(toplevels.close(window.id));
              }
            },
          ),
        ],
    ];
    return [
      for (final group in groups.where((g) => g.isNotEmpty).indexed)
        for (final (i, item) in group.$2.indexed)
          i == 0 && group.$1 > 0
              ? DockMenuItem(
                  item.label,
                  item.onTap,
                  checked: item.checked,
                  separated: true,
                )
              : item,
    ];
  }

  /// As opções do menu de [item].
  List<DockMenuItem> menuItems(DockItem item) {
    final pinned = state.dock.contains(item);
    final keep = pinned
        ? DockMenuItem('Remover da Dock', () => state.dock.unpin(item))
        : DockMenuItem('Manter na Dock', () => state.dock.pin(item));
    switch (item) {
      case DockApp(:final id):
        return _appMenu(id, keep);
      case DockPath(:final path):
        final parent = File(path).parent.path;
        return [
          DockMenuItem(
            item is DockFolder ? 'Abrir no Files' : 'Abrir',
            () => _open([path]),
          ),
          DockMenuItem('Mostrar no Files', () => _open([parent])),
          keep,
        ];
      case DockTrash():
        return [
          DockMenuItem('Abrir', () => unawaited(openTrash())),
          if (trashFull.value)
            DockMenuItem(
              'Esvaziar a lixeira',
              () => askEmptyTrash.value = true,
            ),
        ];
    }
  }
}
