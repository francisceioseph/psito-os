// Abrir arquivos: os códigos de campo do Exec, o que o sandbox monta, o
// caminho que o chamador vê e o org.psito.Launcher num barramento privado.
import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_fs/psito_fs.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/launcher_client.dart';
import 'package:psito_shell/desktop_entries.dart';
import 'package:psito_shell/launcher_bus.dart';
import 'package:psito_shell/opener.dart';

DesktopEntry _entry(String id, String content) =>
    DesktopEntry.parse(id, '[Desktop Entry]\n$content')!;

final _files = _entry('org.psito.files', '''
Name=Files
Exec=/usr/lib/psito/apps/org.psito.files/psito_files %U
MimeType=inode/directory;
X-Psito-App=files
X-Psito-Permissions=files:home;files:removable;
''');
final _notepad = _entry('org.psito.notepad', '''
Name=Notepad
Exec=/usr/lib/psito/apps/org.psito.notepad/psito_notepad %f
MimeType=text/plain;
X-Psito-App=notepad
''');
final _settings = _entry('org.psito.settings', '''
Name=Settings
Exec=/usr/lib/psito/apps/org.psito.settings/psito_settings
X-Psito-App=settings
X-Psito-Permissions=settings;network;
''');
final _firefox = _entry('firefox-esr', '''
Name=Firefox
Exec=/usr/lib/firefox-esr/firefox-esr %u
MimeType=text/html;
''');

