// O psito-sandbox (session/) pelo --dry-run: os argumentos do proxy do
// D-Bus e do bwrap para cada permissão.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _script = 'session/psito-sandbox';
const _env = {'HOME': '/home/psito', 'XDG_RUNTIME_DIR': '/run/user/1000'};

typedef _Plan = ({List<String> proxy, List<String> bwrap});

Future<_Plan> _dryRun(
  String permissions, [
  List<String> extra = const [],
  Map<String, String> env = const {},
]) async {
  final result = await Process.run(
    'bash',
    [
      _script,
      '--app',
      'org.psito.x',
      '--permissions',
      permissions,
      ...extra,
      '--dry-run',
      '--',
      '/usr/lib/psito/apps/org.psito.x/x',
    ],
    environment: {..._env, ...env},
  );
  expect(result.exitCode, 0, reason: '${result.stderr}');
  final lines = (result.stdout as String).trim().split('\n');
  final split = lines.indexOf('bwrap:');
  return (proxy: lines.sublist(1, split), bwrap: lines.sublist(split + 1));
}

/// O valor depois de [flag] (a primeira vez), ou os dois depois dele.
List<String> _after(List<String> args, String flag, [int count = 1]) {
  final i = args.indexOf(flag);
  return i < 0 ? const [] : args.sublist(i + 1, i + 1 + count);
}

const _update =
    '--call=org.psito.Settings=org.psito.Settings.Update@/org/psito/Settings';

