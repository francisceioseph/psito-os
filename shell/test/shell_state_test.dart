import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_shell/desktop_entries.dart';
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
}
