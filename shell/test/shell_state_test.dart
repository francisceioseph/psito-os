import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_dock/psito_dock.dart';
import 'package:psito_shell/desktop_entries.dart';
import 'package:psito_shell/dock.dart';
import 'package:psito_shell/notifications_server.dart';
import 'package:psito_shell/shell_state.dart';
import 'package:psito_shell/surfaces.dart';
import 'package:psito_shell/toplevels.dart';
import 'package:psito_services/system_services.dart';
import 'package:system_shell/shell/settings_store.dart';
import 'package:system_shell/shell/shortcuts.dart';

const _toplevels = MethodChannel('test/toplevels');
const _surfaces = MethodChannel('test/surfaces');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late ShellState state;
  late List<MethodCall> toplevelCalls;
  late List<MethodCall> surfaceCalls;

  Future<void> window(int id, String appId, {bool activated = false}) =>
      state.toplevels.handle(
        MethodCall('changed', {
          'id': id,
          'title': 'janela $id',
          'appId': appId,
          'activated': activated,
        }),
      );

  KeyEvent down(LogicalKeyboardKey key, PhysicalKeyboardKey physical) =>
      KeyDownEvent(
        physicalKey: physical,
        logicalKey: key,
        timeStamp: Duration.zero,
      );

  setUp(() {
    toplevelCalls = [];
    surfaceCalls = [];
    messenger.setMockMethodCallHandler(_toplevels, (call) async {
      toplevelCalls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(_surfaces, (call) async {
      surfaceCalls.add(call);
      return null;
    });
    state = ShellState(
      settings: SettingsStore.memory(),
      services: SystemServices.fake(),
      toplevels: ToplevelList(channel: _toplevels),
      surfaces: const Surfaces(_surfaces),
      osdDuration: const Duration(milliseconds: 50),
    );
    state.apps.value = const [
      DesktopEntry(id: 'foot', name: 'Foot', command: ['foot'], icon: 'foot'),
    ];
  });

  group('Alt+Tab', () {
    test('Runs repetidos avançam e soltar o Ctrl ativa a escolhida', () async {
      await window(1, 'foot');
      await window(2, 'firefox-esr');
      await window(3, 'foot', activated: true);

      state.run(ShellAction.switchNext);
      expect(state.switcher.windows.map((w) => w.id), ['3', '2', '1']);
      expect(state.switcher.selectedId, '2');
      expect(
        surfaceCalls.last,
        isMethodCall('showOverlay', arguments: 'exclusive'),
      );

      state.run(ShellAction.switchNext);
      expect(state.switcher.selectedId, '1');
      state.run(ShellAction.switchPrev);
      expect(state.switcher.selectedId, '2');

      // A janela de um app com .desktop pega o nome dele
      expect(state.switcher.windows.first.app.name, 'Foot');

      final handled = state.handleKey(
        const KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.controlLeft,
          logicalKey: LogicalKeyboardKey.controlLeft,
          timeStamp: Duration.zero,
        ),
      );
      expect(handled, isTrue);
      expect(state.switcher.isOpen, isFalse);
      expect(toplevelCalls.last, isMethodCall('activate', arguments: 2));
      expect(surfaceCalls.last, isMethodCall('hideOverlay', arguments: null));
    });

    test('Tab que chega ao shell avança; Esc cancela', () async {
      await window(1, 'foot');
      await window(2, 'foot', activated: true);
      state.run(ShellAction.switchNext);
      expect(state.switcher.selectedId, '1');

      state.handleKey(down(LogicalKeyboardKey.tab, PhysicalKeyboardKey.tab));
      expect(state.switcher.selectedId, '2');
      state.handleKey(
        down(LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape),
      );
      expect(state.switcher.isOpen, isFalse);
      expect(toplevelCalls.where((c) => c.method == 'activate'), isEmpty);
    });

    test(
      'com uma janela só não abre, e sem seletor as teclas passam',
      () async {
        await window(1, 'foot', activated: true);
        state.run(ShellAction.switchNext);
        expect(state.switcher.isOpen, isFalse);
        expect(
          state.handleKey(
            down(LogicalKeyboardKey.tab, PhysicalKeyboardKey.tab),
          ),
          isFalse,
        );
      },
    );
  });

  test('a dock segue o dock.json e as janelas abertas', () async {
    List<String> ids() => [for (final slot in state.dockSections.apps) slot.id];
    // Os da primeira vez que não estão instalados ficam escondidos
    expect(ids(), ['foot']);
    await window(1, 'org.gtk.Demo4');
    expect(ids(), ['foot', 'org.gtk.Demo4']);
    expect(state.dockSections.running.single.name, 'janela 1');

    await state.dock.pin(
      const DockApp('org.gtk.Demo4'),
      before: const DockApp('foot'),
    );
    expect(ids(), ['org.gtk.Demo4', 'foot']);
    expect(state.dockSections.running, isEmpty);
    await state.dock.unpin(const DockApp('foot'));
    expect(ids(), ['org.gtk.Demo4']);
  });

  test('o clique na dock ativa e minimiza pelo foreign-toplevel', () async {
    await window(1, 'foot');
    state.tapDock(state.dockSections.pinned.single);
    expect(toplevelCalls.last, isMethodCall('activate', arguments: 1));
    await window(1, 'foot', activated: true);
    state.tapDock(state.dockSections.pinned.single);
    expect(
      toplevelCalls.last,
      isMethodCall('minimize', arguments: {'id': 1, 'minimized': true}),
    );
  });

  group('mostrar a área de trabalho', () {
    Future<void> minimized(int id, {bool activated = false}) =>
        state.toplevels.handle(
          MethodCall('changed', {
            'id': id,
            'appId': 'foot',
            'minimized': true,
            'activated': activated,
          }),
        );

    List<Object?> calls(String method) => [
      for (final call in toplevelCalls)
        if (call.method == method)
          call.arguments is Map
              ? (call.arguments as Map)['id']
              : call.arguments,
    ];

    Future<void> hideAll() async {
      await window(1, 'foot');
      await window(2, 'foot');
      await window(3, 'foot', activated: true);
      state.run(ShellAction.showDesktop);
      await minimized(1);
      await minimized(2);
      await minimized(3);
    }

    test('minimiza as visíveis, e repetir traz de volta na ordem', () async {
      await hideAll();
      expect(calls('minimize'), [1, 2, 3]);
      state.run(ShellAction.showDesktop);
      expect(calls('activate'), [1, 2, 3]);
    });

    test('a que já estava minimizada fica', () async {
      await window(1, 'foot', activated: true);
      await minimized(2);
      state.run(ShellAction.showDesktop);
      expect(calls('minimize'), [1]);
      await minimized(1);
      state.run(ShellAction.showDesktop);
      expect(calls('activate'), [1]);
    });

    test('o foco passando entre as que estão saindo não esquece', () async {
      await window(1, 'foot');
      await window(2, 'foot', activated: true);
      state.run(ShellAction.showDesktop);
      // O compositor foca a 1 ao minimizar a 2, antes de minimizar a 1
      await minimized(2);
      await window(1, 'foot', activated: true);
      await minimized(1);
      state.run(ShellAction.showDesktop);
      expect(calls('activate'), [1, 2]);
    });

    test('ativar uma janela nesse meio esquece a lista', () async {
      await hideAll();
      await window(2, 'foot', activated: true);
      toplevelCalls.clear();
      state.run(ShellAction.showDesktop);
      expect(calls('activate'), isEmpty);
      expect(calls('minimize'), [2]);
    });

    test('abrir uma janela nesse meio esquece a lista', () async {
      await hideAll();
      await window(4, 'foot', activated: true);
      toplevelCalls.clear();
      state.run(ShellAction.showDesktop);
      expect(calls('activate'), isEmpty);
      expect(calls('minimize'), [4]);
    });

    test('a que fechou nesse meio não volta', () async {
      await hideAll();
      await state.toplevels.handle(const MethodCall('closed', 2));
      state.run(ShellAction.showDesktop);
      expect(calls('activate'), [1, 3]);
    });

    test('sem janelas, não faz nada', () async {
      state.run(ShellAction.showDesktop);
      expect(toplevelCalls.where((c) => c.method == 'minimize'), isEmpty);
    });
  });

  test('o volume pelo atalho mostra o OSD por um tempo', () async {
    final before = state.services.audio.state.value.volume;
    state.run(ShellAction.volumeUp);
    await Future<void>.delayed(Duration.zero);
    expect(
      state.services.audio.state.value.volume,
      closeTo(before + 0.05, 1e-9),
    );
    expect(state.osd.value, isTrue);
    expect(surfaceCalls.last, isMethodCall('show', arguments: 'osd'));

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(state.osd.value, isFalse);
    expect(surfaceCalls.last, isMethodCall('hide', arguments: 'osd'));
  });

  test('notificação de fora vira toast com o app do .desktop', () async {
    final id = state.notify(
      const IncomingNotification(
        appName: 'foot',
        summary: 'pronto',
        body: 'compilou',
        desktopEntry: 'foot',
      ),
    );
    final n = state.notifications.toasts.single;
    expect(n.id, id);
    expect(n.appName, 'Foot');
    expect(n.windowId, isNull);
    expect(surfaceCalls.last, isMethodCall('show', arguments: 'toasts'));

    // Clicar ativa a janela do app
    await window(7, 'foot');
    int? tapped;
    state.onNotificationTapped = (id) => tapped = id;
    state.openNotification(n);
    expect(tapped, id);
    expect(toplevelCalls.last, isMethodCall('activate', arguments: 7));

    state.notifications.dismissToast(id);
    expect(surfaceCalls.last, isMethodCall('hide', arguments: 'toasts'));
  });

  test('um .desktop novo aparece sem recarregar à mão', () async {
    final tmp = await Directory.systemTemp.createTemp('psito-watch');
    addTearDown(() => tmp.delete(recursive: true));
    final env = {'HOME': tmp.path, 'XDG_DATA_DIRS': ''};
    await state.watchApps(env);
    expect(state.apps.value, isEmpty);
    await File('${tmp.path}/.local/share/applications/org.psito.x.desktop')
        .writeAsString('[Desktop Entry]\nName=X\nExec=x\nX-Psito-App=x');
    for (var i = 0; i < 40 && state.apps.value.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(state.apps.value.single.psitoApp, 'x');
  });

  test('só os apps do Psito com settings gravam as configurações', () {
    state.apps.value = const [
      DesktopEntry(
        id: 'org.psito.settings',
        name: 'Configurações',
        command: ['s'],
        psitoApp: 'settings',
        permissions: ['settings', 'network'],
      ),
      DesktopEntry(
        id: 'org.psito.calculator',
        name: 'Calculator',
        command: ['c'],
        psitoApp: 'calculator',
      ),
      DesktopEntry(id: 'foot', name: 'Foot', command: ['foot']),
    ];
    expect(state.maySetSettings('org.psito.settings'), isTrue);
    expect(state.maySetSettings('org.psito.calculator'), isFalse);
    expect(state.maySetSettings('foot'), isTrue);
    expect(state.maySetSettings(null), isTrue);
  });

  group('a área de transferência', () {
    Map<String, Uint8List> text(String value) => {
      'text/plain;charset=utf-8': Uint8List.fromList(value.codeUnits),
    };

    test('o atalho copia de novo e avisa no OSD', () {
      addTearDown(state.clipboard.clear);
      state.clipboard.copied(text('a'));
      state.clipboard.copied(text('b'));
      state.run(ShellAction.clipboard2);
      expect(state.clipboard.entries.first.preview, 'a');
      expect(state.osdClip.value?.preview, 'a');
      expect(state.osd.value, isTrue);
      expect(surfaceCalls.last, isMethodCall('show', arguments: 'osd'));
    });

    test('uma posição vazia não faz nada', () {
      state.run(ShellAction.clipboard3);
      expect(state.osd.value, isFalse);
    });

    test('o painel abre com o teclado, para escolher pelo número', () {
      state.run(ShellAction.clipboard);
      expect(state.overlay.value, ShellOverlay.clipboard);
      expect(
        surfaceCalls.last,
        isMethodCall('showOverlay', arguments: 'exclusive'),
      );
      state.run(ShellAction.clipboard);
      expect(state.overlay.value, isNull);
    });

    test('o volume tira o item do OSD', () {
      addTearDown(state.clipboard.clear);
      state.clipboard.copied(text('a'));
      state.run(ShellAction.clipboard1);
      expect(state.osdClip.value, isNotNull);
      state.run(ShellAction.volumeMute);
      expect(state.osdClip.value, isNull);
    });
  });

  test('o atalho de bloquear fecha o que está aberto e sobe a tela', () async {
    var locks = 0;
    state.startLock = () async => locks++;
    state.toggle(ShellOverlay.power);
    state.run(ShellAction.lock);
    await Future<void>.delayed(Duration.zero);
    expect(locks, 1);
    expect(state.overlay.value, isNull);
  });
}
