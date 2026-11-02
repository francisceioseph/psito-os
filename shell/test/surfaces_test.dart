import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_shell/surfaces.dart';

const _channel = MethodChannel('test/surfaces');

Map<String, Object?> _secondary(int id) => {
  'id': id,
  'background': id * 10,
  'topbar': id * 10 + 1,
};

Future<void> _event(String method, Object? arguments) async {
  const codec = StandardMethodCodec();
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        _channel.name,
        codec.encodeMethodCall(MethodCall(method, arguments)),
        (_) {},
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method == 'secondaries') return [_secondary(1)];
          return null;
        });
  });

  test('pega os monitores de agora e acompanha o runner', () async {
    final surfaces = Surfaces(_channel);
    await surfaces.start();
    expect(surfaces.secondaries.value.single.background, 10);
    expect(surfaces.secondaries.value.single.topbar, 11);

    await _event('secondaries', [_secondary(1), _secondary(2)]);
    expect(surfaces.secondaries.value.map((s) => s.id), [1, 2]);
  });

  test('o foco do fundo continua chegando', () async {
    final surfaces = Surfaces(_channel);
    await surfaces.start();
    final focus = <bool>[];
    surfaces.onBackgroundFocus(focus.add);
    await _event('backgroundFocus', true);
    expect(focus, [true]);
  });
}
