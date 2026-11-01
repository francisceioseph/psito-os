import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:psito_fs/psito_fs.dart';

late Directory tmp;

String p(String rel) => '${tmp.path}/$rel';

void write(String rel, [String text = 'x']) {
  File(p(rel))
    ..createSync(recursive: true)
    ..writeAsStringSync(text);
}

/// Um shared-mime-info pequeno, com o formato do de verdade.
MimeDatabase fakeMime() {
  final dir = Directory(p('mime'))..createSync();
  File('${dir.path}/globs2').writeAsStringSync('''
# comentário
50:text/plain:*.txt
50:text/x-python:*.py
50:application/x-compressed-tar:*.tar.gz
50:application/gzip:*.gz
50:image/png:*.png
50:text/x-makefile:makefile
50:text/x-makefile:Makefile:cs
10:text/x-readme:README*
''');
  File('${dir.path}/subclasses').writeAsStringSync(
    'text/x-python text/x-script\napplication/x-compressed-tar application/gzip\n',
  );
  File('${dir.path}/aliases')
      .writeAsStringSync('text/x-python3 text/x-python\n');
  File('${dir.path}/generic-icons').writeAsStringSync(
    'text/x-python:text-x-script\napplication/gzip:package-x-generic\n',
  );
  File('${dir.path}/icons').writeAsStringSync('');
  Directory('${dir.path}/text').createSync();
  File('${dir.path}/text/plain.xml').writeAsStringSync('''
<?xml version="1.0" encoding="utf-8"?>
<mime-type xmlns="http://www.freedesktop.org/standards/shared-mime-info" type="text/plain">
  <comment>plain text document</comment>
  <comment xml:lang="pt_BR">Documento de texto simples</comment>
  <comment xml:lang="pt">documento em texto simples &amp; outros</comment>
</mime-type>
''');
  return MimeDatabase.load([dir.path]);
}

