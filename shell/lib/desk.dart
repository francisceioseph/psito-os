// shell/lib/desk.dart
//
// A mesa: os itens da pasta da Área de Trabalho (vigiada), o home e a lixeira,
// a célula de cada um e o que abrir faz. A grade e as posições são do
// psito_desktop, e quem desenha é o PsitoDesktopIcons.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
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
  String? _selected;
  StreamSubscription<void>? _watch;

  List<DeskItem> get items => _items;
  Map<String, DeskCell> get cells => _cells;
  String? get selected => _selected;

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

  void select(String? key) {
    if (key == _selected) return;
    _selected = key;
    notifyListeners();
  }

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
    for (final item in _items) {
      if (item.key == key) {
        _openItem(item);
        return;
      }
    }
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
    super.dispose();
  }
}
