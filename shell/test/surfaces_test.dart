import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_shell/surfaces.dart';

const _channel = MethodChannel('test/surfaces');

Map<String, Object?> _secondary(int id) => {
  'id': id,
  'background': id * 10,
  'topbar': id * 10 + 1,
};

Map<String, Object?> _monitor(int id, int x, {bool primary = false}) => {
  'id': id,
  'x': x,
  'y': 0,
  'width': 1440,
  'height': 900,
  'scale': 1,
  'model': '',
  'primary': primary,
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
          if (call.method == 'monitors') return [_monitor(1, 0)];
          if (call.method == 'setPrimary') return call.arguments == 2;
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

  test('os monitores ficam na ordem do layout e têm um número', () async {
    final surfaces = Surfaces(_channel);
    await surfaces.start();
    expect(surfaces.monitors.value.single.rect.width, 1440);

    await _event('monitors', [
      _monitor(1, 1440, primary: true),
      _monitor(2, 0),
    ]);
    expect(surfaces.monitors.value.map((m) => m.id), [2, 1]);
    expect(surfaces.monitors.value.last.primary, isTrue);
    expect(surfaces.screenNumber(2), 1);
    expect(surfaces.screenNumber(1), 2);
    expect(surfaces.screenNumber(9), isNull);
  });

  test('trocar o principal diz se o monitor existe', () async {
    final surfaces = Surfaces(_channel);
    expect(await surfaces.setPrimary(2), isTrue);
    expect(await surfaces.setPrimary(9), isFalse);
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