void main() {
  setUp(() => tmp = Directory.systemTemp.createTempSync('psito_fs'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('nomes', () {
    test('baseName e dirName', () {
      expect(baseName('/a/b.txt'), 'b.txt');
      expect(baseName('/a/b/'), 'b');
      expect(baseName('/'), '/');
      expect(dirName('/a/b.txt'), '/a');
      expect(dirName('/a'), '/');
      expect(joinPath('/', 'a'), '/a');
      expect(isWithin('/a/b', '/a/b/c'), isTrue);
      expect(isWithin('/a/b', '/a/bc'), isFalse);
    });

    test('a extensão', () {
      expect(splitExtension('foto.png'), ('foto', '.png'));
      expect(splitExtension('pacote.tar.gz'), ('pacote', '.tar.gz'));
      expect(splitExtension('.bashrc'), ('.bashrc', ''));
      expect(splitExtension('v1.2', isDirectory: true), ('v1.2', ''));
    });

    test('nomes livres e de cópia', () {
      write('foto.png');
      write('foto 2.png');
      expect(uniqueName(tmp.path, 'foto.png'), 'foto 3.png');
      expect(uniqueName(tmp.path, 'outra.png'), 'outra.png');
      expect(copyName(tmp.path, 'foto.png'), 'foto copy.png');
      write('foto copy.png');
      expect(copyName(tmp.path, 'foto.png'), 'foto copy 2.png');
    });

    test('a ordem natural', () {
      final names = ['foto 10', 'Foto 2', 'foto 1', 'abc', 'foto 02'];
      names.sort(naturalCompare);
      expect(names, ['abc', 'foto 1', 'Foto 2', 'foto 02', 'foto 10']);
    });

    test('nomes inválidos', () {
      expect(invalidName(''), isNotNull);
      expect(invalidName('a/b'), isNotNull);
      expect(invalidName('..'), isNotNull);
      expect(invalidName('ok.txt'), isNull);
    });
  });

  group('tipos MIME', () {
    test('pelo nome: extensão, a mais longa, literal e curinga', () {
      final mime = fakeMime();
      expect(mime.typeForName('a.TXT'), 'text/plain');
      expect(mime.typeForName('a.tar.gz'), 'application/x-compressed-tar');
      expect(mime.typeForName('a.gz'), 'application/gzip');
      expect(mime.typeForName('Makefile'), 'text/x-makefile');
      expect(mime.typeForName('README.md'), 'text/x-readme');
      expect(mime.typeForName('semtipo'), isNull);
    });

    test('pelo conteúdo: texto, binário, vazio, PNG e ELF', () {
      final mime = fakeMime();
      expect(mime.typeForContent(utf8.encode('olá, mundo')), 'text/plain');
      expect(mime.typeForContent([0, 1, 2, 3]), binaryType);
      expect(mime.typeForContent([]), 'text/plain');
      expect(
        mime.typeForContent([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        'image/png',
      );
      expect(
        mime.typeForContent([0x7f, 0x45, 0x4c, 0x46, 2, 1]),
        'application/x-executable',
      );
      File(p('script')).writeAsStringSync('#!/bin/sh\necho oi\n');
      expect(mime.typeOf(p('script')), 'text/plain');
      expect(mime.typeOf(tmp.path), directoryType);
    });

    test('subtipos, apelidos, ícones e descrição', () {
      final mime = fakeMime();
      expect(mime.canonical('text/x-python3'), 'text/x-python');
      expect(mime.parentsOf('text/x-python'), [
        'text/x-script',
        'text/plain',
        binaryType,
      ]);
      expect(
        mime.isA('application/x-compressed-tar', 'application/gzip'),
        isTrue,
      );
      expect(mime.iconNames('text/x-python').take(3), [
        'text-x-python',
        'text-x-script',
        'text-x-generic',
      ]);
      expect(mime.iconNames(directoryType).first, 'folder');
      expect(
        mime.description('text/plain', locale: 'pt_BR.UTF-8'),
        'Documento de texto simples',
      );
      expect(
        mime.description('text/plain', locale: 'pt_PT'),
        'documento em texto simples & outros',
      );
      expect(mime.description('text/plain'), 'plain text document');
      expect(mime.description('image/png'), 'image/png');
    });
  });

  group('listar', () {
    test('tipos, ocultos (.hidden), links e o tamanho', () async {
      final mime = fakeMime();
      write('pasta/a.txt', 'abc');
      write('pasta/.oculto');
      write('pasta/escondido.py');
      write('pasta/.hidden', 'escondido.py\n');
      Directory(p('pasta/sub')).createSync();
      Link(p('pasta/link')).createSync(p('pasta/a.txt'));
      Link(p('pasta/quebrado')).createSync(p('pasta/nada'));
      final entries = {
        for (final e in await listDirectory(p('pasta'), mime)) e.name: e,
      };
      expect(entries['a.txt']!.size, 3);
      expect(entries['a.txt']!.mimeType, 'text/plain');
      expect(entries['a.txt']!.hidden, isFalse);
      expect(entries['.oculto']!.hidden, isTrue);
      expect(entries['escondido.py']!.hidden, isTrue);
      expect(entries['sub']!.isDirectory, isTrue);
      expect(entries['sub']!.mimeType, directoryType);
      expect(entries['link']!.linkTarget, p('pasta/a.txt'));
      expect(entries['link']!.kind, FsKind.file);
      expect(entries['quebrado']!.brokenLink, isTrue);
      expect(entries['a.txt']!.modified.isUtc, isTrue);
    });

    test('ordenar: pastas primeiro, por chave e nome natural', () {
      FsEntry e(String name, {bool dir = false, int size = 0}) => FsEntry(
        path: '/x/$name',
        name: name,
        kind: dir ? FsKind.directory : FsKind.file,
        size: size,
        modified: DateTime.utc(2026),
        mimeType: dir ? directoryType : textType,
      );
      final items = [e('b 10'), e('b 2', size: 5), e('z', dir: true), e('a')];
      expect(sortEntries(items, const FsSort()).map((e) => e.name), [
        'z',
        'a',
        'b 2',
        'b 10',
      ]);
      expect(
        sortEntries(
          items,
          const FsSort(
            key: FsSortKey.size,
            ascending: false,
            foldersFirst: false,
          ),
        ).first.name,
        'b 2',
      );
      expect(
        FsSort.fromJson(const FsSort(key: FsSortKey.kind).toJson()),
        const FsSort(key: FsSortKey.kind),
      );
    });

    test('vigiar avisa uma vez por rajada', () async {
      Directory(p('w')).createSync();
      var count = 0;
      final sub = watchDirectory(
        p('w'),
        delay: const Duration(milliseconds: 50),
      ).listen((_) => count++);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      for (var i = 0; i < 5; i++) {
        write('w/$i');
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await sub.cancel();
      expect(count, 1);
    });

    test('buscar pelo nome, sem acento nem caixa, fora dos ocultos', () async {
      write('b/Cópia de nota.txt');
      write('b/sub/copia.png');
      write('b/.oculta/copia');
      write('b/outro');
      final found = <String>[];
      await for (final batch in searchByName(p('b'), 'COPIA', fakeMime())) {
        found.addAll(batch.map((e) => e.name));
      }
      found.sort();
      expect(found, ['Cópia de nota.txt', 'copia.png']);
      expect(foldName('Ação'), 'acao');
    });

    test('o tamanho de uma pasta', () async {
      write('t/a', 'abcd');
      write('t/s/b', 'ef');
      expect(await directorySize(p('t')), (6, 3));
    });
  });

  test('as pastas do usuário', () {
    final dirs = parseUserDirs('''
XDG_DESKTOP_DIR="\$HOME/Área de trabalho"
XDG_DOCUMENTS_DIR="\$HOME/Documentos"
XDG_MUSIC_DIR="\$HOME/"
XDG_VIDEOS_DIR="/mnt/v\\"x"
''', '/home/u');
    expect(dirs, {
      UserDir.desktop: '/home/u/Área de trabalho',
      UserDir.documents: '/home/u/Documentos',
      UserDir.videos: '/mnt/v"x',
    });
  });

  group('lixeira', () {
    late Trash trash;
    setUp(
      () =>
          trash = Trash(p('Trash'), now: () => DateTime(2026, 10, 31, 9, 5, 7)),
    );

    test('jogar, listar e pôr de volta', () async {
      write('docs/nota.txt', 'oi');
      final item = await trash.trash(p('docs/nota.txt'));
      expect(File(p('docs/nota.txt')).existsSync(), isFalse);
      final info = File(p('Trash/info/nota.txt.trashinfo')).readAsStringSync();
      expect(info, contains('Path=${p('docs/nota.txt')}'));
      expect(info, contains('DeletionDate=2026-10-31T09:05:07'));
      final listed = await trash.list();
      expect(listed.single.originalPath, p('docs/nota.txt'));
      expect(listed.single.deletedAt, DateTime.utc(2026, 10, 31, 9, 5, 7));
      expect(item.deletedAt, listed.single.deletedAt);
      expect(await trash.restore(listed.single), p('docs/nota.txt'));
      expect(File(p('docs/nota.txt')).readAsStringSync(), 'oi');
      expect(await trash.isEmpty(), isTrue);
      expect(Directory(p('Trash/info')).listSync(), isEmpty);
    });

    test('dois com o mesmo nome e o conflito ao pôr de volta', () async {
      write('a/x.txt', '1');
      write('b/x.txt', '2');
      await trash.trash(p('a/x.txt'));
      await trash.trash(p('b/x.txt'));
      expect(File(p('Trash/files/x.2.txt')).existsSync(), isTrue);
      final items = await trash.list();
      expect(items, hasLength(2));
      write('a/x.txt', 'novo');
      final first = items.firstWhere((i) => i.originalPath == p('a/x.txt'));
      expect(await trash.restore(first), p('a/x 2.txt'));
      final second = (await trash.list()).single;
      write('b/x.txt', 'novo');
      await trash.restore(second, replace: true);
      expect(File(p('b/x.txt')).readAsStringSync(), '2');
    });

    test('pastas, caminhos com espaço e pasta de origem que sumiu', () async {
      write('com espaço/sub/f', 'f');
      await trash.trash(p('com espaço'));
      final info = File(p('Trash/info/com espaço.trashinfo'))
          .readAsStringSync();
      expect(info, contains('com%20espa%C3%A7o'));
      final item = (await trash.list()).single;
      expect(item.isDirectory, isTrue);
      expect(item.originalPath, p('com espaço'));
      await trash.restore(item);
      expect(File(p('com espaço/sub/f')).existsSync(), isTrue);
    });

    test('esvaziar e apagar um', () async {
      write('a');
      write('b');
      await trash.trash(p('a'));
      final b = await trash.trash(p('b'));
      await trash.delete(b);
      expect((await trash.list()).map((i) => i.name), ['a']);
      await trash.empty();
      expect(await trash.isEmpty(), isTrue);
      expect(await trash.list(), isEmpty);
    });

    test('um .trashinfo estranho fica de fora', () {
      expect(parseTrashInfo('[Outra]\nPath=/x\n'), isNull);
      expect(parseTrashInfo('[Trash Info]\nPath=relativo\n'), isNull);
      expect(parseTrashInfo('[Trash Info]\nPath=/a%20b\n')!.$1, '/a b');
    });
  });

  group('operações', () {
    late Trash trash;
    setUp(() => trash = Trash(p('Trash')));

    test('copiar com progresso, e o desfazer manda para a lixeira', () async {
      write('src/a.txt', 'a' * 3000);
      write('src/d/b.txt', 'bb');
      Directory(p('dst')).createSync();
      final job = FileJob.start(JobKind.copy, [
        p('src/a.txt'),
        p('src/d'),
      ], destination: p('dst'));
      final progress = <JobProgress>[];
      job.progress.listen(progress.add);
      final result = await job.result;
      expect(result.errors, isEmpty);
      expect(File(p('dst/a.txt')).lengthSync(), 3000);
      expect(File(p('dst/d/b.txt')).readAsStringSync(), 'bb');
      expect(progress.last.doneBytes, 3002);
      expect(progress.last.totalBytes, 3002);
      expect(progress.last.fraction, 1);
      await FileJob.undoFor(JobKind.copy, result, trash).run();
      expect(File(p('dst/a.txt')).existsSync(), isFalse);
      expect((await trash.list()), hasLength(2));
      expect(File(p('src/a.txt')).existsSync(), isTrue);
    });

    test('o bit de execução e os links vão junto', () async {
      write('s/run.sh', '#!/bin/sh\n');
      Process.runSync('chmod', ['755', p('s/run.sh')]);
      Link(p('s/l')).createSync('run.sh');
      Directory(p('d')).createSync();
      await FileJob.start(JobKind.copy, [p('s')], destination: p('d')).result;
      expect(FileStat.statSync(p('d/s/run.sh')).mode & 0x1ff, 0x1ed);
      expect(Link(p('d/s/l')).targetSync(), 'run.sh');
    });

    test('mover e desfazer', () async {
      write('a/x.txt');
      Directory(p('b')).createSync();
      final result = await FileJob.start(JobKind.move, [
        p('a/x.txt'),
      ], destination: p('b')).result;
      expect(result.done.single, (p('a/x.txt'), p('b/x.txt')));
      expect(File(p('a/x.txt')).existsSync(), isFalse);
      await FileJob.undoFor(JobKind.move, result, trash).run();
      expect(File(p('a/x.txt')).existsSync(), isTrue);
      expect(File(p('b/x.txt')).existsSync(), isFalse);
    });

    test('conflitos: substituir, manter os dois, pular e para todos', () async {
      for (final n in ['1', '2', '3']) {
        write('s/$n', 'novo');
        write('d/$n', 'velho');
      }
      final asked = <String>[];
      final answers = [
        const ConflictAnswer(ConflictChoice.replace),
        const ConflictAnswer(ConflictChoice.skip, applyToAll: true),
      ];
      final result = await FileJob.start(
        JobKind.copy,
        [p('s/1'), p('s/2'), p('s/3')],
        destination: p('d'),
        onConflict: (c) async {
          asked.add(baseName(c.target));
          return answers.removeAt(0);
        },
      ).result;
      expect(asked, ['1', '2']);
      expect(File(p('d/1')).readAsStringSync(), 'novo');
      expect(File(p('d/2')).readAsStringSync(), 'velho');
      expect(File(p('d/3')).readAsStringSync(), 'velho');
      expect(result.done, [(p('s/1'), p('d/1'))]);

      final both = await FileJob.start(
        JobKind.copy,
        [p('s/2')],
        destination: p('d'),
        onConflict: (_) async => const ConflictAnswer(ConflictChoice.keepBoth),
      ).result;
      expect(both.done.single.$2, p('d/2 2'));
    });

    test(
      'copiar para a mesma pasta duplica, e a pasta não entra nela',
      () async {
        write('s/f.txt');
        final same = await FileJob.start(JobKind.copy, [
          p('s/f.txt'),
        ], destination: p('s')).result;
        expect(same.done.single.$2, p('s/f copy.txt'));
        final dup = await FileJob.start(JobKind.duplicate, [
          p('s/f.txt'),
        ]).result;
        expect(dup.done.single.$2, p('s/f copy 2.txt'));
        final inside = await FileJob.start(JobKind.move, [
          p('s'),
        ], destination: p('s')).result;
        expect(inside.done, isEmpty);
        final into = await FileJob.start(JobKind.copy, [
          tmp.path,
        ], destination: p('s')).result;
        expect(into.errors.single.kind, FsErrorKind.intoItself);
      },
    );

    test('cancelar tira o pedaço copiado', () async {
      // 64 MB: grande o bastante para cancelar no meio
      final big = File(p('big'));
      final raf = big.openSync(mode: FileMode.write);
      raf.setPositionSync((64 << 20) - 1);
      raf.writeByteSync(1);
      raf.closeSync();
      Directory(p('d')).createSync();
      final job = FileJob.start(JobKind.copy, [p('big')], destination: p('d'));
      // Logo depois de começar: o progresso só sai a cada 100 ms, e esperar
      // por ele deixava a cópia acabar antes do pedido chegar
      job.cancel();
      final result = await job.result;
      expect(result.cancelled, isTrue);
      expect(File(p('d/big')).existsSync(), isFalse);
    });

    test('renomear, nova pasta e lixeira, com os desfazer', () async {
      write('r/a.txt');
      write('r/b.txt');
      final (renamed, undoRename) = await renameEntry(p('r/a.txt'), 'c.txt');
      expect(renamed, p('r/c.txt'));
      expect(() => renameEntry(p('r/c.txt'), 'b.txt'), throwsA(isA<FsError>()));
      await undoRename.run();
      expect(File(p('r/a.txt')).existsSync(), isTrue);
      final (folder, undoFolder) = await createFolder(
        p('r'),
        name: 'Nova pasta',
      );
      final (folder2, _) = await createFolder(p('r'), name: 'Nova pasta');
      expect(baseName(folder), 'Nova pasta');
      expect(baseName(folder2), 'Nova pasta 2');
      await undoFolder.run();
      expect(Directory(folder).existsSync(), isFalse);
      final (items, undoTrash) = await trashEntries(trash, [p('r/b.txt')]);
      expect(items.single.name, 'b.txt');
      await undoTrash.run();
      expect(File(p('r/b.txt')).existsSync(), isTrue);
    });
  });

  group('apps de cada tipo', () {
    test('o padrão, os acrescentados, os tirados e os subtipos', () {
      final mime = fakeMime();
      write('cfg/psito-mimeapps.list', '''
[Default Applications]
text/plain=org.psito.notepad.desktop
''');
      write('cfg/mimeapps.list', '''
[Default Applications]
text/x-python=nao-instalado.desktop;code.desktop

[Removed Associations]
text/plain=gedit.desktop;
''');
      write('data/applications/mimeapps.list', '''
[Added Associations]
text/plain=firefox-esr.desktop;
''');
      final env = {
        'HOME': tmp.path,
        'XDG_CONFIG_HOME': p('cfg'),
        'XDG_CONFIG_DIRS': p('nada'),
        'XDG_DATA_HOME': p('data'),
        'XDG_DATA_DIRS': p('nada'),
        'XDG_CURRENT_DESKTOP': 'Psito:labwc',
      };
      expect(MimeApps.filesFor(env).take(3), [
        p('cfg/psito-mimeapps.list'),
        p('cfg/labwc-mimeapps.list'),
        p('cfg/mimeapps.list'),
      ]);
      final apps = MimeApps.load(MimeApps.filesFor(env));
      final installed = {
        'org.psito.notepad': ['text/plain'],
        'gedit': ['text/plain'],
        'code': ['text/x-python'],
        'firefox-esr': ['text/html'],
        'org.psito.files': ['inode/directory'],
      };
      expect(apps.appsFor('text/plain', installed, mime), [
        'org.psito.notepad',
        'firefox-esr',
      ]);
      expect(apps.defaultFor('text/x-python', installed, mime), 'code');
      expect(apps.appsFor('text/x-python', installed, mime), [
        'code',
        'org.psito.notepad',
        'firefox-esr',
      ]);
      expect(
        apps.defaultFor(directoryType, installed, mime),
        'org.psito.files',
      );
      expect(apps.defaultFor('image/png', installed, mime), isNull);
    });

    test('gravar o padrão mantém o resto do arquivo', () async {
      const text = '''
[Added Associations]
a/b=x.desktop;

[Default Applications]
text/plain=velho.desktop
image/png=img.desktop

''';
      final out = MimeApps.withDefault(text, 'text/plain', 'novo');
      expect(out, contains('text/plain=novo.desktop\n'));
      expect(out, contains('image/png=img.desktop'));
      expect(out, contains('a/b=x.desktop;'));
      expect(out, isNot(contains('velho')));
      final added = MimeApps.withDefault(out, 'video/mp4', 'mpv');
      expect(added, contains('image/png=img.desktop\nvideo/mp4=mpv.desktop'));
      expect(
        MimeApps.withDefault('', 'a/b', 'c'),
        '[Default Applications]\na/b=c.desktop\n',
      );
      await MimeApps.setDefault(p('c/mimeapps.list'), 'a/b', 'c');
      expect(
        File(p('c/mimeapps.list')).readAsStringSync(),
        contains('a/b=c.desktop'),
      );
    });
  });

  group('sameDevice', () {
    test('a mesma pasta é o mesmo disco', () async {
      final dir = await Directory.systemTemp.createTemp('psito_device_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/a')..createSync();
      expect(await sameDevice([file.path], dir.path), isTrue);
    });

    test('o /proc é outro disco', () async {
      final dir = await Directory.systemTemp.createTemp('psito_device_');
      addTearDown(() => dir.delete(recursive: true));
      expect(await sameDevice(['/proc/self'], dir.path), isFalse);
    });

    test('sem o arquivo, responde não', () async {
      expect(await sameDevice(['/nao/existe'], '/tmp'), isFalse);
    });
  });
}
