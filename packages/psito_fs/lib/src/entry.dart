// packages/psito_fs/lib/src/entry.dart
//
// Listar uma pasta: cada item com o tipo, o tamanho, as datas, se é oculto,
// o alvo dos links e o tipo MIME. A listagem roda num Isolate, para uma pasta
// de 10 mil arquivos não travar a tela, e ordenar segue o Finder.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'mime_database.dart';
import 'names.dart';

enum FsKind { directory, file, other }

class FsEntry {
  final String path;
  final String name;

  /// O tipo do alvo, nos links.
  final FsKind kind;

  /// Em bytes; 0 nas pastas.
  final int size;

  /// Em UTC (o fuso do processo pode estar errado, veja o CLAUDE.md).
  final DateTime modified;
  final DateTime accessed;
  final DateTime changed;

  /// Os bits de permissão (`0o755`).
  final int mode;
  final bool hidden;

  /// O alvo, se for um link simbólico.
  final String? linkTarget;

  /// O link aponta para algo que não existe.
  final bool brokenLink;
  final String mimeType;

  const FsEntry({
    required this.path,
    required this.name,
    required this.kind,
    this.size = 0,
    required this.modified,
    DateTime? accessed,
    DateTime? changed,
    this.mode = 0x1a4, // 0o644
    this.hidden = false,
    this.linkTarget,
    this.brokenLink = false,
    required this.mimeType,
  }) : accessed = accessed ?? modified,
       changed = changed ?? modified;

  bool get isDirectory => kind == FsKind.directory;
  bool get isLink => linkTarget != null;
  bool get executable => kind == FsKind.file && mode & 0x49 != 0; // 0o111

  /// Lê um item. Null se ele sumiu.
  static FsEntry? stat(
    String path,
    MimeDatabase mime, {
    Set<String>? hiddenNames,
  }) {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    final name = baseName(path);
    String? target;
    var stat = FileStat.statSync(path);
    var broken = false;
    if (type == FileSystemEntityType.link) {
      try {
        target = Link(path).targetSync();
      } on FileSystemException {
        target = '';
      }
      if (stat.type == FileSystemEntityType.notFound) {
        broken = true;
        // O stat do link, já que o alvo não existe
        stat = FileStat.statSync(path);
      }
    }
    final kind = switch (stat.type) {
      FileSystemEntityType.directory => FsKind.directory,
      FileSystemEntityType.file => FsKind.file,
      _ => broken ? FsKind.file : FsKind.other,
    };
    return FsEntry(
      path: path,
      name: name,
      kind: kind,
      size: kind == FsKind.file && !broken ? stat.size : 0,
      modified: stat.modified.toUtc(),
      accessed: stat.accessed.toUtc(),
      changed: stat.changed.toUtc(),
      mode: stat.mode & 0xfff,
      hidden:
          name.startsWith('.') ||
          name.endsWith('~') ||
          (hiddenNames?.contains(name) ?? false),
      linkTarget: target,
      brokenLink: broken,
      mimeType: broken
          ? symlinkType
          : kind == FsKind.directory
          ? directoryType
          : kind == FsKind.other
          // Sockets, fifos e dispositivos: só o ícone genérico
          ? 'inode/x-special'
          : mime.typeOf(path, isDirectory: false),
    );
  }

  @override
  String toString() => 'FsEntry($path, $kind, $mimeType)';
}

/// Os itens de [dir], fora do Isolate principal. Os nomes do arquivo
/// `.hidden` da pasta contam como ocultos (o costume do GNOME).
Future<List<FsEntry>> listDirectory(String dir, MimeDatabase mime) =>
    Isolate.run(() => listDirectorySync(dir, mime));

List<FsEntry> listDirectorySync(String dir, MimeDatabase mime) {
  Set<String>? hiddenNames;
  try {
    hiddenNames = File(joinPath(dir, '.hidden')).readAsLinesSync().toSet();
  } on FileSystemException {
    hiddenNames = null;
  }
  final out = <FsEntry>[];
  for (final child in Directory(dir).listSync(followLinks: false)) {
    final entry = FsEntry.stat(child.path, mime, hiddenNames: hiddenNames);
    if (entry != null) out.add(entry);
  }
  return out;
}

enum FsSortKey { name, modified, size, kind }

class FsSort {
  final FsSortKey key;
  final bool ascending;

  /// As pastas antes dos arquivos, em qualquer ordem.
  final bool foldersFirst;

  const FsSort({
    this.key = FsSortKey.name,
    this.ascending = true,
    this.foldersFirst = true,
  });

  FsSort copyWith({FsSortKey? key, bool? ascending, bool? foldersFirst}) =>
      FsSort(
        key: key ?? this.key,
        ascending: ascending ?? this.ascending,
        foldersFirst: foldersFirst ?? this.foldersFirst,
      );

  Map<String, Object?> toJson() => {
    'key': key.name,
    'ascending': ascending,
    'foldersFirst': foldersFirst,
  };

