// examples/player/lib/src/library/folder_watcher.dart
//
// Observar as pastas com o player aberto. Avisa qual pasta mudou, e quem decide
// quando ler de novo é o LibraryController.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'scanner.dart';

abstract interface class FolderWatcher {
  /// Passa a observar exatamente [folders].
  void watch(Set<String> folders, void Function(String folder) onChanged);
  void dispose();
}

/// Um arquivo que não entra na biblioteca não pede leitura nenhuma.
bool mattersToLibrary(FileSystemEvent event) {
  if (event.isDirectory) return true;
  final extension = p.extension(event.path).toLowerCase();
  return audioExtensions.contains(extension) ||
      const {'.lrc', '.srt', '.jpg', '.jpeg', '.png'}.contains(extension);
}

class DirectoryWatcher implements FolderWatcher {
  final _watching = <String, _WatchedTree>{};

  @override
  void watch(Set<String> folders, void Function(String folder) onChanged) {
    for (final gone in _watching.keys.toSet().difference(folders)) {
      _watching.remove(gone)?.close();
    }
    for (final folder in folders.difference(_watching.keys.toSet())) {
      _watching[folder] = _WatchedTree(
        folder,
        () => onChanged(folder),
        // Um disco que saiu: a próxima conferência tenta de novo
        onGone: () => _watching.remove(folder),
      )..open();
    }
  }

  @override
  void dispose() {
    for (final tree in _watching.values) {
      tree.close();
    }
    _watching.clear();
  }
}

/// O inotify só vê uma pasta de cada vez, e o `recursive` do Dart não faz nada
/// no Linux: cada subpasta tem a sua observação.
class _WatchedTree {
  final String root;
  final void Function() onChanged;
  final void Function() onGone;
  final _dirs = <String, StreamSubscription<FileSystemEvent>>{};
  bool _closed = false;
  bool _warned = false;

  _WatchedTree(this.root, this.onChanged, {required this.onGone});

  void open() => unawaited(_add(root));

  Future<void> _add(String path) async {
    if (_closed || _dirs.containsKey(path)) return;
    final dir = Directory(path);
    try {
      _dirs[path] = dir.watch().listen(
        _onEvent,
        onError: (Object e) => _lost(path, e),
        onDone: () => _drop(path),
      );
      await for (final entry in dir.list(followLinks: false)) {
        if (entry is Directory) await _add(entry.path);
      }
    } on FileSystemException catch (e) {
      _lost(path, e);
    }
  }

  void _onEvent(FileSystemEvent event) {
    if (event.isDirectory && event is! FileSystemDeleteEvent) {
      unawaited(_add(event.path));
    }
    if (mattersToLibrary(event)) onChanged();
  }

  // Passar do limite de observações do sistema cai aqui
  void _lost(String path, Object error) {
    if (!_warned && path != root) {
      _warned = true;
      debugPrint('🎵 não deu para observar tudo em $root: $error');
    }
    unawaited(_dirs[path]?.cancel());
    _drop(path);
  }

  void _drop(String path) {
    _dirs.remove(path);
    if (path == root && !_closed) {
      close();
      onGone();
    }
  }

  void close() {
    _closed = true;
    for (final subscription in _dirs.values) {
      unawaited(subscription.cancel());
    }
    _dirs.clear();
  }
}
