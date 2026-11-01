import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_shell/idle.dart';

void main() {
  late List<Object?> sent;

  setUp(() {
    sent = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('psito/idle'), (
          call,
        ) async {
          sent.add(call.arguments);
          return null;
        });
  });

  test('pede em segundos, e só quando muda', () async {
    final idle = IdleWatcher();
    await idle.setMinutes(5);
    await idle.setMinutes(5);
    await idle.setMinutes(0);
    expect(sent, [300, 0]);
  });

  test('o aviso do compositor chega a quem vigia', () async {
    final idle = IdleWatcher();
    var count = 0;
    idle.onIdle = () => count++;
    await idle.handle(const MethodCall('idled'));
    expect(count, 1);
  });
}