  factory FsSort.fromJson(Object? json) {
    if (json is! Map) return const FsSort();
    return FsSort(
      key: FsSortKey.values.firstWhere(
        (k) => k.name == json['key'],
        orElse: () => FsSortKey.name,
      ),
      ascending: json['ascending'] != false,
      foldersFirst: json['foldersFirst'] != false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FsSort &&
      other.key == key &&
      other.ascending == ascending &&
      other.foldersFirst == foldersFirst;

  @override
  int get hashCode => Object.hash(key, ascending, foldersFirst);
}

/// Ordena como o Finder: pela chave e, empatados, pelo nome natural.
/// [kindOf] dá o nome do tipo, para ordenar por tipo (a descrição, que é o
/// que a coluna mostra); sem ele, vale o tipo MIME.
List<FsEntry> sortEntries(
  Iterable<FsEntry> entries,
  FsSort sort, {
  String Function(FsEntry)? kindOf,
}) {
  int byKey(FsEntry a, FsEntry b) => switch (sort.key) {
    FsSortKey.name => 0,
    FsSortKey.modified => a.modified.compareTo(b.modified),
    FsSortKey.size => a.size.compareTo(b.size),
    FsSortKey.kind => (kindOf?.call(a) ?? a.mimeType).compareTo(
      kindOf?.call(b) ?? b.mimeType,
    ),
  };
  final list = entries.toList();
  list.sort((a, b) {
    if (sort.foldersFirst && a.isDirectory != b.isDirectory) {
      return a.isDirectory ? -1 : 1;
    }
    var result = byKey(a, b);
    if (result == 0) result = naturalCompare(a.name, b.name);
    return sort.ascending ? result : -result;
  });
  return list;
}

/// Avisa quando [dir] muda, [delay] depois da última mudança de uma rajada.
/// Para quando a pasta some.
Stream<void> watchDirectory(
  String dir, {
  Duration delay = const Duration(milliseconds: 200),
}) {
  late StreamController<void> controller;
  StreamSubscription<FileSystemEvent>? sub;
  Timer? pending;
  controller = StreamController<void>(
    onListen: () {
      try {
        sub = Directory(dir).watch().listen(
          (event) {
            pending?.cancel();
            pending = Timer(delay, () => controller.add(null));
          },
          onError: (Object e) => controller.addError(e),
          onDone: () => controller.close(),
        );
      } on FileSystemException catch (e) {
        controller.addError(e);
        controller.close();
      }
    },
    onCancel: () {
      pending?.cancel();
      return sub?.cancel();
    },
  );
  return controller.stream;
}

/// O tamanho de uma pasta e de tudo dentro, sem seguir links, fora do
/// Isolate principal ("Obter informações"). Devolve os bytes e os itens.
Future<(int, int)> directorySize(String dir) => Isolate.run(() {
  var bytes = 0, items = 0;
  try {
    for (final e in Directory(
      dir,
    ).listSync(recursive: true, followLinks: false)) {
      items++;
      if (e is File) {
        try {
          bytes += e.lengthSync();
        } on FileSystemException {
          // Sem permissão: fica de fora
        }
      }
    }
  } on FileSystemException {
    // Uma subpasta sem permissão para a listagem no meio
  }
  return (bytes, items);
});

/// Tira a caixa e os acentos, para a busca ("Cópia" acha "copia").
String foldName(String text) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final lower = text.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final i = from.indexOf(char);
    out.write(i < 0 ? char : to[i]);
  }
  return out.toString();
}

/// Busca pelo nome em [root] e nas pastas de baixo, num Isolate, com os
/// resultados chegando em blocos (a cada [batch] achados ou um pouco de
/// tempo). As pastas ocultas ficam de fora, como no Finder. Cancelar a
/// assinatura para a busca.
Stream<List<FsEntry>> searchByName(
  String root,
  String query,
  MimeDatabase mime, {
  int batch = 50,
}) {
  final needle = foldName(query.trim());
  late StreamController<List<FsEntry>> controller;
  Isolate? isolate;
  final port = ReceivePort();
  controller = StreamController<List<FsEntry>>(
    onListen: () async {
      port.listen((message) {
        if (message == null) {
          port.close();
          controller.close();
        } else {
          controller.add((message as List).cast<FsEntry>());
        }
      });
      isolate = await Isolate.spawn(_search, (
        port.sendPort,
        root,
        needle,
        mime,
        batch,
      ));
    },
    onCancel: () {
      isolate?.kill(priority: Isolate.immediate);
      port.close();
    },
  );
  return controller.stream;
}

void _search((SendPort, String, String, MimeDatabase, int) args) {
  final (port, root, needle, mime, batch) = args;
  final found = <FsEntry>[];
  final clock = Stopwatch()..start();
  void flush() {
    if (found.isEmpty) return;
    port.send(List<FsEntry>.of(found));
    found.clear();
    clock.reset();
  }

  final queue = [root];
  while (queue.isNotEmpty && needle.isNotEmpty) {
    final dir = queue.removeAt(0);
    final List<FileSystemEntity> children;
    try {
      children = Directory(dir).listSync(followLinks: false);
    } on FileSystemException {
      continue;
    }
    for (final child in children) {
      final name = baseName(child.path);
      if (name.startsWith('.')) continue;
      if (child is Directory) queue.add(child.path);
      if (foldName(name).contains(needle)) {
        final entry = FsEntry.stat(child.path, mime);
        if (entry != null) found.add(entry);
      }
      if (found.length >= batch || clock.elapsedMilliseconds > 200) flush();
    }
  }
  flush();
  port.send(null);
}
