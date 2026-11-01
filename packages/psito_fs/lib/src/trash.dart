// packages/psito_fs/lib/src/trash.dart
//
// A lixeira da especificação do freedesktop (Trash spec 1.0), a do home:
// ~/.local/share/Trash, com o arquivo em files/ e, em info/, um .trashinfo
// com o caminho de onde ele saiu e a data. É a mesma lixeira do GNOME, do
// KDE e do gio trash.
import 'dart:io';

import 'names.dart';
import 'operations.dart' show deleteEntity, moveEntity;

class TrashItem {
  /// O nome dentro da lixeira (o do `.trashinfo` sem a extensão).
  final String trashName;

  /// O caminho de onde o item saiu.
  final String originalPath;

  /// A `DeletionDate`: a hora local de quando foi para a lixeira (a
  /// especificação não grava o fuso), guardada nos campos de um DateTime UTC
  /// para nenhuma conversão mexer nela.
  final DateTime? deletedAt;

  /// Onde o item está agora (`Trash/files/<nome>`).
  final String path;
  final bool isDirectory;

  const TrashItem({
    required this.trashName,
    required this.originalPath,
    required this.deletedAt,
    required this.path,
    required this.isDirectory,
  });

  String get name => baseName(originalPath);
}

class Trash {
  /// A pasta `Trash` (`$XDG_DATA_HOME/Trash`).
  final String dir;

  /// A hora local da `DeletionDate`. O shell e os apps passam a hora certa
  /// (o `ctx.now()`), já que o `DateTime.now()` fica com o fuso de quando o
  /// processo começou.
  final DateTime Function() now;

  Trash(this.dir, {DateTime Function()? now}) : now = now ?? DateTime.now;

  factory Trash.forEnv(Map<String, String> env, {DateTime Function()? now}) {
    final home = env['HOME'] ?? '';
    return Trash(
      '${env['XDG_DATA_HOME'] ?? '$home/.local/share'}/Trash',
      now: now,
    );
  }

  String get filesDir => '$dir/files';
  String get infoDir => '$dir/info';

