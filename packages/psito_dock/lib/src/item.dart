// packages/psito_dock/lib/src/item.dart
//
// Um item fixado na dock: um app (pelo id do `.desktop`), uma pasta ou um
// arquivo (pelo caminho).
import 'package:flutter/foundation.dart';

@immutable
sealed class DockItem {
  const DockItem();

  /// Null: um item que este shell não conhece (de uma versão mais nova).
  static DockItem? fromJson(Object? json) => switch (json) {
    {'app': final String id} => DockApp(id),
    {'folder': final String path} => DockFolder(path),
    {'file': final String path} => DockFile(path),
    _ => null,
  };

  Map<String, Object?> toJson();
}

final class DockApp extends DockItem {
  final String id;
  const DockApp(this.id);

  @override
  Map<String, Object?> toJson() => {'app': id};

  @override
  bool operator ==(Object other) => other is DockApp && other.id == id;

  @override
  int get hashCode => Object.hash(DockApp, id);

  @override
  String toString() => 'DockApp($id)';
}

/// Uma pasta ou um arquivo.
sealed class DockPath extends DockItem {
  final String path;
  const DockPath(this.path);

  String get name {
    final parts = path.split('/')..removeWhere((part) => part.isEmpty);
    return parts.isEmpty ? '/' : parts.last;
  }
}

final class DockFolder extends DockPath {
  const DockFolder(super.path);

  @override
  Map<String, Object?> toJson() => {'folder': path};

  @override
  bool operator ==(Object other) => other is DockFolder && other.path == path;

  @override
  int get hashCode => Object.hash(DockFolder, path);

  @override
  String toString() => 'DockFolder($path)';
}

final class DockFile extends DockPath {
  const DockFile(super.path);

  @override
  Map<String, Object?> toJson() => {'file': path};

  @override
  bool operator ==(Object other) => other is DockFile && other.path == path;

  @override
  int get hashCode => Object.hash(DockFile, path);

  @override
  String toString() => 'DockFile($path)';
}

/// A lixeira: sempre no fim da dock, fora do dock.json.
final class DockTrash extends DockItem {
  const DockTrash();

  @override
  Map<String, Object?> toJson() => const {'trash': true};

  @override
  bool operator ==(Object other) => other is DockTrash;

  @override
  int get hashCode => (DockTrash).hashCode;

  @override
  String toString() => 'DockTrash()';
}

/// O ícone "Apps", que abre a lista de apps: sempre o primeiro da dock,
/// fora do dock.json, e não sai do lugar.
final class DockLauncher extends DockItem {
  const DockLauncher();

  @override
  Map<String, Object?> toJson() => const {'launcher': true};

  @override
  bool operator ==(Object other) => other is DockLauncher;

  @override
  int get hashCode => (DockLauncher).hashCode;

  @override
  String toString() => 'DockLauncher()';
}