void main() {
  group('Exec', () {
    test('%F e %U num comando, %f e %u um por arquivo, sem código nada', () {
      expect(_files.commandsFor(['/a b', '/c']), [
        [
          '/usr/lib/psito/apps/org.psito.files/psito_files',
          'file:///a%20b',
          'file:///c',
        ],
      ]);
      expect(_notepad.commandsFor(['/a', '/b']).map((c) => c.last), [
        '/a',
        '/b',
      ]);
      expect(
        _firefox.commandsFor(['/x y.html']).single.last,
        'file:///x%20y.html',
      );
      final plain = _entry('foot', 'Name=Foot\nExec=foot\n');
      expect(plain.commandsFor(['/a']), [
        ['foot'],
      ]);
      final embedded = _entry('x', 'Name=X\nExec=x --file=%f %i\n');
      expect(embedded.commandsFor(['/a']), [
        ['x', '--file=/a'],
      ]);
      expect(_files.commandsFor(const []), [_files.command]);
      expect(_notepad.mimeTypes, ['text/plain']);
    });

    test('os --file vão para o sandbox, antes do --', () {
      final command = _notepad.launchCommand(
        random: 1,
        sandbox: '/sb',
        command: ['/n', '/run/user/1000/doc/0/a.txt'],
        files: [('/home/u/a.txt', '/run/user/1000/doc/0/a.txt')],
      );
      expect(command.sublist(9), [
        '/sb',
        '--app',
        'org.psito.notepad',
        '--permissions',
        '',
        '--file',
        '/home/u/a.txt',
        '/run/user/1000/doc/0/a.txt',
        '--',
        '/n',
        '/run/user/1000/doc/0/a.txt',
      ]);
    });
  });

  group('Opener', () {
    late Directory tmp;
    late Opener opener;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('psito_opener');
      File('${tmp.path}/nota.txt').writeAsStringSync('oi');
      Directory('${tmp.path}/pasta').createSync();
      opener = Opener(
        env: {
          'HOME': tmp.path,
          'XDG_RUNTIME_DIR': '/run/user/1000',
          'XDG_DATA_HOME': '${tmp.path}/.local/share',
        },
        mime: MimeDatabase.empty(),
        sandbox: '/sb',
        apps: () => [_firefox, _files, _notepad],
        mimeApps: MimeApps.empty,
      );
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('um disco externo só é visto com files:removable', () {
      const disk = '/media/ana/PENDRIVE';
      expect(opener.fromCaller('org.psito.files', '$disk/a'), '$disk/a');
      expect(opener.fromCaller('org.psito.notepad', '$disk/a'), isNull);
      // Montar por cima, com o --file, seguraria o disco
      final plan = opener.plan([disk], withApp: 'org.psito.files').single;
      expect(plan.files, isEmpty);
      expect(plan.paths, [disk]);
      final other = opener.plan(['$disk/a.txt'], withApp: 'org.psito.notepad');
      expect(other.single.files.single.$1, '$disk/a.txt');
    });

    test('o caminho que o chamador vê, pelas permissões', () {
      final home = tmp.path;
      // Fora de um app (o shell, um terminal) e apps de fora: como veio
      expect(opener.fromCaller(null, '/tmp/x'), '/tmp/x');
      expect(opener.fromCaller('firefox-esr', '$home/a'), '$home/a');
      // files:home vê o home, o /usr e o /etc, e nada além
      expect(opener.fromCaller('org.psito.files', '$home/a/../b'), '$home/b');
      expect(
        opener.fromCaller('org.psito.files', '/usr/share/x'),
        '/usr/share/x',
      );
      expect(opener.fromCaller('org.psito.files', '/tmp/x'), isNull);
      // Sem files:home, o home é o privado do app
      expect(
        opener.fromCaller('org.psito.notepad', '$home/nota.txt'),
        '$home/.local/share/psito/apps/org.psito.notepad/nota.txt',
      );
      expect(
        opener.fromCaller('org.psito.notepad', '/etc/hosts'),
        '/etc/hosts',
      );
      expect(opener.fromCaller('org.psito.notepad', 'relativo'), isNull);
    });

    test('cada arquivo no seu app, com o --file para quem não vê', () {
      final plans = opener.plan(['${tmp.path}/nota.txt', '${tmp.path}/pasta']);
      expect(plans.map((p) => p.app.id), [
        'org.psito.notepad',
        'org.psito.files',
      ]);
      final notepad = plans.first;
      expect(notepad.files, [
        ('${tmp.path}/nota.txt', '/run/user/1000/doc/0/nota.txt'),
      ]);
      expect(notepad.commands.single.last, '/run/user/1000/doc/0/nota.txt');
      // O Files tem files:home: vê a pasta como ela é
      expect(plans.last.files, isEmpty);
      expect(plans.last.paths, ['${tmp.path}/pasta']);
      // Com outro app, à força; e um tipo sem app
      expect(
        opener
            .plan(['${tmp.path}/pasta'], withApp: 'firefox-esr')
            .single
            .app
            .id,
        'firefox-esr',
      );
      File('${tmp.path}/x.bin').writeAsBytesSync([0, 1, 2]);
      expect(
        () => opener.plan(['${tmp.path}/x.bin']),
        throwsA(isA<NoAppException>()),
      );
    });
  });

  group('org.psito.Launcher', () {
    late Directory dir;
    late DBusServer server;
    late DBusClient shellBus;
    late DBusClient appBus;
    late DBusAddress address;
    late LauncherBusObject launcher;
    late List<OpenPlan> launched;
    late List<(String, String)> defaults;
    String? caller;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('psito_launcher_bus_');
      File('${dir.path}/nota.txt').writeAsStringSync('oi');
      server = DBusServer();
      address = await server.listenAddress(DBusAddress.unix(dir: dir));
      shellBus = DBusClient(address);
      appBus = DBusClient(address);
      launched = [];
      defaults = [];
      caller = null;
      launcher = LauncherBusObject(
        opener: Opener(
          env: {'HOME': dir.path, 'XDG_RUNTIME_DIR': '/run/user/1000'},
          mime: MimeDatabase.empty(),
          sandbox: '/sb',
          apps: () => [_firefox, _files, _notepad, _settings],
          mimeApps: MimeApps.empty,
        ),
        callerOf: (_) async => caller,
        launch: (plan) async => launched.add(plan),
        setDefault: (mime, app) async => defaults.add((mime, app)),
        importVpn: (path) async => path.contains('ruim') ? null : 'uuid-1',
        isConnected: (sender) => shellBus.nameHasOwner(sender),
        waitLimit: const Duration(milliseconds: 300),
      );
      await publishLauncher(shellBus, launcher);
    });

    tearDown(() async {
      await appBus.close();
      await shellBus.close();
      await server.close();
      await dir.delete(recursive: true);
    });

    test('abrir, abrir com e os apps de um tipo', () async {
      final client = LauncherClient(appBus);
      await client.open(['${dir.path}/nota.txt']);
      expect(launched.single.app.id, 'org.psito.notepad');
      await client.open(['${dir.path}/nota.txt'], withApp: 'firefox-esr');
      expect(launched.last.app.id, 'firefox-esr');
      expect(await client.appsFor('text/plain'), [
        const PsitoAppChoice(
          id: 'org.psito.notepad',
          name: 'Notepad',
          isDefault: true,
        ),
      ]);
      File('${dir.path}/x.bin').writeAsBytesSync([0, 1]);
      await expectLater(
        client.open(['${dir.path}/x.bin']),
        throwsA(
          isA<PsitoOpenException>().having(
            (e) => e.detail,
            'detail',
            contains('x.bin'),
          ),
        ),
      );
    });

    test('o Quick Look vai com a marca nos argumentos do Files', () async {
      final path = '${dir.path}/nota.txt';
      await launcher.preview(path);
      final plan = launched.single;
      expect(plan.app.id, 'org.psito.files');
      expect(plan.paths, ['$psitoQuickLookPrefix$path']);
      expect(plan.commands.single, contains('$psitoQuickLookPrefix$path'));
      expect(plan.commands.single, isNot(contains(path)));
    });

    test('importar uma VPN é só de quem tem settings', () async {
      final client = LauncherClient(appBus);
      caller = 'org.psito.settings';
      expect(await client.importVpn('/home/ana/x.conf'), 'uuid-1');
      await expectLater(
        client.importVpn('/home/ana/ruim.conf'),
        throwsA(anything),
      );
      caller = 'org.psito.notepad';
      await expectLater(
        client.importVpn('/home/ana/x.conf'),
        throwsA(anything),
      );
    });

    test('o caminho que o app não vê e o padrão sem files:home', () async {
      final client = LauncherClient(appBus);
      caller = 'org.psito.files';
      await expectLater(
        client.open(['/tmp/x']),
        throwsA(isA<PsitoOpenException>()),
      );
      await client.setDefault('text/plain', 'firefox-esr');
      expect(defaults, [('text/plain', 'firefox-esr')]);
      caller = 'org.psito.notepad';
      await expectLater(
        client.setDefault('text/plain', 'firefox-esr'),
        throwsA(isA<DBusMethodResponseException>()),
      );
      expect(defaults, hasLength(1));
    });

    group('o que solta na janela', () {
      late String nota;

      setUp(() => nota = '${dir.path}/nota.txt');

      test('só abre o que a origem ofereceu', () async {
        final client = LauncherClient(appBus);
        caller = 'org.psito.notepad';
        expect(await client.acceptsDrop([nota]), isFalse);
        expect(await client.openDropped([nota]), isFalse);
        expect(launched, isEmpty);

        caller = 'org.psito.files';
        await client.offerDrag([nota]);
        caller = 'org.psito.notepad';
        expect(await client.acceptsDrop([nota]), isTrue);
        expect(await client.acceptsDrop([nota, '/tmp/x']), isFalse);
        expect(await client.openDropped([nota]), isTrue);
        final plan = launched.single;
        expect(plan.app.id, 'org.psito.notepad');
        // O app não vê o arquivo: vai pelo --file
        expect(plan.files.single.$1, nota);
      });

      test('vale uma vez', () async {
        final client = LauncherClient(appBus);
        launcher.offerDrag([nota]);
        caller = 'org.psito.notepad';
        expect(await client.openDropped([nota]), isTrue);
        expect(await client.openDropped([nota]), isFalse);
        expect(launched, hasLength(1));
      });

      test('só um tipo que o app abre', () async {
        final client = LauncherClient(appBus);
        File('${dir.path}/x.bin').writeAsBytesSync([0, 1]);
        launcher.offerDrag(['${dir.path}/x.bin']);
        caller = 'org.psito.notepad';
        expect(await client.acceptsDrop(['${dir.path}/x.bin']), isFalse);
      });

      test('a origem não oferece o que ela não vê', () async {
        final client = LauncherClient(appBus);
        caller = 'org.psito.files';
        await client.offerDrag(['/etc/../tmp/x']);
        caller = 'org.psito.notepad';
        expect(await client.acceptsDrop(['/etc/../tmp/x']), isFalse);
      });

      test('o caminho da origem no sandbox vira o de verdade', () async {
        final client = LauncherClient(appBus);
        final real =
            '${dir.path}/.local/share/psito/apps/org.psito.notepad/nota.txt';
        File(real)
          ..createSync(recursive: true)
          ..writeAsStringSync('oi');
        caller = 'org.psito.notepad';
        await client.offerDrag([nota]);
        expect(await client.openDropped([nota]), isTrue);
        expect(launched.single.files.single.$1, real);
      });

      test('a oferta vence', () async {
        final old = LauncherBusObject(
          opener: launcher.opener,
          callerOf: (_) async => 'org.psito.notepad',
          launch: (plan) async => launched.add(plan),
          setDefault: (_, _) async {},
          offerLimit: Duration.zero,
        );
        old.offerDrag([nota]);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        final reply = await old.handleMethodCall(
          DBusMethodCall(
            sender: ':1.1',
            interface: launcherInterface,
            name: 'AcceptsDrop',
            values: [
              DBusArray.string([nota]),
            ],
          ),
        );
        expect(reply.returnValues.single, const DBusBoolean(false));
      });
    });

    test('a instância que espera recebe os arquivos', () async {
      caller = 'org.psito.files';
      final requests = <List<String>>[];
      final sub = LauncherClient(appBus).openRequests().listen(requests.add);
      for (var i = 0; i < 50 && !launcher.waiting('org.psito.files'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      caller = null;
      await launcher.openPaths([dir.path]);
      for (var i = 0; i < 50 && requests.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(requests, [
        [dir.path],
      ]);
      expect(launched, isEmpty);
      // Depois do tempo-limite o app volta a esperar, sem receber vazio
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(requests, hasLength(1));
      await sub.cancel();
    });

    test('a instância que saiu do barramento não recebe: abre outra', () async {
      caller = 'org.psito.files';
      final gone = DBusClient(address);
      unawaited(
        gone
            .callMethod(
              destination: launcherBusName,
              path: launcherPath,
              interface: launcherInterface,
              name: 'NextOpen',
            )
            .catchError((_) => DBusMethodSuccessResponse()),
      );
      for (var i = 0; i < 50 && !launcher.waiting('org.psito.files'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(launcher.waiting('org.psito.files'), isTrue);
      await gone.close();
      caller = null;
      await launcher.openPaths([dir.path]);
      expect(launched.single.app.id, 'org.psito.files');
      expect(launcher.waiting('org.psito.files'), isFalse);
    });
  });
}