  /// Manda o item para a lixeira. O que está em outro sistema de arquivos é
  /// copiado para ela e apagado (a lixeira de cada disco fica para depois).
  Future<TrashItem> trash(String path) async {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException('not found', path);
    }
    if (isWithin(dir, path)) {
      throw FileSystemException('already in the trash', path);
    }
    await Directory(filesDir).create(recursive: true);
    await Directory(infoDir).create(recursive: true);
    final absolute = File(path).absolute.path;
    // O .trashinfo é criado com O_EXCL: dois processos não pegam o mesmo
    // nome
    final name = baseName(absolute);
    final (stem, ext) = splitExtension(
      name,
      isDirectory: type == FileSystemEntityType.directory,
    );
    late String trashName;
    late File info;
    for (var n = 1; ; n++) {
      trashName = n == 1 ? name : '$stem.$n$ext';
      info = File('$infoDir/$trashName.trashinfo');
      if (FileSystemEntity.typeSync(
            '$filesDir/$trashName',
            followLinks: false,
          ) !=
          FileSystemEntityType.notFound) {
        continue;
      }
      try {
        await info.create(exclusive: true);
        break;
      } on FileSystemException {
        continue;
      }
    }
    final deletedAt = now();
    await info.writeAsString(
      '[Trash Info]\n'
      'Path=${_encodePath(absolute)}\n'
      'DeletionDate=${formatDeletionDate(deletedAt)}\n',
      flush: true,
    );
    final target = '$filesDir/$trashName';
    try {
      await moveEntity(absolute, target);
    } on FileSystemException {
      await info.delete();
      rethrow;
    }
    return TrashItem(
      trashName: trashName,
      originalPath: absolute,
      deletedAt: DateTime.utc(
        deletedAt.year,
        deletedAt.month,
        deletedAt.day,
        deletedAt.hour,
        deletedAt.minute,
        deletedAt.second,
      ),
      path: target,
      isDirectory: type == FileSystemEntityType.directory,
    );
  }

  /// Os itens da lixeira, os mais novos primeiro. Um `.trashinfo` sem o
  /// arquivo (ou o contrário) fica de fora.
  Future<List<TrashItem>> list() async {
    final items = <TrashItem>[];
    final dir = Directory(infoDir);
    if (!await dir.exists()) return items;
    await for (final file in dir.list()) {
      if (file is! File || !file.path.endsWith('.trashinfo')) continue;
      final trashName = baseName(file.path)
          .substring(0, baseName(file.path).length - '.trashinfo'.length);
      final path = '$filesDir/$trashName';
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      final String text;
      try {
        text = await file.readAsString();
      } on FileSystemException {
        continue;
      }
      final parsed = parseTrashInfo(text);
      if (parsed == null) continue;
      items.add(
        TrashItem(
          trashName: trashName,
          originalPath: parsed.$1,
          deletedAt: parsed.$2,
          path: path,
          isDirectory: type == FileSystemEntityType.directory,
        ),
      );
    }
    items.sort((a, b) {
      final x = a.deletedAt, y = b.deletedAt;
      if (x == null || y == null) return naturalCompare(a.name, b.name);
      return y.compareTo(x);
    });
    return items;
  }

  Future<bool> isEmpty() async {
    final dir = Directory(filesDir);
    if (!await dir.exists()) return true;
    return dir.list().isEmpty;
  }

  /// Põe o item de volta onde estava, recriando as pastas que faltarem. Se
  /// já houver algo lá, [replace] apaga o que está lá; sem ele, o item volta
  /// com um nome livre ("nome 2"). Devolve onde ele ficou.
  Future<String> restore(TrashItem item, {bool replace = false}) async {
    final parent = dirName(item.originalPath);
    await Directory(parent).create(recursive: true);
    var target = item.originalPath;
    if (FileSystemEntity.typeSync(target, followLinks: false) !=
        FileSystemEntityType.notFound) {
      if (replace) {
        await deleteEntity(target);
      } else {
        target = joinPath(
          parent,
          uniqueName(parent, item.name, isDirectory: item.isDirectory),
        );
      }
    }
    await moveEntity(item.path, target);
    await _deleteInfo(item.trashName);
    return target;
  }

  /// Apaga o item de vez.
  Future<void> delete(TrashItem item) async {
    await deleteEntity(item.path);
    await _deleteInfo(item.trashName);
  }

  /// Apaga tudo da lixeira, inclusive o que não tem `.trashinfo`.
  Future<void> empty() async {
    for (final sub in [filesDir, infoDir]) {
      final dir = Directory(sub);
      if (!await dir.exists()) continue;
      await for (final child in dir.list(followLinks: false)) {
        await deleteEntity(child.path);
      }
    }
    final sizes = File('$dir/directorysizes');
    if (await sizes.exists()) await sizes.delete();
  }

  Future<void> _deleteInfo(String trashName) async {
    final info = File('$infoDir/$trashName.trashinfo');
    if (await info.exists()) await info.delete();
  }
}

/// `2026-10-31T14:05:09`, sem o fuso, como pede a especificação.
String formatDeletionDate(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}'
      'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// O caminho e a data de um `.trashinfo`. Null se não for um.
(String, DateTime?)? parseTrashInfo(String text) {
  var inGroup = false;
  String? path;
  DateTime? date;
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('[')) {
      inGroup = line == '[Trash Info]';
      continue;
    }
    if (!inGroup) continue;
    if (line.startsWith('Path=')) {
      try {
        path = Uri.decodeComponent(line.substring(5));
      } on ArgumentError {
        path = line.substring(5);
      }
    } else if (line.startsWith('DeletionDate=')) {
      final m = RegExp(r'^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)')
          .firstMatch(line.substring(13));
      if (m != null) {
        final [y, mo, d, h, mi, s] = [
          for (var i = 1; i <= 6; i++) int.parse(m.group(i)!),
        ];
        // Hora local "solta": guardada como UTC só para não mudar de fuso
        date = DateTime.utc(y, mo, d, h, mi, s);
      }
    }
  }
  if (path == null || !path.startsWith('/')) return null;
  return (path, date);
}

/// O `Path=` é o caminho com os bytes fora do permitido em `%XX`, como numa
/// URL, mas com as `/`.
String _encodePath(String path) =>
    path.split('/').map(Uri.encodeComponent).join('/');
