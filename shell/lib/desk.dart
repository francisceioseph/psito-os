// shell/lib/desk.dart
//
// A mesa: os itens da pasta da Área de Trabalho (vigiada), o home e a lixeira,
// a célula de cada um, o que abrir faz e os menus do clique direito. A grade e
// as posições são do psito_desktop, quem desenha é o PsitoDesktopIcons, e a
// sobreposição desenha os menus.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:psito_desktop/psito_desktop.dart';
import 'package:psito_files_ui/psito_files_ui.dart';
import 'package:psito_dock/psito_dock.dart';
import 'package:psito_fs/psito_fs.dart';
import 'package:psito_runtime/psito_runtime.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/widgets/dock_menu.dart';
import 'package:system_shell/widgets/top_bar.dart';
import 'package:system_shell/widgets/transfer_indicator.dart';

import 'desktop_entries.dart';
import 'shell_state.dart';

/// Um item da mesa.
class DeskItem {
  /// O nome do arquivo, ou [homeKey] e [trashKey], que nenhum arquivo pode
  /// ter: a barra não entra em nome de arquivo.
  final String key;
  final String name;

  /// Null no home e na lixeira.
  final FsEntry? entry;

  /// O `.desktop`, num atalho que dá para abrir.
  final DesktopEntry? shortcut;

  /// O atalho não acha o programa (o app desinstalado).
  final bool broken;

  const DeskItem({
    required this.key,
    required this.name,
    this.entry,
    this.shortcut,
    this.broken = false,
  });

  static const homeKey = '/home';
  static const trashKey = '/trash';
}

/// Um copiar ou mover da mesa em andamento.
class _DeskJob {
  final FileJob job;
  final String label;
  JobProgress progress = const JobProgress();

  /// Passou de [DeskController.jobDelay]: o que é rápido não pisca na top bar.
  bool visible = false;

  _DeskJob(this.job, this.label);
}

/// Uma ação que o Ctrl+Z desfaz, com as células de antes dela.
class _DeskUndo {
  final FsUndo undo;
  final Map<String, DeskCell> cells;

  const _DeskUndo(this.undo, this.cells);
}

/// Um menu da mesa aberto.
@immutable
class DeskMenuRequest {
  final String title;

  /// O ponteiro, na tela.
  final Offset at;
  final List<DockMenuItem> items;

  const DeskMenuRequest(this.title, this.at, this.items);
}

/// Um atalho não confiável esperando resposta.
@immutable
class DeskTrustRequest {
  final String name;
  final VoidCallback onTrust;

  const DeskTrustRequest(this.name, this.onTrust);
}

class DeskController extends ChangeNotifier implements FileIconEnv {
  final ShellState state;

  /// A pasta da mesa. Null: o `user-dirs.dirs` não tem (só o home e a
  /// lixeira).
  final String? dir;
  final String home;
  @override
  final MimeDatabase mime;
  final DeskStore store;
  final Map<UserDir, String> userDirs;
  final Map<String, String> env;
  final PsitoClipboard clipboard;

  /// Abre um atalho. Os testes trocam.
  final Future<void> Function(DesktopEntry app) launchEntry;

  /// Quanto um trabalho anda antes de aparecer na top bar.
  final Duration jobDelay;

  DeskController(
    this.state, {
    required this.dir,
    required this.home,
    required this.mime,
    required this.store,
    this.userDirs = const {},
    this.env = const {},
    PsitoClipboard? clipboard,
    Future<void> Function(DesktopEntry app)? launchEntry,
    this.jobDelay = const Duration(milliseconds: 500),
  }) : clipboard = clipboard ?? PsitoClipboard.instance,
       launchEntry =
           launchEntry ?? ((app) => app.launch(sandbox: state.sandbox)) {
    state.settings.addListener(_settingsChanged);
    state.apps.addListener(_appsChanged);
    state.deskMenu.addListener(notifyListeners);
    this.clipboard.current.addListener(notifyListeners);
    _settings = state.settings.value;
  }

  late PsitoSettings _settings;
  List<FsEntry> _entries = const [];
  Map<String, DesktopEntry> _shortcuts = const {};
  List<DeskItem> _items = const [];
  Map<String, DeskCell> _cells = const {};
  DeskGrid? _grid;
  final _selection = DeskSelection();
  String? _renaming;
  bool _keyboard = false;
  bool _keysLive = false;
  String _typed = '';
  Timer? _typedTimer;
  StreamSubscription<void>? _watch;

  /// As células de quem está chegando: o nome ainda não pode ir para o
  /// [store], que esquece quem não está na pasta.
  final _arriving = <String, DeskCell>{};
  String? _deviceKey;
  bool _deviceSame = false;
  bool _disposed = false;
  final _jobs = <_DeskJob>[];
  final _undo = <_DeskUndo>[];

  List<DeskItem> get items => _items;
  Map<String, DeskCell> get cells => _cells;
  Set<String> get selected => _selection.keys;
  String? get cursor => _selection.cursor;

  /// O item com o campo de renomear aberto.
  String? get renaming => _renaming;

  /// A superfície do fundo tem o teclado.
  bool get keyboard => _keyboard;

  /// Um menu da mesa está aberto.
  bool get menuOpen => state.deskMenu.value != null;

  /// Se [item] foi recortado e espera o colar.
  bool isCut(DeskItem item) {
    final clip = clipboard.current.value;
    return clip != null &&
        clip.cut &&
        item.entry != null &&
        clip.paths.contains(item.entry!.path);
  }

  /// Se dá para criar um atalho aqui.
  bool get canCreateShortcut => dir != null && _settings.desktopShowIcons;

