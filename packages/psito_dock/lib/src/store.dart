// packages/psito_dock/lib/src/store.dart
//
// Os itens fixados, na ordem, em $XDG_CONFIG_HOME/psito/dock.json. Só o
// shell usa, por isso não fica no settings.json. Um item que sumiu (o app
// desinstalado, a pasta apagada) continua no arquivo: quem esconde é o
// [dockLayout], e ele volta se o app for instalado de novo.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'item.dart';

File defaultDockFile([Map<String, String>? env]) {
  env ??= Platform.environment;
  final configHome = env['XDG_CONFIG_HOME'] ?? '${env['HOME'] ?? '.'}/.config';
  return File('$configHome/psito/dock.json');
}

class DockStore extends ValueNotifier<List<DockItem>> {
  /// Null: só em memória (testes e o laboratório).
  final File? file;

  DockStore._(List<DockItem> items, this.file)
    : super(List.unmodifiable(items));

  DockStore.memory([List<DockItem> items = const []]) : this._(items, null);

  /// Sem o arquivo (a primeira vez), começa com [initial] e grava. Um
  /// arquivo ilegível fica como está, e a dock usa [initial] sem gravar por
  /// cima, até o primeiro fixar ou tirar.
  static Future<DockStore> load(
    File file, {
    required List<DockItem> initial,
  }) async {
    if (!await file.exists()) {
      final store = DockStore._(initial, file);
      await store._save();
      return store;
    }
    return DockStore._(await _read(file) ?? initial, file);
  }

  /// Null: ilegível.
  static Future<List<DockItem>?> _read(File file) async {
    try {
      final json = jsonDecode(await file.readAsString());
      if (json case {'items': final List<Object?> items}) {
        return [for (final raw in items) ?DockItem.fromJson(raw)];
      }
      debugPrint('🦜 ${file.path} sem a lista de itens; usando a padrão');
    } catch (e) {
      debugPrint('🦜 Erro lendo ${file.path}: $e; usando a lista padrão');
    }
    return null;
  }

  bool contains(DockItem item) => value.contains(item);

  /// Fixa [item] antes de [before] (no fim, se for null ou não estiver na
  /// dock). Um item que já está fixado só muda de lugar. O "Apps" e a
  /// lixeira não são fixados: estão sempre lá.
  Future<void> pin(DockItem item, {DockItem? before}) async {
    if (item is DockTrash || item is DockLauncher) return;
    final items = [...value]..remove(item);
    final at = before == null ? -1 : items.indexOf(before);
    items.insert(at < 0 ? items.length : at, item);
    return _set(items);
  }

  Future<void> unpin(DockItem item) => _set([...value]..remove(item));

  Future<void> _set(List<DockItem> items) async {
    if (listEquals(items, value)) return;
    value = List.unmodifiable(items);
    await _save();
  }

  StreamSubscription<FileSystemEvent>? _watch;
  Timer? _debounce;

  /// Relê o arquivo quando outro processo grava nele, como o
  /// SettingsStore.watch: vigia o diretório e espera [debounce] sem eventos.
  Future<void> watch({
    Duration debounce = const Duration(milliseconds: 150),
  }) async {
    final file = this.file;
    if (file == null || _watch != null) return;
    try {
      await file.parent.create(recursive: true);
    } catch (e) {
      debugPrint('🦜 Sem como vigiar ${file.path}: $e');
      return;
    }
    _watch = file.parent.watch().listen((event) {
      final hit =
          event.path == file.path ||
          (event is FileSystemMoveEvent && event.destination == file.path);
      if (!hit) return;
      _debounce?.cancel();
      _debounce = Timer(debounce, () async {
        final items = await _read(file);
        if (items != null && !listEquals(items, value)) {
          value = List.unmodifiable(items);
        }
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(_watch?.cancel());
    super.dispose();
  }

  // Grava num .tmp e renomeia: um desligamento no meio não corrompe o arquivo
  Future<void> _save() async {
    final file = this.file;
    if (file == null) return;
    try {
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'items': [for (final item in value) item.toJson()],
        }),
      );
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('🦜 Erro gravando ${file.path}: $e');
    }
  }
}
