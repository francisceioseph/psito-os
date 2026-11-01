// A lixeira de cada disco, com pastas temporárias fazendo o papel do disco.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:psito_fs/psito_fs.dart';

void main() {
  late Directory root;
  late String disk;
  late Trash trash;
  late int uid;
  late List<String> mounted;

  String homeFile(String name) => '${root.path}/casa/$name';
  String onDisk(String name) => '$disk/$name';
  late String own;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('psito_disktrash_');
    disk = '${root.path}/disco';
    Directory(disk).createSync();
    Directory('${root.path}/casa').createSync();
    uid = int.parse('${(await Process.run('id', ['-u'])).stdout}'.trim());
    own = '$disk/.Trash-$uid';
    mounted = [disk];
    trash = Trash(
      '${root.path}/Trash',
      now: () => DateTime(2026, 11, 1, 10),
      mounts: () => mounted,
    );
  });

  tearDown(() => root.delete(recursive: true));

  test('um arquivo do disco fica no disco, com o caminho relativo', () async {
    Directory(onDisk('fotos')).createSync();
    File(onDisk('fotos/a.txt')).writeAsStringSync('a');
    final item = await trash.trash(onDisk('fotos/a.txt'));
    expect(item.path, '$own/files/a.txt');
    expect(item.originalPath, onDisk('fotos/a.txt'));
    expect(File(onDisk('fotos/a.txt')).existsSync(), isFalse);
    expect(Directory('${root.path}/Trash/files').existsSync(), isFalse);
    expect(
      File('$own/info/a.txt.trashinfo').readAsStringSync(),
      contains('Path=fotos/a.txt\n'),
    );
    final mode = FileStat.statSync(own).mode & 0x1ff;
    expect(mode, 0x1c0, reason: 'só a conta entra');
  });

  test('um arquivo de fora do disco vai para a do home', () async {
    File(homeFile('b.txt')).writeAsStringSync('b');
    final item = await trash.trash(homeFile('b.txt'));
    expect(item.path, '${root.path}/Trash/files/b.txt');
    expect(Directory(own).existsSync(), isFalse);
  });

  test('uma pasta de nome parecido não conta como o disco', () async {
    final other = '${disk}2';
    Directory(other).createSync();
    File('$other/c.txt').writeAsStringSync('c');
    final item = await trash.trash('$other/c.txt');
    expect(item.path, '${root.path}/Trash/files/c.txt');
  });

  test('o disco inteiro não vai para a lixeira', () {
    expect(() => trash.trash(disk), throwsA(isA<FileSystemException>()));
  });

  test('a lista junta as lixeiras, e pôr de volta acha a certa', () async {
    File(homeFile('b.txt')).writeAsStringSync('b');
    File(onDisk('a.txt')).writeAsStringSync('a');
    await trash.trash(homeFile('b.txt'));
    await trash.trash(onDisk('a.txt'));
    final items = await trash.list();
    expect(items.map((i) => i.name).toSet(), {'a.txt', 'b.txt'});
    expect(await trash.isEmpty(), isFalse);

    final fromDisk = items.firstWhere((i) => i.name == 'a.txt');
    expect(await trash.restore(fromDisk), onDisk('a.txt'));
    expect(File(onDisk('a.txt')).readAsStringSync(), 'a');
    expect(File('$own/info/a.txt.trashinfo').existsSync(), isFalse);
  });

  test('o caminho volta certo mesmo montado em outro lugar', () async {
    File(onDisk('a.txt')).writeAsStringSync('a');
    await trash.trash(onDisk('a.txt'));
    final moved = '${root.path}/outro';
    Directory(disk).renameSync(moved);
    mounted = [moved];
    final item = (await trash.list()).single;
    expect(item.originalPath, '$moved/a.txt');
  });

  test('apagar e esvaziar valem em todas', () async {
    File(homeFile('b.txt')).writeAsStringSync('b');
    File(onDisk('a.txt')).writeAsStringSync('a');
    File(onDisk('c.txt')).writeAsStringSync('c');
    await trash.trash(homeFile('b.txt'));
    final a = await trash.trash(onDisk('a.txt'));
    await trash.trash(onDisk('c.txt'));
    await trash.delete(a);
    expect(File(a.path).existsSync(), isFalse);
    expect((await trash.list()).map((i) => i.name).toSet(), {'b.txt', 'c.txt'});
    await trash.empty();
    expect(await trash.isEmpty(), isTrue);
    expect(await trash.list(), isEmpty);
  });

  test('um disco tirado some da lixeira', () async {
    File(onDisk('a.txt')).writeAsStringSync('a');
    await trash.trash(onDisk('a.txt'));
    mounted = [];
    expect(await trash.list(), isEmpty);
    expect(await trash.isEmpty(), isTrue);
    await trash.empty();
    mounted = [disk];
    expect((await trash.list()).single.name, 'a.txt');
  });

  group('a .Trash do administrador', () {
    test('com o bit sticky, usa a pasta da conta dentro dela', () async {
      Directory('$disk/.Trash').createSync();
      await Process.run('chmod', ['1777', '$disk/.Trash']);
      File(onDisk('a.txt')).writeAsStringSync('a');
      final item = await trash.trash(onDisk('a.txt'));
      expect(item.path, '$disk/.Trash/$uid/files/a.txt');
    });

    test('sem o bit, não é confiável, e usa a da conta', () async {
      Directory('$disk/.Trash').createSync();
      File(onDisk('a.txt')).writeAsStringSync('a');
      final item = await trash.trash(onDisk('a.txt'));
      expect(item.path, '$own/files/a.txt');
    });

    test('sendo um link, também não', () async {
      Directory(homeFile('falsa')).createSync();
      await Process.run('chmod', ['1777', homeFile('falsa')]);
      Link('$disk/.Trash').createSync(homeFile('falsa'));
      File(onDisk('a.txt')).writeAsStringSync('a');
      final item = await trash.trash(onDisk('a.txt'));
      expect(item.path, '$own/files/a.txt');
    });
  });

  group('um disco preparado para enganar', () {
    late File precious;

    setUp(() {
      precious = File(homeFile('importante.txt'))..writeAsStringSync('meu');
    });

    test('a lixeira como link para o home é recusada', () async {
      Link(own).createSync('${root.path}/casa');
      File(onDisk('a.txt')).writeAsStringSync('a');
      expect(
        () => trash.trash(onDisk('a.txt')),
        throwsA(isA<FileSystemException>()),
      );
      await trash.empty();
      expect(precious.existsSync(), isTrue);
    });

    test('files/ como link: esvaziar não apaga o que ele aponta', () async {
      Directory(own).createSync();
      Link('$own/files').createSync('${root.path}/casa');
      Directory('$own/info').createSync();
      await trash.empty();
      expect(precious.existsSync(), isTrue);
      expect(await trash.list(), isEmpty);
    });

    Future<void> planted(String path) async {
      Directory('$own/files').createSync(recursive: true);
      Directory('$own/info').createSync();
      File('$own/files/x').writeAsStringSync('do disco');
      File('$own/info/x.trashinfo')
          .writeAsStringSync('[Trash Info]\nPath=$path\n');
    }

    test('um caminho absoluto no .trashinfo não é aceito', () async {
      await planted(precious.path);
      expect(await trash.list(), isEmpty);
    });

    test('um caminho com .. não é aceito', () async {
      await planted('../casa/importante.txt');
      expect(await trash.list(), isEmpty);
    });

    test('pôr de volta numa pasta que é link é recusado', () async {
      Link(onDisk('sub')).createSync('${root.path}/casa');
      await planted('sub/importante.txt');
      final item = (await trash.list()).single;
      await expectLater(
        trash.restore(item, replace: true),
        throwsA(isA<FileSystemException>()),
      );
      expect(precious.readAsStringSync(), 'meu');
    });
  });

  test(
    'watch avisa da lixeira que nasce no disco e do que muda nela',
    () async {
      File(onDisk('a.txt')).writeAsStringSync('a');
      File(onDisk('b.txt')).writeAsStringSync('b');
      var changes = 0;
      final watch = trash
          .watch(delay: const Duration(milliseconds: 10))
          .listen((_) => changes++);
      addTearDown(watch.cancel);
      Future<void> waitChange(int from) async {
        for (var i = 0; i < 100 && changes == from; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(changes, greaterThan(from));
        // O que ainda estava chegando
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await trash.trash(onDisk('a.txt'));
      await waitChange(0);

      final seen = changes;
      await trash.trash(onDisk('b.txt'));
      await waitChange(seen);

      final before = changes;
      File(onDisk('outro.txt')).writeAsStringSync('fora da lixeira');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(changes, before);
    },
  );
}
