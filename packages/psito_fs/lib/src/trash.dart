// packages/psito_fs/lib/src/trash.dart
//
// A lixeira da especificação do freedesktop (Trash spec 1.0): a do home, em
// ~/.local/share/Trash, e a de cada disco externo, em $topdir/.Trash/$uid ou
// $topdir/.Trash-$uid. Cada uma tem o arquivo em files/ e, em info/, um
// .trashinfo com o caminho de onde ele saiu e a data. É a mesma lixeira do
// GNOME, do KDE e do gio trash.
//
// Um disco externo pode vir de qualquer lugar, com o que quiserem dentro: as
// pastas não podem ser links, e o caminho de volta não pode sair do disco.
import 'dart:async';
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

/// A lixeira toda: a do home e a de cada disco montado. Quem usa não precisa
/// saber em qual delas um item está.
class Trash {
  final TrashFolder home;

  /// Onde há discos externos montados agora.
  Iterable<String> Function() mounts;

  /// O usuário, que dá o nome da lixeira no disco.
  final Future<int> Function() uid;

  Trash(
    String dir, {
    DateTime Function()? now,
    Iterable<String> Function()? mounts,
    Future<int> Function()? uid,
  }) : home = TrashFolder(dir, now: now),
       mounts = mounts ?? (() => const []),
       uid = uid ?? _currentUid;

  factory Trash.forEnv(Map<String, String> env, {DateTime Function()? now}) {
    final home = env['HOME'] ?? '';
    return Trash(
      '${env['XDG_DATA_HOME'] ?? '$home/.local/share'}/Trash',
      now: now,
    );
  }

  static Future<int> _currentUid() async {
    final result = await Process.run('id', ['-u']);
    return int.parse('${result.stdout}'.trim());
  }

  String get dir => home.dir;
  String get filesDir => home.filesDir;
  String get infoDir => home.infoDir;

  /// O disco em que [path] está, do mais fundo para o mais raso.
  String? _mountOf(String path) {
    final absolute = File(path).absolute.path;
    String? found;
    for (final mount in mounts()) {
      if (!isWithin(mount, absolute)) continue;
      if (found == null || mount.length > found.length) found = mount;
    }
    return found;
  }

  /// As lixeiras que existem nos discos montados.
  Future<List<TrashFolder>> diskFolders() async {
    final found = <TrashFolder>[];
    for (final mount in mounts()) {
      final folder = await _diskFolder(mount, create: false);
      if (folder != null) found.add(folder);
    }
    return found;
  }

  Future<List<TrashFolder>> _all() async => [home, ...await diskFolders()];

  /// Avisa quando o conteúdo de alguma lixeira muda. Quem troca de discos
  /// montados escuta de novo. Vigiar não segura o disco na hora de desmontar.
  Stream<void> watch({Duration delay = const Duration(milliseconds: 200)}) {
    late StreamController<void> controller;
    final watches = <StreamSubscription<FileSystemEvent>>[];
    Timer? pending;
    var generation = 0;

    void clear() {
      for (final watch in watches) {
        unawaited(watch.cancel());
      }
      watches.clear();
    }

    Future<void> arm() async {
      final current = ++generation;
      final folders = await _all();
      if (current != generation) return;
      clear();
      void changed(FileSystemEvent event) {
        pending?.cancel();
        pending = Timer(delay, () {
          // A pasta da lixeira pode ter acabado de nascer ou de sumir
          unawaited(arm());
          controller.add(null);
        });
      }

      void watchDir(String path, {bool Function(FileSystemEvent)? only}) {
        try {
          watches.add(
            Directory(path).watch().listen((event) {
              if (only?.call(event) ?? true) changed(event);
            }, onError: (Object _) {}),
          );
        } on FileSystemException {
          // Ainda não existe. A raiz do disco avisa quando nascer, e a do home
          // nasce com a primeira coisa que vai para ela
        }
      }

      // A raiz do disco, porque é lá que a lixeira nasce
      for (final mount in mounts()) {
        watchDir(
          mount,
          only: (e) => e.path.split('/').last.startsWith('.Trash'),
        );
      }
      for (final folder in folders) {
        watchDir(folder.filesDir);
        watchDir(folder.infoDir);
      }
    }

    controller = StreamController<void>(
      onListen: () => unawaited(arm()),
      onCancel: () {
        generation++;
        pending?.cancel();
        clear();
      },
    );
    return controller.stream;
  }

  /// A lixeira de um disco, como manda a especificação: a `.Trash/$uid` se o
  /// administrador deixou a `.Trash` com o bit sticky, e senão a `.Trash-$uid`.
  /// Null se o que está lá não é confiável.
  Future<TrashFolder?> _diskFolder(String mount, {required bool create}) async {
    final id = await uid();
    final now = home.now;
    final shared = '$mount/.Trash';
    if (_isRealDir(shared) && FileStat.statSync(shared).mode & 0x200 != 0) {
      final folder = TrashFolder('$shared/$id', now: now, topDir: mount);
      if (await folder._usable(create: create, uid: id)) return folder;
    }
    final own = TrashFolder('$mount/.Trash-$id', now: now, topDir: mount);
    return await own._usable(create: create, uid: id) ? own : null;
  }