  @override
  String? folderIcon(String path) {
    if (path == home) return 'user-home';
    for (final MapEntry(key: dir, value: dirPath) in userDirs.entries) {
      if (dirPath == path) return dir.icon;
    }
    return null;
  }

  /// O que a top bar e a dock tiram da tela. A célula conta a partir daqui.
  EdgeInsets get insets {
    final zone = state.dockUi.exclusiveZone.toDouble();
    return EdgeInsets.only(
      top: TopBar.height,
      left: _settings.dockPosition == PsitoDockPosition.left ? zone : 0,
      right: _settings.dockPosition == PsitoDockPosition.right ? zone : 0,
      bottom: _settings.dockPosition == PsitoDockPosition.bottom ? zone : 0,
    );
  }

  /// Lista a pasta e passa a vigiar.
  Future<void> start() async {
    final dir = this.dir;
    if (dir != null) {
      try {
        await Directory(dir).create(recursive: true);
        _watch = watchDirectory(dir).listen(
          (_) => unawaited(reload()),
          onError: (Object e) => debugPrint('🦜 mesa: sem vigiar $dir ($e)'),
        );
      } on FileSystemException catch (e) {
        debugPrint('🦜 mesa: sem a pasta $dir ($e)');
      }
    }
    await reload();
  }

  Future<void> reload() async {
    final dir = this.dir;
    if (dir != null) {
      try {
        final listed = await listDirectory(dir, mime);
        _entries = sortEntries(
          listed.where((entry) => !entry.hidden),
          const FsSort(),
        );
        _shortcuts = await _readShortcuts(_entries);
        unawaited(
          store.retain({
            for (final entry in _entries) entry.name,
            DeskItem.homeKey,
            DeskItem.trashKey,
          }),
        );
      } on FileSystemException catch (e) {
        // Fica o que estava: a pasta volta, e as posições também
        debugPrint('🦜 mesa: sem listar $dir ($e)');
      }
    }
    _rebuild();
  }

  Future<Map<String, DesktopEntry>> _readShortcuts(
    List<FsEntry> entries,
  ) async {
    final out = <String, DesktopEntry>{};
    for (final entry in entries) {
      if (!isDeskShortcut(entry) || entry.size > _maxShortcutBytes) continue;
      try {
        final parsed = DesktopEntry.parse(
          entry.name.substring(0, entry.name.length - '.desktop'.length),
          await File(entry.path).readAsString(),
          locale: env['LANG'],
          path: entry.path,
        );
        if (parsed != null) out[entry.name] = parsed;
      } on FileSystemException catch (e) {
        debugPrint('🦜 mesa: sem ler ${entry.path} ($e)');
      }
    }
    return out;
  }

  /// Um `.desktop` maior que isso não é um atalho.
  static const _maxShortcutBytes = 1 << 20;

  /// O app instalado a que o atalho aponta: o de mesmo id ou de mesmo `Exec`.
  /// É ele que abre, com o sandbox dele, e não o `Exec` do arquivo.
  DesktopEntry? installedFor(DesktopEntry shortcut) {
    if (state.installed(shortcut.id) case final app?) return app;
    for (final app in state.apps.value) {
      if (listEquals(app.exec, shortcut.exec)) return app;
    }
    return null;
  }

  bool _onPath(String program) {
    if (program.contains('/')) return File(program).existsSync();
    for (final dir in (env['PATH'] ?? '').split(':')) {
      if (dir.isNotEmpty && File('$dir/$program').existsSync()) return true;
    }
    return false;
  }

  void _rebuild() {
    final show = _settings.desktopShowIcons;
    _items = !show
        ? const []
        : [
            if (_settings.desktopShowHome)
              const DeskItem(key: DeskItem.homeKey, name: 'Pasta pessoal'),
            if (_settings.desktopShowTrash)
              const DeskItem(key: DeskItem.trashKey, name: 'Lixeira'),
            for (final entry in _entries) _itemFor(entry),
          ];
    _arrange();
    notifyListeners();
  }

  DeskItem _itemFor(FsEntry entry) {
    final shortcut = _shortcuts[entry.name];
    if (shortcut == null) {
      return DeskItem(key: entry.name, name: entry.name, entry: entry);
    }
    return DeskItem(
      key: entry.name,
      name: shortcut.name,
      entry: entry,
      shortcut: shortcut,
      broken:
          installedFor(shortcut) == null && !_onPath(shortcut.command.first),
    );
  }

  void _arrange() {
    final grid = _grid;
    if (grid == null) return;
    final keys = [for (final item in _items) item.key];
    _selection.retain(keys.toSet());
    if (!keys.contains(_renaming)) _renaming = null;
    if (_settings.desktopAutoArrange) {
      _cells = packDesk(keys, grid);
      return;
    }
    final result = arrangeDesk(keys, {...store.cells, ..._arriving}, grid);
    _cells = result.cells;
    unawaited(store.put(result.placed));
  }

  /// A grade que cabe na tela: o tamanho só se sabe ao desenhar.
  void setGrid(DeskGrid grid) {
    if (grid == _grid) return;
    _grid = grid;
    _arrange();
    notifyListeners();
  }

  // O Flutter guarda as teclas apertadas, e uma tecla solta noutra superfície
  // deixaria o Ctrl preso. Só vale o que chegou desde que a mesa tem o teclado
  bool get _ctrl => _keysLive && HardwareKeyboard.instance.isControlPressed;
  bool get _shift => _keysLive && HardwareKeyboard.instance.isShiftPressed;

