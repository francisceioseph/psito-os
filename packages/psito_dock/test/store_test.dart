import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:psito_dock/psito_dock.dart';

const _initial = [DockApp('foot'), DockApp('org.psito.files')];

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('psito_dock_');
    file = File('${dir.path}/psito/dock.json');
  });
  tearDown(() => dir.delete(recursive: true));

  Future<Object?> saved() async => jsonDecode(await file.readAsString());

  test('na primeira vez, grava a lista padrão', () async {
    final store = await DockStore.load(file, initial: _initial);
    expect(store.value, _initial);
    expect(await saved(), {
      'items': [
        {'app': 'foot'},
        {'app': 'org.psito.files'},
      ],
    });
  });

  test('fixar, mudar de lugar e tirar gravam no arquivo', () async {
    final store = await DockStore.load(file, initial: _initial);
    await store.pin(const DockFolder('/home/u/Downloads'));
    await store.pin(
      const DockApp('firefox-esr'),
      before: const DockApp('foot'),
    );
    // Já fixado: só muda de lugar
    await store.pin(const DockApp('foot'));
    expect(store.value, const [
      DockApp('firefox-esr'),
      DockApp('org.psito.files'),
      DockFolder('/home/u/Downloads'),
      DockApp('foot'),
    ]);
    await store.unpin(const DockApp('org.psito.files'));
    final reloaded = await DockStore.load(file, initial: const []);
    expect(reloaded.value, const [
      DockApp('firefox-esr'),
      DockFolder('/home/u/Downloads'),
      DockApp('foot'),
    ]);
  });

  test('um arquivo ilegível fica, e a dock usa a lista padrão', () async {
    await file.parent.create(recursive: true);
    await file.writeAsString('{ quebrado');
    final store = await DockStore.load(file, initial: _initial);
    expect(store.value, _initial);
    expect(await file.readAsString(), '{ quebrado');
  });

  test('itens desconhecidos ficam de fora', () async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'items': [
          {'app': 'foot'},
          {'widget': 'clima'},
          {'file': '/home/u/a.txt'},
        ],
      }),
    );
    final store = await DockStore.load(file, initial: const []);
    expect(store.value, const [DockApp('foot'), DockFile('/home/u/a.txt')]);
  });

  test('o watch relê o que outro processo gravou', () async {
    final store = await DockStore.load(file, initial: _initial);
    await store.watch(debounce: const Duration(milliseconds: 20));
    final other = await DockStore.load(file, initial: const []);
    await other.unpin(const DockApp('foot'));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(store.value, const [DockApp('org.psito.files')]);
    store.dispose();
  });
}