void main() {
  test('files:removable dá a /media e o org.psito.Volumes', () async {
    final without = await _dryRun('files:home');
    expect(without.bwrap, isNot(contains('/media')));
    expect(without.proxy, isNot(contains('--talk=org.psito.Volumes')));
    final plan = await _dryRun('files:removable');
    expect(_after(plan.bwrap, '--bind-try', 2), ['/media', '/media']);
    expect(plan.proxy, contains('--talk=org.psito.Volumes'));
  });

  test('só settings fala com o org.psito.Displays', () async {
    final without = await _dryRun('network;files:home;notifications');
    expect(without.proxy, isNot(contains('--talk=org.psito.Displays')));
    final plan = await _dryRun('settings');
    expect(plan.proxy, contains('--talk=org.psito.Displays'));
  });

  group('acessibilidade', () {
    const bus = 'unix:path=/run/user/1000/at-spi/bus_0';
    const on = {'PSITO_A11Y_BUS': bus};

    test('desligada, o app não vê o barramento', () async {
      final plan = await _dryRun('');
      expect(plan.proxy, isNot(contains(bus)));
      expect(plan.bwrap.join(' '), contains('NO_AT_BRIDGE 1'));
      expect(plan.bwrap.join(' '), isNot(contains('AT_SPI_BUS_ADDRESS')));
    });

    test('ligada, passa por um proxy que só deixa se registrar', () async {
      final plan = await _dryRun('', const [], on);
      final start = plan.proxy.indexOf(bus);
      expect(start, greaterThan(0));
      final a11y = plan.proxy.sublist(start);
      expect(a11y.sublist(2, 4), ['--filter', '--sloppy-names']);
      expect(a11y.where((a) => a.startsWith('--talk')), isEmpty);
      expect(
        a11y.where((a) => a.startsWith('--call')),
        everyElement(startsWith('--call=org.a11y.atspi.Registry=')),
      );
      // Mandar teclas e ler a árvore dos outros ficam de fora
      expect(a11y.join(' '), isNot(contains('GenerateKeyboardEvent')));
      expect(a11y.join(' '), isNot(contains('atspi.Accessible')));
      expect(plan.bwrap.join(' '), isNot(contains('NO_AT_BRIDGE')));
      expect(
        plan.bwrap.join(' '),
        contains('AT_SPI_BUS_ADDRESS unix:path=/run/user/1000/at-spi/bus'),
      );
      expect(plan.bwrap, isNot(contains('/run/user/1000/at-spi/bus_0')));
    });
  });

  test(
    'sem permissões: sem rede, \$HOME privado e só leitura no D-Bus',
    () async {
      final plan = await _dryRun('');
      expect(plan.bwrap, contains('--unshare-all'));
      expect(plan.bwrap, isNot(contains('--share-net')));
      expect(plan.bwrap.indexOf('--bind'), greaterThan(0));
      expect(
        plan.bwrap.join(' '),
        contains(
          '--bind /home/psito/.local/share/psito/apps/org.psito.x /home/psito',
        ),
      );
      expect(_after(plan.bwrap, '--unsetenv'), ['DISPLAY']);
      expect(plan.proxy, isNot(contains(_update)));
      expect(
        plan.proxy,
        isNot(contains('--talk=org.freedesktop.Notifications')),
      );
      expect(
        plan.proxy,
        isNot(contains('--talk=org.freedesktop.NetworkManager')),
      );
      expect(plan.proxy, isNot(contains('--talk=org.freedesktop.timedate1')));
      expect(plan.proxy, contains('--filter'));
      expect(plan.bwrap.last, '/usr/lib/psito/apps/org.psito.x/x');
    },
  );

  test('cada permissão abre só o que é dela', () async {
    final network = await _dryRun('network');
    expect(network.bwrap, contains('--share-net'));
    expect(network.proxy, isNot(contains(_update)));

    final settings = await _dryRun('settings');
    expect(settings.proxy, contains(_update));
    expect(settings.proxy, contains('--talk=org.freedesktop.timedate1'));
    expect(settings.bwrap, isNot(contains('--share-net')));

    final notifications = await _dryRun('notifications');
    expect(
      notifications.proxy,
      contains('--talk=org.freedesktop.Notifications'),
    );

    final home = await _dryRun('files:home');
    expect(home.bwrap.join(' '), contains('--bind /home/psito /home/psito'));
  });

  test('o NetworkManager: só leitura, a menos que mude o sistema', () async {
    // As conexões guardadas têm as senhas de Wi-Fi, que ele entrega à conta
    const talk = '--talk=org.freedesktop.NetworkManager';
    final network = await _dryRun('network');
    expect(network.proxy, isNot(contains(talk)));
    final calls = network.proxy.where(
      (arg) => arg.startsWith('--call=org.freedesktop.NetworkManager='),
    );
    expect(calls, hasLength(3));
    for (final call in calls) {
      expect(call, matches(r'\.(GetManagedObjects|Get|GetAll)@'));
    }
    expect((await _dryRun('settings;network')).proxy, contains(talk));
    expect(
      (await _dryRun('settings')).proxy
          .where((arg) => arg.contains('NetworkManager')),
      isEmpty,
    );
  });

  test('o org.psito.Shell não passa para ninguém', () async {
    final all = await _dryRun('network;settings;files:home;notifications');
    expect(all.proxy.where((a) => a.contains('org.psito.Shell')), isEmpty);
  });

  test('um id com .. ou / é recusado', () async {
    for (final id in ['../x', 'a/b', '']) {
      final result = await Process.run('bash', [
        _script,
        '--app',
        id,
        '--',
        'true',
      ], environment: _env);
      expect(result.exitCode, 2, reason: id);
    }
  });

  test('o Launcher: abrir para todos, o padrão só com files:home', () async {
    String call(String method) =>
        '--call=org.psito.Launcher=org.psito.Launcher.$method@/org/psito/Launcher';
    final none = await _dryRun('');
    for (final method in [
      'Open',
      'OpenWith',
      'AppsFor',
      'NextOpen',
      'OfferDrag',
      'AcceptsDrop',
      'OpenDropped',
    ]) {
      expect(none.proxy, contains(call(method)));
    }
    expect(none.proxy, isNot(contains(call('SetDefault'))));
    expect(none.proxy, isNot(contains(call('ImportVpn'))));
    expect((await _dryRun('settings')).proxy, contains(call('ImportVpn')));
    expect((await _dryRun('files:home')).proxy, contains(call('SetDefault')));
  });

  test('o --file monta o arquivo em \$XDG_RUNTIME_DIR/doc', () async {
    final dir = await Directory.systemTemp.createTemp('psito_sandbox_file');
    final file = File('${dir.path}/a b.txt')..writeAsStringSync('oi');
    try {
      final plan = await _dryRun('', [
        '--file',
        file.path,
        '/run/user/1000/doc/0/a b.txt',
      ]);
      expect(_after(plan.bwrap, '--bind', 2).isNotEmpty, isTrue);
      final i = plan.bwrap.lastIndexOf(file.path);
      expect(plan.bwrap.sublist(i - 1, i + 2), [
        '--bind',
        file.path,
        '/run/user/1000/doc/0/a b.txt',
      ]);
      for (final inside in ['/home/psito/x', '/run/user/1000/doc/../x']) {
        final bad = await Process.run('bash', [
          _script,
          '--app',
          'org.psito.x',
          '--file',
          file.path,
          inside,
          '--dry-run',
          '--',
          'true',
        ], environment: _env);
        expect(bad.exitCode, 2, reason: inside);
      }
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