  void setKeyboard(bool focused) {
    if (focused == _keyboard) return;
    _keyboard = focused;
    if (!focused) _keysLive = false;
    notifyListeners();
  }

  void press(String? key, {bool? ctrl, bool? shift}) {
    _selection.press(key, _cells, ctrl: ctrl ?? _ctrl, shift: shift ?? _shift);
    notifyListeners();
  }

  void release(String key, {bool? ctrl, bool? shift}) {
    _selection.release(key, ctrl: ctrl ?? _ctrl, shift: shift ?? _shift);
    notifyListeners();
  }

  void selectRect(Set<String> keys) {
    _selection.rect(deskOrder(_cells).where(keys.contains));
    notifyListeners();
  }

  /// O teclado da mesa. A superfície sem o foco pode ter recebido a tecla por
  /// causa do foco do Flutter, que é um só para todas as views: um Delete no
  /// painel não pode ir para a lixeira.
  KeyEventResult handleKey(KeyEvent event) {
    _keysLive = true;
    if (event is KeyUpEvent || !_keyboard || _renaming != null) {
      return KeyEventResult.ignored;
    }
    final handled = key(
      event.logicalKey,
      ctrl: HardwareKeyboard.instance.isControlPressed,
      shift: HardwareKeyboard.instance.isShiftPressed,
      alt: HardwareKeyboard.instance.isAltPressed,
      character: event.character,
    );
    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  /// Uma tecla apertada; devolve se ela fez alguma coisa.
  bool key(
    LogicalKeyboardKey key, {
    bool ctrl = false,
    bool shift = false,
    bool alt = false,
    String? character,
  }) {
    bool done(void Function() action) {
      action();
      notifyListeners();
      return true;
    }

    void arrow(int dx, int dy) =>
        _selection.arrow(_cells, dx, dy, shift: shift);

    if (ctrl && shift && key == LogicalKeyboardKey.keyN) {
      unawaited(newFolder());
      return true;
    }
    if (ctrl && key == LogicalKeyboardKey.keyA) {
      return done(() => _selection.all(_cells));
    }
    if (ctrl && !shift && key == LogicalKeyboardKey.keyC) {
      copySelected();
      return true;
    }
    if (ctrl && !shift && key == LogicalKeyboardKey.keyX) {
      copySelected(cut: true);
      return true;
    }
    if (ctrl && !shift && key == LogicalKeyboardKey.keyV) {
      unawaited(paste());
      return true;
    }
    if (ctrl && !shift && key == LogicalKeyboardKey.keyZ) {
      unawaited(undo());
      return true;
    }
    if (ctrl || alt) return false;
    switch (key) {
      case LogicalKeyboardKey.arrowUp:
        return done(() => arrow(0, -1));
      case LogicalKeyboardKey.arrowDown:
        return done(() => arrow(0, 1));
      case LogicalKeyboardKey.arrowLeft:
        return done(() => arrow(-1, 0));
      case LogicalKeyboardKey.arrowRight:
        return done(() => arrow(1, 0));
      case LogicalKeyboardKey.escape:
        return done(_selection.clear);
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        deskOrder(_cells).where(selected.contains).forEach(open);
        return true;
      case LogicalKeyboardKey.f2:
        if (selected.length == 1) startRename(selected.single);
        return true;
      case LogicalKeyboardKey.delete:
        unawaited(trashSelected());
        return true;
      case LogicalKeyboardKey.space:
        _preview();
        return true;
    }
    if (character != null && character.trim().isNotEmpty) {
      return done(() => _typeAhead(character));
    }
    return false;
  }

  /// Digitar o começo do nome seleciona o primeiro que começa assim.
  void _typeAhead(String text) {
    _typedTimer?.cancel();
    _typedTimer = Timer(const Duration(seconds: 1), () => _typed = '');
    _typed += foldName(text);
    final byKey = {for (final item in _items) item.key: item};
    for (final key in deskOrder(_cells)) {
      if (foldName(byKey[key]?.name ?? '').startsWith(_typed)) {
        _selection.only(key);
        return;
      }
    }
  }

  DeskItem? _item(String key) {
    for (final item in _items) {
      if (item.key == key) return item;
    }
    return null;
  }

  /// Abre o campo de renomear. O home e a lixeira não têm nome de arquivo.
  void startRename(String key) {
    if (_item(key)?.entry == null) return;
    _selection.only(key);
    _renaming = key;
    notifyListeners();
  }

  void stopRename() {
    if (_renaming == null) return;
    _renaming = null;
    notifyListeners();
  }

  /// Renomeia, levando a célula para o nome novo. Um nome que não serve avisa.
  /// Num atalho, o que muda é o `Name=`, que é o que a mesa mostra.
  Future<void> rename(String key, String name) async {
    final item = _item(key);
    final entry = item?.entry;
    stopRename();
    if (entry == null) return;
    if (item?.shortcut != null) {
      await _renameShortcut(entry.path, name);
      return;
    }
    try {
      final (_, undo) = await renameEntry(entry.path, name);
      _pushUndo(undo, _cellsOf([key]));
    } on Exception catch (e) {
      _warn('Sem como renomear', _message(e));
      return;
    }
    // Antes do reload: o nome novo não pode cair na primeira célula livre
    if (store.cells[key] case final cell?) await store.put({name: cell});
    _selection.only(name);
    await reload();
  }

  Future<void> _renameShortcut(String path, String name) async {
    try {
      final file = File(path);
      final text = await file.readAsString();
      await file.writeAsString(renamedDeskShortcut(text, name));
      _pushUndo(
        FsUndo('Renomear', () async {
          await file.writeAsString(text);
        }),
      );
    } on FileSystemException catch (e) {
      _warn('Sem como renomear', e.message);
    }
    await reload();
  }

  /// Cria uma pasta na mesa (na célula de [at]), já com o nome em edição, como
  /// no Files.
  Future<void> newFolder({Offset? at}) async {
    final dir = this.dir;
    if (dir == null) return;
    final String path;
    try {
      final FsUndo undo;
      (path, undo) = await createFolder(dir, trash: state.dockUi.trash);
      _pushUndo(undo);
    } on Exception catch (e) {
      _warn('Sem como criar a pasta', _message(e));
      return;
    }
    await _placeAt(baseName(path), at);
    await reload();
    startRename(baseName(path));
  }

  /// Joga a seleção na lixeira. O home e a lixeira ficam.
  Future<void> trashSelected() => _trashPaths([
    for (final item in _items)
      if (selected.contains(item.key) && item.entry != null) item.entry!.path,
  ]);

  Future<void> _trashPaths(List<String> paths) async {
    final trash = state.dockUi.trash;
    if (trash == null || paths.isEmpty) return;
    final cells = _cellsOf(_namesHere(paths));
    try {
      final (_, undo) = await trashEntries(trash, paths);
      _pushUndo(undo, cells);
    } on Exception catch (e) {
      _warn('Sem como mover para a lixeira', _message(e));
    }
    await reload();
  }

  // Desfazer

  bool get canUndo => _undo.isNotEmpty;
  String? get undoLabel => _undo.lastOrNull?.undo.label;

  void _pushUndo(FsUndo undo, [Map<String, DeskCell> cells = const {}]) {
    _undo.add(_DeskUndo(undo, cells));
    if (_undo.length > 50) _undo.removeAt(0);
  }

  /// O Ctrl+Z: desfaz a última ação, e quem volta para a mesa volta para a
  /// célula de antes. Até o arquivo voltar, a célula fica em [_arriving], porque
  /// o [store] esquece quem não está na pasta.
  Future<void> undo() async {
    if (_undo.isEmpty) return;
    final last = _undo.removeLast();
    _arriving.addAll(last.cells);
    try {
      await last.undo.run();
    } on Exception catch (e) {
      _warn('Sem como desfazer', _message(e));
    }
    await store.put(last.cells);
    _arriving.removeWhere((name, _) => last.cells.containsKey(name));
    await reload();
  }

  /// As células de agora de [keys].
  Map<String, DeskCell> _cellsOf(Iterable<String> keys) => {
    for (final key in keys) key: ?_cells[key],
  };

  /// Os nomes dos que estão na pasta da mesa, entre [paths].
  List<String> _namesHere(List<String> paths) => [
    for (final path in paths)
      if (dirName(path) == dir) baseName(path),
  ];

  /// O desfazer de algo novo que apareceu em [path]: vai para a lixeira.
  FsUndo _undoCreate(String label, String path) => FsUndo(label, () async {
    if (FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound) {
      await state.dockUi.trash?.trash(path);
    }
  });

  /// Guarda a célula de [at] (a mais perto, se tiver alguém nela) para [name],
  /// antes do reload: ele não pode cair na primeira célula livre.
  Future<void> _placeAt(String name, Offset? at) async {
    if (at != null) await store.put(_cellsNear([name], at));
  }

  /// A célula embaixo de [at], na área livre.
  DeskCell _cellAt(DeskGrid grid, Offset at) {
    final free = insets;
    return deskCellAt(
      at - free.topLeft,
      state.dockUi.screen.width - free.horizontal,
      grid,
      _settings.desktopIconSize,
    );
  }

  /// Uma célula livre para cada um de [names], a partir de [at].
  Map<String, DeskCell> _cellsNear(List<String> names, Offset at) {
    final grid = _grid;
    if (grid == null) return const {};
    final cell = _cellAt(grid, at);
    final taken = {
      for (final MapEntry(:key, :value) in _cells.entries)
        if (!names.contains(key)) value,
      ..._arriving.values,
    };
    return {
      for (final name in names)
        name: () {
          final free = nearestFreeCell(cell, grid, taken) ?? cell;
          taken.add(free);
          return free;
        }(),
    };
  }

  /// Os caminhos selecionados, sem o home e a lixeira.
  List<String> get _selectedPaths => [
    for (final key in deskOrder(_cells))
      if (selected.contains(key))
        if (_item(key)?.entry case final entry?) entry.path,
  ];

  void copySelected({bool cut = false}) {
    final paths = _selectedPaths;
    if (paths.isNotEmpty) unawaited(clipboard.copy(paths, cut: cut));
  }

  /// Traz para a mesa o que está copiado, aqui ou em outro app. Um nome que já
  /// existe fica com os dois.
  Future<void> paste() async {
    final dir = this.dir;
    if (dir == null) return;
    final clip = await clipboard.read();
    if (clip == null) return;
    if (clip.cut) await clipboard.clear();
    final sources = [
      for (final path in clip.paths)
        if (!(clip.cut && dirName(path) == dir)) path,
    ];
    if (sources.isEmpty) return;
    await _transfer(
      clip.cut ? JobKind.move : JobKind.copy,
      sources,
      dir,
      failure: 'Sem como colar',
    );
  }

  /// Copia ou move [sources] para [folder]. O que chega na mesa fica
  /// selecionado, e nas células de [_arriving].
  Future<void> _transfer(
    JobKind kind,
    List<String> sources,
    String folder, {
    required String failure,
    Set<String> arriving = const {},
  }) async {
    final left = kind == JobKind.move
        ? _cellsOf(_namesHere(sources))
        : const <String, DeskCell>{};
    final result = await _track(
      FileJob.start(kind, sources, destination: folder),
      kind == JobKind.move ? 'Movendo' : 'Copiando',
    );
    // O dispose cancela os trabalhos, e este volta depois dele
    if (_disposed) return;
    if (result.errors.isNotEmpty) _warn(failure, result.errors.join('\n'));
    final trash = state.dockUi.trash;
    if (result.done.isNotEmpty && trash != null) {
      _pushUndo(FileJob.undoFor(kind, result, trash), left);
    }
    final names = {for (final (_, to) in result.done) baseName(to)};
    if (folder == dir) {
      await store.put({for (final name in names) name: ?_arriving[name]});
    }
    _arriving.removeWhere((name, _) => arriving.contains(name));
    await reload();
    if (folder == dir) {
      _selection.press(null, _cells);
      selectRect(names);
    }
  }

  /// Acompanha [job] na top bar até terminar.
  Future<JobResult> _track(FileJob job, String label) async {
    final running = _DeskJob(job, label);
    _jobs.add(running);
    final delay = Timer(jobDelay, () {
      running.visible = true;
      _publishJobs();
    });
    final progress = job.progress.listen((value) {
      running.progress = value;
      _publishJobs();
    });
    final result = await job.result;
    delay.cancel();
    await progress.cancel();
    _jobs.remove(running);
    _publishJobs();
    return result;
  }

  /// O primeiro trabalho visível, com a conta dos outros.
  void _publishJobs() {
    final visible = _jobs.where((running) => running.visible).toList();
    final first = visible.firstOrNull;
    if (first == null) {
      state.deskTransfer.value = null;
      return;
    }
    final p = first.progress;
    final what = p.current == null ? '' : ' "${p.current}"';
    final more = visible.length > 1 ? ' (e mais ${visible.length - 1})' : '';
    state.deskTransfer.value = TransferStatus(
      '${first.label}$what$more',
      p.totalItems == 0 ? null : p.fraction,
    );
  }

  /// O X da top bar.
  void cancelJobs() {
    for (final running in _jobs) {
      running.job.cancel();
    }
  }

  // Arrastar

  /// Com o botão apertado num item fora da seleção, só ele vai.
  void dragStarted(String key) {
    if (selected.contains(key)) return;
    _selection.only(key);
    notifyListeners();
  }

  /// Leva os arquivos de [keys] para fora da mesa, pela view [viewId].
  void dragOut(int viewId, Set<String> keys, Uint8List? icon, Offset hotspot) {
    final paths = [
      for (final key in deskOrder(_cells))
        if (keys.contains(key))
          if (_item(key)?.entry case final entry?) entry.path,
    ];
    if (paths.isEmpty) return;
    unawaited(
      PsitoDnd.instance.startDrag(viewId, paths, icon: icon, hotspot: hotspot),
    );
  }

  /// Soltou [keys] na mesa, com [grabbed] no ponto [at]. Organizando sozinha,
  /// deixa de organizar: quem soltou escolheu o lugar, e as células de agora
  /// ficam guardadas para o resto não mudar.
  void moveKeys(String grabbed, Set<String> keys, Offset at) {
    final grid = _grid;
    if (grid == null) return;
    final moved = moveDeskCells(
      _cells,
      deskOrder(_cells).where(keys.contains).toList(),
      grabbed,
      _cellAt(grid, at),
      grid,
    );
    if (moved.isEmpty) return;
    final auto = _settings.desktopAutoArrange;
    _pushUndo(
      FsUndo('Mover', () async {
        if (!auto) return;
        await state.settings.update(
          state.settings.value.copyWith(desktopAutoArrange: true),
        );
      }),
      _cellsOf(moved.keys),
    );
    unawaited(store.put({if (auto) ..._cells, ...moved}));
    if (auto) {
      unawaited(
        state.settings.update(
          state.settings.value.copyWith(desktopAutoArrange: false),
        ),
      );
    }
    _rebuild();
  }

  /// Se o item recebe arquivos soltos em cima dele.
  bool acceptsDrops(String key) {
    if (key == DeskItem.trashKey || key == DeskItem.homeKey) return true;
    final item = _item(key);
    return item != null &&
        (item.shortcut != null || (item.entry?.isDirectory ?? false));
  }

  /// A pasta para onde vai o que se solta em [key] (null: a mesa).
  String? _dropFolder(String? key) {
    if (key == null) return canCreateShortcut ? dir : null;
    if (key == DeskItem.homeKey) return home;
    final entry = _item(key)?.entry;
    return entry != null && entry.isDirectory ? entry.path : null;
  }

  /// O app em que abre o que se solta em [key], se for um atalho.
  DockApp? _dropApp(String? key) {
    final shortcut = key == null ? null : _item(key)?.shortcut;
    final app = shortcut == null ? null : installedFor(shortcut);
    return app == null ? null : DockApp(app.id);
  }

  /// Com que ação [key] (null: a mesa) aceita [paths]. Null recusa. A resposta
  /// do disco chega depois: até lá é copiar, que não perde nada, e o próximo
  /// movimento do ponteiro já vê.
  DropAction? dropAction(String? key, List<String> paths) {
    if (paths.isEmpty) return null;
    if (key == DeskItem.trashKey) {
      return state.dockUi.dropAction(const DockTrash(), paths);
    }
    if (_dropApp(key) case final app?) {
      return state.dockUi.dropAction(app, paths);
    }
    final folder = _dropFolder(key);
    if (folder == null || paths.any((path) => isWithin(path, folder))) {
      return null;
    }
    return _sameDevice(paths, folder) ? DropAction.move : DropAction.copy;
  }

  bool _sameDevice(List<String> paths, String folder) {
    final key = [folder, ...paths].join('\n');
    if (key != _deviceKey) {
      _deviceKey = key;
      _deviceSame = false;
      unawaited(
        sameDevice(paths, folder).then((same) {
          if (key == _deviceKey) _deviceSame = same;
        }),
      );
    }
    return _deviceSame;
  }

  /// [paths] de fora soltos em [key] (null: a mesa, no ponto [at]). A cópia não
  /// segura o soltar: o outro app fica esperando a resposta.
  Future<bool> drop(
    String? key,
    List<String> paths,
    DropAction action, {
    Offset? at,
  }) async {
    if (dropAction(key, paths) == null) return false;
    if (key == DeskItem.trashKey) {
      await _trashPaths(paths);
      await state.dockUi.refreshTrash();
      return true;
    }
    if (_dropApp(key) case final app?) {
      return state.dockUi.dropOn(app, paths);
    }
    final folder = _dropFolder(key)!;
    // Quem já está na pasta só muda de célula
    final sources = [
      for (final path in paths)
        if (dirName(path) != folder) path,
    ];
    var arriving = const <String, DeskCell>{};
    if (key == null && at != null && !_settings.desktopAutoArrange) {
      final here = [
        for (final path in paths)
          if (dirName(path) == folder) baseName(path),
      ];
      if (here.isNotEmpty) {
        await store.put(_cellsNear(here, at));
        _rebuild();
      }
      arriving = _cellsNear([
        for (final path in sources) uniqueName(folder, baseName(path)),
      ], at);
      _arriving.addAll(arriving);
    }
    if (sources.isNotEmpty) {
      unawaited(
        _transfer(
          action == DropAction.move ? JobKind.move : JobKind.copy,
          sources,
          folder,
          failure: 'Sem como trazer para a mesa',
          arriving: arriving.keys.toSet(),
        ),
      );
    }
    return true;
  }

  List<String> _pathsOf(Set<String> keys) => [
    for (final key in keys)
      if (_item(key)?.entry case final entry?) entry.path,
  ];

  /// Se [target] aceita [keys], arrastados na própria mesa.
  bool canDropOn(String target, Set<String> keys) =>
      acceptsDrops(target) && dropAction(target, _pathsOf(keys)) != null;

  /// [keys] soltos em cima de [target], dentro da mesa: é sempre mover.
  void dropOn(String target, Set<String> keys) =>
      unawaited(drop(target, _pathsOf(keys), DropAction.move));

  /// O atalho de [app] na mesa, já executável: uma cópia do `.desktop`, que
  /// fica na célula de [at]. Se já tem um, é ele que vai para lá.
  Future<void> createShortcut(DesktopEntry app, {Offset? at}) async {
    final dir = this.dir, source = app.path;
    if (!canCreateShortcut || dir == null || source == null) return;
    for (final item in _items) {
      final shortcut = item.shortcut;
      if (shortcut != null && installedFor(shortcut)?.id == app.id) {
        await _placeAt(item.key, at);
        _selection.only(item.key);
        _rebuild();
        return;
      }
    }
    final name = uniqueName(dir, '${app.id}.desktop');
    final path = joinPath(dir, name);
    try {
      await File(source).copy(path);
      await _trust(path);
    } on Exception catch (e) {
      _warn('Sem como criar o atalho', '$e');
      return;
    }
    _pushUndo(_undoCreate('Criar atalho', path));
    await _placeAt(name, at);
    await reload();
    _selection.only(name);
    notifyListeners();
  }

  /// Dá o `+x`, e tira a escrita dos outros, que tira a confiança.
  Future<void> _trust(String path) async {
    final result = await Process.run('chmod', ['u+x,go-w', path]);
    if (result.exitCode != 0) {
      throw FileSystemException('${result.stderr}'.trim(), path);
    }
  }

  /// Cria um documento na mesa, em branco ou a partir de [template], já com o
  /// nome em edição.
  Future<void> newDocument({String? template, Offset? at}) async {
    final dir = this.dir;
    if (dir == null) return;
    final name = uniqueName(
      dir,
      template == null ? 'Novo documento.txt' : baseName(template),
    );
    final path = joinPath(dir, name);
    try {
      if (template == null) {
        await File(path).create(exclusive: true);
      } else {
        await File(template).copy(path);
      }
    } on FileSystemException catch (e) {
      _warn('Sem como criar o documento', e.message);
      return;
    }
    _pushUndo(_undoCreate('Novo documento', path));
    await _placeAt(name, at);
    await reload();
    startRename(name);
  }

  /// "Organizar por": as chaves na ordem de [key], sem buracos. Os itens fixos
  /// vêm primeiro. Por nome, vale o que a mesa mostra: o `Name=` de um atalho, e
  /// não o nome do arquivo.
  void arrangeBy(FsSortKey key) {
    _pushUndo(FsUndo('Organizar', () async {}), {..._cells});
    final fixed = [
      for (final item in _items)
        if (item.entry == null) item.key,
    ];
    if (key != FsSortKey.name) {
      _pack([
        ...fixed,
        for (final entry in sortEntries(
          _entries,
          FsSort(key: key, ascending: key == FsSortKey.kind),
        ))
          entry.name,
      ]);
      return;
    }
    final files = _items.where((item) => item.entry != null).toList()
      ..sort((a, b) {
        if (a.entry!.isDirectory != b.entry!.isDirectory) {
          return a.entry!.isDirectory ? -1 : 1;
        }
        return naturalCompare(foldName(a.name), foldName(b.name));
      });
    _pack([...fixed, for (final item in files) item.key]);
  }

  /// "Limpar": tira os buracos, na ordem em que estão.
  void cleanUp() {
    _pushUndo(FsUndo('Limpar', () async {}), {..._cells});
    _pack(deskOrder(_cells));
  }

  void _pack(List<String> keys) {
    final grid = _grid;
    if (grid == null) return;
    unawaited(store.put(packDesk(keys, grid)));
    _rebuild();
  }

  /// O Espaço: abre o item no Quick Look do Files.
  void _preview() {
    final key = _selection.cursor;
    final path = key == null ? null : _item(key)?.entry?.path;
    final preview = state.previewPath;
    if (path == null || preview == null) return;
    unawaited(
      preview(path).catchError((Object e) {
        _warn('Sem como pré-visualizar', '$e');
      }),
    );
  }

  String _message(Exception e) => e is FsError ? e.message : '$e';

  void _settingsChanged() {
    final old = _settings, now = state.settings.value;
    _settings = now;
    if (old.desktopShowIcons != now.desktopShowIcons ||
        old.desktopShowHome != now.desktopShowHome ||
        old.desktopShowTrash != now.desktopShowTrash ||
        old.desktopAutoArrange != now.desktopAutoArrange) {
      _rebuild();
    } else if (old != now) {
      // O tamanho, a dock ou o tema: a view recalcula a grade
      notifyListeners();
    }
  }

  // Um app instalado ou removido conserta ou quebra os atalhos
  void _appsChanged() => _rebuild();

  void open(String key) {
    if (_item(key) case final item?) _openItem(item);
  }

  void _openItem(DeskItem item) {
    if (item.key == DeskItem.trashKey) {
      unawaited(state.dockUi.openTrash());
    } else if (item.key == DeskItem.homeKey) {
      _openPath(home);
    } else if (item.shortcut case final shortcut?) {
      unawaited(_openShortcut(item, shortcut));
    } else {
      _openPath(item.entry!.path);
    }
  }

  void _openPath(String path, {String? withApp}) {
    final open = state.openPaths;
    if (open == null) return;
    unawaited(
      open([path], withApp: withApp).catchError((Object e) {
        _warn('Sem como abrir', '$e');
      }),
    );
  }

  // Só abre direto se for executável e do próprio usuário. O FileStat não traz
  // o dono, então quem responde é o `test -O`
  Future<void> _openShortcut(DeskItem item, DesktopEntry shortcut) async {
    final path = item.entry!.path;
    if (item.broken) {
      _warn('Atalho quebrado', 'O programa de "${item.name}" não existe mais.');
    } else if (deskShortcutTrusted(item.entry!) &&
        (await Process.run('test', ['-O', path])).exitCode == 0) {
      await _launchShortcut(shortcut);
    } else {
      state.deskTrust.value = DeskTrustRequest(
        item.name,
        () => unawaited(_trustAndOpen(path, shortcut)),
      );
    }
  }

  Future<void> _trustAndOpen(String path, DesktopEntry shortcut) async {
    try {
      await _trust(path);
    } on FileSystemException catch (e) {
      _warn('Sem como confiar no atalho', e.message);
      return;
    }
    await reload();
    await _launchShortcut(shortcut);
  }

  Future<void> _launchShortcut(DesktopEntry shortcut) =>
      launchEntry(installedFor(shortcut) ?? shortcut);

  // Menus

  /// O clique direito: num item fora da seleção, só ele fica selecionado; na
  /// mesa vazia, a seleção limpa. Um arquivo copiado em outro app só se vê
  /// agora, porque a mesa acabou de ganhar o teclado.
  Future<void> openMenu(String? key, Offset at) async {
    if (key == null) {
      _selection.clear();
    } else if (!selected.contains(key)) {
      _selection.only(key);
    }
    notifyListeners();
    // Um dono travado não pode segurar o menu
    final clip = await clipboard.read().timeout(
      const Duration(milliseconds: 300),
      onTimeout: () => clipboard.current.value,
    );
    final item = key == null ? null : _item(key);
    if (item == null) {
      _showMenu('Área de trabalho', at, _deskMenu(clip, at));
    } else if (selected.length > 1) {
      _showMenu('${selected.length} itens', at, _selectionMenu());
    } else {
      _showMenu(item.name, at, _itemMenu(item, at));
    }
  }

  void _showMenu(String title, Offset at, List<DockMenuItem> items) =>
      state.deskMenu.value = DeskMenuRequest(title, at, items);

  void closeMenu() => state.deskMenu.value = null;

  List<DockMenuItem> _deskMenu(FileClip? clip, Offset at) {
    final count = clip?.paths.length ?? 0;
    final auto = _settings.desktopAutoArrange;
    final terminal = _terminal;
    return [
      DockMenuItem('Nova pasta', () => unawaited(newFolder(at: at))),
      DockMenuItem(
        'Novo documento…',
        () => unawaited(_templatesMenu(at)),
        keepsOpen: true,
      ),
      DockMenuItem(
        count > 1 ? 'Colar $count itens' : 'Colar',
        () => unawaited(paste()),
        enabled: count > 0,
      ),
      DockMenuItem(
        canUndo ? 'Desfazer $undoLabel' : 'Desfazer',
        () => unawaited(undo()),
        enabled: canUndo,
      ),
      DockMenuItem(
        'Organizar por…',
        () => _arrangeMenu(at),
        keepsOpen: true,
        separated: true,
        enabled: !auto,
      ),
      DockMenuItem('Limpar', cleanUp, enabled: !auto),
      DockMenuItem(
        'Abrir no Files',
        () => _openPath(dir ?? home),
        separated: true,
      ),
      if (terminal != null)
        DockMenuItem(
          'Abrir o terminal aqui',
          () => unawaited(terminal.launch(workingDirectory: dir ?? home)),
        ),
      if (state.installed('org.psito.settings') case final settings?)
        DockMenuItem(
          'Mudar o papel de parede',
          () => unawaited(
            settings.launch(
              sandbox: state.sandbox,
              command: [
                ...settings.command,
                '${psitoSettingsSectionPrefix}appearance',
              ],
            ),
          ),
        ),
    ];
  }

  /// O foot, que vem com o Psito, ou outro terminal instalado.
  DesktopEntry? get _terminal {
    if (state.installed('foot') case final foot?) return foot;
    for (final app in state.apps.value) {
      if (app.categories.contains('TerminalEmulator')) return app;
    }
    return null;
  }

  void _arrangeMenu(Offset at) => _showMenu('Organizar por', at, [
    DockMenuItem('Nome', () => arrangeBy(FsSortKey.name)),
    DockMenuItem('Tipo', () => arrangeBy(FsSortKey.kind)),
    DockMenuItem('Data', () => arrangeBy(FsSortKey.modified)),
    DockMenuItem('Tamanho', () => arrangeBy(FsSortKey.size)),
  ]);

  /// Os modelos da pasta `TEMPLATES`, como no GNOME.
  Future<void> _templatesMenu(Offset at) async {
    var templates = const <FsEntry>[];
    if (userDirs[UserDir.templates] case final dir?) {
      try {
        templates = sortEntries(
          (await listDirectory(
            dir,
            mime,
          )).where((entry) => !entry.hidden && entry.kind == FsKind.file),
          const FsSort(),
        );
      } on FileSystemException catch (e) {
        debugPrint('🦜 mesa: sem os modelos de $dir ($e)');
      }
    }
    _showMenu('Novo documento', at, [
      DockMenuItem('Documento vazio', () => unawaited(newDocument(at: at))),
      for (final (i, template) in templates.indexed)
        DockMenuItem(
          splitExtension(template.name).$1,
          () => unawaited(newDocument(template: template.path, at: at)),
          separated: i == 0,
        ),
    ]);
  }

  /// O que vale para vários itens.
  List<DockMenuItem> _selectionMenu() => [
    DockMenuItem(
      'Abrir',
      () => deskOrder(_cells).where(selected.contains).forEach(open),
    ),
    ..._fileActions(),
  ];

  List<DockMenuItem> _fileActions() => [
    DockMenuItem('Copiar', copySelected, separated: true),
    DockMenuItem('Recortar', () => copySelected(cut: true)),
    DockMenuItem('Mover para a lixeira', () => unawaited(trashSelected())),
  ];

  List<DockMenuItem> _itemMenu(DeskItem item, Offset at) {
    if (item.key == DeskItem.trashKey) {
      return [
        DockMenuItem('Abrir', () => open(item.key)),
        if (state.dockUi.trashFull.value)
          DockMenuItem(
            'Esvaziar a lixeira',
            () => state.dockUi.askEmptyTrash.value = true,
          ),
      ];
    }
    final entry = item.entry;
    if (entry == null) return [DockMenuItem('Abrir', () => open(item.key))];
    final dockItem = _dockItem(item);
    return [
      DockMenuItem('Abrir', () => open(item.key)),
      if (item.shortcut == null)
        DockMenuItem(
          'Abrir com…',
          () => _openWithMenu(item, at, mime.typeOf(entry.path)),
          keepsOpen: true,
        ),
      DockMenuItem('Renomear', () => startRename(item.key), separated: true),
      ..._fileActions(),
      DockMenuItem(
        'Mostrar no Files',
        () => _openPath(dirName(entry.path)),
        separated: true,
      ),
      if (dockItem != null && !state.dock.contains(dockItem))
        DockMenuItem(
          'Fixar na Dock',
          () => unawaited(state.dock.pin(dockItem)),
        ),
    ];
  }

  void _openWithMenu(DeskItem item, Offset at, String type) {
    final path = item.entry!.path;
    final apps = state.appsForType?.call(type) ?? const <DesktopEntry>[];
    _showMenu('Abrir com', at, [
      for (final app in apps)
        DockMenuItem(app.name, () => _openPath(path, withApp: app.id)),
      if (type.isNotEmpty)
        DockMenuItem(
          'Outro…',
          () => _openWithMenu(item, at, ''),
          keepsOpen: true,
          separated: apps.isNotEmpty,
        ),
    ]);
  }

  /// O item da dock de [item]: um atalho fixa o app instalado.
  DockItem? _dockItem(DeskItem item) {
    if (item.shortcut case final shortcut?) {
      return switch (installedFor(shortcut)) {
        final app? => DockApp(app.id),
        null => null,
      };
    }
    final entry = item.entry!;
    return entry.isDirectory ? DockFolder(entry.path) : DockFile(entry.path);
  }

  void _warn(String title, String body) {
    state.notifications.add(
      app: state.appFor('Área de trabalho', name: 'Área de trabalho'),
      title: title,
      body: body,
    );
  }

  @override
  void dispose() {
    state.settings.removeListener(_settingsChanged);
    state.apps.removeListener(_appsChanged);
    state.deskMenu.removeListener(notifyListeners);
    clipboard.current.removeListener(notifyListeners);
    unawaited(_watch?.cancel());
    _typedTimer?.cancel();
    cancelJobs();
    _disposed = true;
    super.dispose();
  }
}