  /// Manda o item para a lixeira do disco em que ele está, sem copiar nada: um
  /// arquivo de um pendrive não ocupa o disco do computador.
  Future<TrashItem> trash(String path) async {
    final mount = _mountOf(path);
    if (mount == null) return home.trash(path);
    if (File(path).absolute.path == mount) {
      throw FileSystemException('this is the whole disk', path);
    }
    final folder = await _diskFolder(mount, create: true);
    if (folder == null) {
      throw FileSystemException('no trash on this disk', path);
    }
    return folder.trash(path);
  }

  /// Os itens de todas as lixeiras, os mais novos primeiro.
  Future<List<TrashItem>> list() async {
    final items = <TrashItem>[
      for (final folder in await _all()) ...await folder.list(),
    ];
    return items..sort(_newestFirst);
  }

  Future<bool> isEmpty() async {
    for (final folder in await _all()) {
      if (!await folder.isEmpty()) return false;
    }
    return true;
  }

  /// A lixeira em que o item está.
  Future<TrashFolder> _ownerOf(TrashItem item) async {
    for (final folder in await diskFolders()) {
      if (isWithin(folder.dir, item.path)) return folder;
    }
    return home;
  }

  /// Põe o item de volta onde estava, recriando as pastas que faltarem. Se
  /// já houver algo lá, [replace] apaga o que está lá; sem ele, o item volta
  /// com um nome livre ("nome 2"). Devolve onde ele ficou.
  Future<String> restore(TrashItem item, {bool replace = false}) async =>
      (await _ownerOf(item)).restore(item, replace: replace);

  /// Apaga o item de vez.
  Future<void> delete(TrashItem item) async =>
      (await _ownerOf(item)).delete(item);

  /// Apaga tudo de todas as lixeiras, inclusive o que não tem `.trashinfo`.
  Future<void> empty() async {
    for (final folder in await _all()) {
      await folder.empty();
    }
  }
}

int _newestFirst(TrashItem a, TrashItem b) {
  final x = a.deletedAt, y = b.deletedAt;
  if (x == null || y == null) return naturalCompare(a.name, b.name);
  return y.compareTo(x);
}

bool _isRealDir(String path) =>
    FileSystemEntity.typeSync(path, followLinks: false) ==
    FileSystemEntityType.directory;

/// Uma pasta de lixeira, com `files/` e `info/`.
class TrashFolder {
  /// A pasta `Trash` (`$XDG_DATA_HOME/Trash`).
  final String dir;

  /// O disco, numa lixeira de disco: o `Path=` é relativo a ele.
  final String? topDir;

  /// A hora local da `DeletionDate`. O shell e os apps passam a hora certa
  /// (o `ctx.now()`), já que o `DateTime.now()` fica com o fuso de quando o
  /// processo começou.
  final DateTime Function() now;

  TrashFolder(this.dir, {DateTime Function()? now, this.topDir})
    : now = now ?? DateTime.now;

  String get filesDir => '$dir/files';
  String get infoDir => '$dir/info';

  /// Se dá para usar esta pasta num disco: é pasta de verdade, é da conta, e
  /// `files/` e `info/` não são links. Um link para o home faria o "Esvaziar"
  /// apagar os arquivos de lá.
  Future<bool> _usable({required bool create, required int uid}) async {
    final type = FileSystemEntity.typeSync(dir, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      if (!create) return false;
      await Directory(dir).create();
      await Process.run('chmod', ['700', dir]);
    } else if (type != FileSystemEntityType.directory) {
      return false;
    }
    final owner = await Process.run('stat', ['-c', '%u', dir]);
    if ('${owner.stdout}'.trim() != '$uid') return false;
    for (final sub in [filesDir, infoDir]) {
      final kind = FileSystemEntity.typeSync(sub, followLinks: false);
      if (kind != FileSystemEntityType.notFound &&
          kind != FileSystemEntityType.directory) {
        return false;
      }
    }
    return true;
  }

  /// Manda o item para esta lixeira.
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
      'Path=${_encodePath(_infoPath(absolute))}\n'
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
      final parsed = parseTrashInfo(text, topDir: topDir);
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
    return items..sort(_newestFirst);
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
    // Uma pasta do disco que é um link faria o item sair dele
    if (topDir case final top?) {
      final real = await Directory(parent).resolveSymbolicLinks();
      final realTop = await Directory(top).resolveSymbolicLinks();
      if (real != realTop && !isWithin(realTop, real)) {
        throw FileSystemException('outside the disk', item.originalPath);
      }
    }
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

  /// O que vai no `Path=`: no disco, relativo a ele, para valer em qualquer
  /// lugar em que ele for montado.
  String _infoPath(String absolute) {
    final top = topDir;
    return top == null ? absolute : absolute.substring(top.length + 1);
  }
}

/// `2026-10-31T14:05:09`, sem o fuso, como pede a especificação.
String formatDeletionDate(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}'
      'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// O caminho e a data de um `.trashinfo`. Null se não for um. Numa lixeira de
/// disco ([topDir]), o caminho é relativo e não pode sair dele: quem preparou o
/// pendrive não escolhe onde o "Pôr de volta" grava.
(String, DateTime?)? parseTrashInfo(String text, {String? topDir}) {
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
  if (path == null) return null;
  if (topDir != null) {
    if (path.startsWith('/') || path.isEmpty) return null;
    if (path.split('/').contains('..')) return null;
    return ('$topDir/$path', date);
  }
  if (!path.startsWith('/')) return null;
  return (path, date);
}

/// O `Path=` é o caminho com os bytes fora do permitido em `%XX`, como numa
/// URL, mas com as `/`.
String _encodePath(String path) =>
    path.split('/').map(Uri.encodeComponent).join('/');
