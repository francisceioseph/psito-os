import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/disks_service.dart';
import 'package:psito_services/storage_service.dart';

ProcessResult _result(String stdout, {int code = 0}) =>
    ProcessResult(1, code, stdout, '');

void main() {
  group('as saídas', () {
    test('o df', () {
      expect(parseDf('1B-blocks  Avail\n 1000 400\n'), (1000, 400));
      expect(parseDf(''), isNull);
      expect(parseDf('x\ny z\n'), isNull);
    });

    test('o du, sem a pasta de cima e da maior para a menor', () {
      final found = parseDu('10\t/h/a\u000030\t/h/b c\u000040\t/h\u0000', '/h');
      expect(found.map((f) => f.path), ['/h/b c', '/h/a']);
      expect(found.first.size, 30);
    });

    test('um nome com quebra de linha não atrapalha', () {
      expect(parseDu('5\t/h/a\nb\u0000', '/h').single.path, '/h/a\nb');
    });

    test('só as maiores', () {
      final many = [for (var i = 0; i < 20; i++) '$i\t/h/$i'].join('\u0000');
      final found = parseDu(many, '/h');
      expect(found, hasLength(largestFoldersLimit));
      expect(found.first.path, '/h/19');
    });
  });

  group('quase cheio', () {
    bool full(int total, int free) =>
        PsitoDiskUsage(total: total, free: free).almostFull;

    test('vale o menor dos dois limites', () {
      // 1 TB com 40 GB livres é muito espaço, e com 1 GB, pouco
      expect(full(1000000000000, 40000000000), isFalse);
      expect(full(1000000000000, 1000000000), isTrue);
      // Num disco de 8 GB, 1 GB livre ainda não é cheio
      expect(full(8000000000, 1000000000), isFalse);
      expect(full(8000000000, 300000000), isTrue);
    });

    test('sem medir, nada a dizer', () {
      expect(const PsitoDiskUsage(total: 1000).almostFull, isFalse);
      expect(const PsitoDiskUsage(total: 0, free: 0).almostFull, isFalse);
    });
  });

  test('o tamanho, no idioma de quem usa', () {
    expect(formatPsitoSize(512, 'pt'), '512 B');
    expect(formatPsitoSize(1234567, 'pt'), '1,2 MB');
    expect(formatPsitoSize(1234567, 'en'), '1.2 MB');
    expect(formatPsitoSize(25000000000, 'pt'), '25 GB');
  });

  group('o serviço', () {
    late FakeDisksService disks;
    late List<List<String>> calls;
    late LocalStorage storage;

    setUp(() {
      disks = FakeDisksService();
      calls = [];
      storage = LocalStorage(
        disks: disks,
        home: '/home/ana',
        trashDirs: () async => ['/nao/existe'],
        onEmptyTrash: () {},
        onOpen: (_) async {},
        run: (executable, arguments) async {
          calls.add([executable, ...arguments]);
          return executable == 'df'
              ? _result('h\n1000 400\n')
              : _result('7\t/home/ana/a\u00009\t/home/ana\u0000');
        },
      );
    });

    tearDown(() => storage.dispose());

    test('o sistema primeiro, e um disco sem montar não pede o df', () async {
      disks.volumes.value = const [
        PsitoVolume(id: '/a', label: 'A', device: '/dev/a', size: 50),
        PsitoVolume(
          id: '/b',
          label: 'B',
          device: '/dev/b',
          mountPoint: '/media/ana/B',
        ),
      ];
      await storage.refresh();
      final found = storage.disks.value;
      expect(found.map((d) => d.isSystem), [true, false, false]);
      expect(found[0].path, '/home/ana');
      expect(found[1].free, isNull);
      expect(found[1].total, 50);
      expect(found[2].free, 400);
      expect(calls.map((c) => c.last), contains('/media/ana/B'));
      expect(calls.map((c) => c.last), isNot(contains('/dev/a')));
    });

    test('o du tem prioridade baixa e fica num disco só', () async {
      final found = await storage.largestFolders('/home/ana');
      expect(found.single.path, '/home/ana/a');
      expect(calls.single.take(3), ['nice', '-n', '10']);
      expect(calls.single, contains('-x'));
    });

    test('um du que falhou numa pasta ainda mede o resto', () async {
      final partial = LocalStorage(
        disks: disks,
        home: '/h',
        trashDirs: () async => const [],
        onEmptyTrash: () {},
        onOpen: (_) async {},
        run: (_, _) async => _result('3\t/h/a\u0000', code: 1),
      );
      addTearDown(partial.dispose);
      expect((await partial.largestFolders('/h')).single.size, 3);
    });

    test('sem lixeira, zero, sem chamar o du', () async {
      expect(await storage.trashSize(), 0);
      expect(calls, isEmpty);
    });

    test('a lixeira soma tudo', () async {
      final dir = Directory.systemTemp.createTempSync('psito_trash');
      addTearDown(() => dir.deleteSync(recursive: true));
      final trash = LocalStorage(
        disks: disks,
        home: '/h',
        trashDirs: () async => [dir.path, '/nao/existe'],
        onEmptyTrash: () {},
        onOpen: (_) async {},
        run: (_, arguments) async {
          calls.add(arguments);
          return _result('5\t${dir.path}\n5\ttotal\n');
        },
      );
      addTearDown(trash.dispose);
      expect(await trash.trashSize(), 5);
      expect(calls.single.last, dir.path);
    });
  });

  test('onde o sistema roda', () {
    for (final mount in ['/', '/boot', '/boot/efi', '/home', '/usr', '/var']) {
      expect(isSystemMount(mount), isTrue, reason: mount);
    }
    for (final mount in [null, '/media/ana/X', '/homework', '/mnt/x']) {
      expect(isSystemMount(mount), isFalse, reason: mount);
    }
  });
}
