import 'package:flutter_test/flutter_test.dart';
import 'package:psito_services/session_service.dart';

void main() {
  group('SleepGuard', () {
    late List<String> calls;
    late SleepGuard guard;

    setUp(() {
      calls = [];
      guard = SleepGuard(
        inhibit: () async {
          calls.add('inhibit');
          return 'fd';
        },
        release: (handle) async => calls.add('release $handle'),
        beforeSleep: () async => calls.add('lock'),
      );
    });

    test(
      'bloqueia antes de soltar a suspensão, e pega de novo ao acordar',
      () async {
        await guard.start();
        await guard.prepareForSleep(true);
        expect(calls, ['inhibit', 'lock', 'release fd']);
        await guard.prepareForSleep(false);
        expect(calls.last, 'inhibit');
      },
    );

    test('um bloqueio que falha não segura a suspensão', () async {
      final failing = SleepGuard(
        inhibit: () async => 'fd',
        release: (handle) async => calls.add('release $handle'),
        beforeSleep: () async => throw StateError('sem bloqueio'),
      );
      await failing.start();
      await expectLater(failing.prepareForSleep(true), throwsStateError);
      expect(calls, ['release fd']);
    });
  });
}
