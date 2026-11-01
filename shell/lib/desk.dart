// shell/lib/desk.dart
//
// A mesa: os itens da pasta da Área de Trabalho (vigiada), o home e a lixeira,
// a célula de cada um e o que abrir faz. A grade e as posições são do
// psito_desktop, e quem desenha é o PsitoDesktopIcons.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:psito_desktop/psito_desktop.dart';
import 'package:psito_files_ui/psito_files_ui.dart';
import 'package:psito_fs/psito_fs.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/widgets/top_bar.dart';

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

  DeskController(
    this.state, {
    required this.dir,
    required this.home,
    required this.mime,
    required this.store,
    this.userDirs = const {},
    this.env = const {},
  }) {
    state.settings.addListener(_settingsChanged);
    state.apps.addListener(_appsChanged);
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

  List<DeskItem> get items => _items;
  Map<String, DeskCell> get cells => _cells;
  Set<String> get selected => _selection.keys;
  String? get cursor => _selection.cursor;

  /// O item com o campo de renomear aberto.
  String? get renaming => _renaming;

  /// A superfície do fundo tem o teclado.
  bool get keyboard => _keyboard;

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
    final result = arrangeDesk(keys, store.cells, grid);
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
  Future<void> rename(String key, String name) async {
    final entry = _item(key)?.entry;
    stopRename();
    if (entry == null) return;
    try {
      await renameEntry(entry.path, name);
    } on Exception catch (e) {
      _warn('Sem como renomear', _message(e));
      return;
    }
    // Antes do reload: o nome novo não pode cair na primeira célula livre
    if (store.cells[key] case final cell?) await store.put({name: cell});
    _selection.only(name);
    await reload();
  }

  /// Cria uma pasta na mesa, já com o nome em edição, como no Files.
  Future<void> newFolder() async {
    final dir = this.dir;
    if (dir == null) return;
    final String path;
    try {
      (path, _) = await createFolder(dir, trash: state.dockUi.trash);
    } on Exception catch (e) {
      _warn('Sem como criar a pasta', _message(e));
      return;
    }
    await reload();
    startRename(baseName(path));
  }

  /// Joga a seleção na lixeira. O home e a lixeira ficam.
  Future<void> trashSelected() async {
    final trash = state.dockUi.trash;
    final paths = [
      for (final item in _items)
        if (selected.contains(item.key) && item.entry != null) item.entry!.path,
    ];
    if (trash == null || paths.isEmpty) return;
    try {
      await trashEntries(trash, paths);
    } on Exception catch (e) {
      _warn('Sem como mover para a lixeira', _message(e));
    }
    await reload();
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
      _openShortcut(item, shortcut);
    } else {
      _openPath(item.entry!.path);
    }
  }

  void _openPath(String path) {
    final open = state.openPaths;
    if (open == null) return;
    unawaited(
      open([path]).catchError((Object e) {
        _warn('Sem como abrir', '$e');
      }),
    );
  }

  void _openShortcut(DeskItem item, DesktopEntry shortcut) {
    if (!deskShortcutTrusted(item.entry!)) {
      _warn(
        'Atalho não confiável',
        '"${item.name}" não é executável, e por isso não abre.',
      );
    } else if (item.broken) {
      _warn('Atalho quebrado', 'O programa de "${item.name}" não existe mais.');
    } else {
      unawaited(
        (installedFor(shortcut) ?? shortcut).launch(sandbox: state.sandbox),
      );
    }
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
    unawaited(_watch?.cancel());
    _typedTimer?.cancel();
    super.dispose();
  }
}
