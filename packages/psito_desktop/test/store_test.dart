import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:psito_desktop/psito_desktop.dart';
import 'package:psito_fs/psito_fs.dart';

FsEntry _file(String name, {int mode = 0x1a4}) => FsEntry(
  path: '/d/$name',
  name: name,
  kind: FsKind.file,
  modified: DateTime.utc(2026),
  mode: mode,
  mimeType: 'application/x-desktop',
);

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('psito_desktop_');
    file = File('${dir.path}/psito/desktop.json');
  });
  tearDown(() => dir.delete(recursive: true));

  test('sem o arquivo, começa vazio e sem gravar', () async {
    final store = await DeskStore.load(file);
    expect(store.cells, isEmpty);
    expect(await file.exists(), isFalse);
  });

  test('as células voltam na próxima subida', () async {
    final store = await DeskStore.load(file);
    await store.put({'a.txt': const DeskCell(2, 3)});
    final again = await DeskStore.load(file);
    expect(again.cells['a.txt'], const DeskCell(2, 3));
  });

  test('esquece quem saiu da pasta', () async {
    final store = await DeskStore.load(file);
    await store.put({'a': const DeskCell(0, 0), 'b': const DeskCell(0, 1)});
    await store.retain({'b'});
    final json = jsonDecode(await file.readAsString());
    expect((json as Map)['cells'], {
      'b': [0, 1],
    });
  });

  test('um arquivo ilegível vale como vazio', () async {
    await file.parent.create(recursive: true);
    await file.writeAsString('{ quebrado');
    expect((await DeskStore.load(file)).cells, isEmpty);
  });

  test('um atalho é confiável com o +x e sem escrita para os outros', () {
    expect(isDeskShortcut(_file('a.desktop')), isTrue);
    expect(isDeskShortcut(_file('a.txt')), isFalse);
    expect(deskShortcutTrusted(_file('a.desktop')), isFalse);
    expect(deskShortcutTrusted(_file('a.desktop', mode: 0x1ed)), isTrue); // 755
    expect(
      deskShortcutTrusted(_file('a.desktop', mode: 0x1ff)),
      isFalse,
    ); // 777
  });
}
