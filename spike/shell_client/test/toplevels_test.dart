import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_shell_client/toplevels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, Object> window(int id, {bool activated = false}) => {
    'id': id,
    'title': 'janela $id',
    'appId': 'foot',
    'activated': activated,
    'minimized': false,
    'maximized': false,
  };

  test('changed cria e atualiza; closed remove', () async {
    final list = ToplevelList();
    var changes = 0;
    list.addListener(() => changes++);

    await list.handle(MethodCall('changed', window(1)));
    await list.handle(MethodCall('changed', {...window(1), 'title': 'novo'}));
    expect(list.windows.single.title, 'novo');

    await list.handle(const MethodCall('closed', 1));
    expect(list.windows, isEmpty);
    expect(changes, 3);
  });

  test('a janela que ganha o foco vai para o fim', () async {
    final list = ToplevelList();
    await list.handle(MethodCall('changed', window(1)));
    await list.handle(MethodCall('changed', window(2)));
    await list.handle(MethodCall('changed', window(1, activated: true)));
    expect(list.windows.map((w) => w.id), [2, 1]);
    expect(list.activated?.id, 1);
  });

  test('start pega a lista atual do runner', () async {
    const channel = MethodChannel('psito/toplevels');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'list');
          return [window(7)];
        });
    final list = ToplevelList();
    await list.start();
    expect(list.windows.single.id, 7);
  });
}
