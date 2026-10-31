import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:psito_shell/bridge/bindings.dart';
import 'package:psito_shell/bridge/bridge.dart';
import 'package:psito_shell/bridge/gtk_theme.dart';
import 'package:psito_shell/bridge/labwc.dart';
import 'package:psito_shell/bridge/wayfire.dart';
import 'package:system_shell/shell/shortcuts.dart';

const _green = Color(0xFF4CAF50);

void main() {
  group('atalhos', () {
    test('todo atalho do system_shell tem nome nos dois compositores', () {
      final bindings = compositorBindings();
      expect(bindings, hasLength(shellBindings.length + 1));
      for (final b in bindings) {
        expect(labwcKey(b), isNotEmpty);
        expect(wayfireKey(b), isNotEmpty);
      }
    });

    test('os nomes de cada compositor', () {
      String names(ShellAction action, String Function(CompositorBinding) f) =>
          [
            for (final b in compositorBindings())
              if (b.action == action) f(b),
          ].join(', ');

      expect(names(ShellAction.closeWindow, labwcKey), 'A-F4, W-q, C-A-w');
      expect(names(ShellAction.launcher, labwcKey), 'C-space, Super_L');
      expect(
        names(ShellAction.volumeUp, labwcKey),
        'XF86AudioRaiseVolume, A-S-Prior',
      );
      expect(
        names(ShellAction.closeWindow, wayfireKey),
        '<alt> KEY_F4, <super> KEY_Q, <ctrl> <alt> KEY_W',
      );
      expect(
        names(ShellAction.switchPrev, wayfireKey),
        '<alt> <shift> KEY_TAB, <ctrl> <shift> KEY_TAB',
      );
      expect(
        names(ShellAction.launcher, wayfireKey),
        '<ctrl> KEY_SPACE, <super>',
      );
    });

    test('o comando do shell passa a ação como string do GVariant', () {
      expect(
        shellCommand(ShellAction.switchNext),
        endsWith('--method org.psito.Shell.Run "\'switchNext\'"'),
      );
    });
  });

  group('labwc', () {
    test('a seção <keyboard> gerada', () {
      final keyboard = labwcKeyboard(compositorBindings());
      expect(keyboard, contains('<default />'));
      expect(
        keyboard,
        contains(
          '<keybind key="W-Left"><action name="SnapToEdge" direction="left" /></keybind>',
        ),
      );
      expect(keyboard, contains('<keybind key="Super_L" onRelease="yes">'));
      expect(
        keyboard,
        contains(
          'command="gdbus call --session --dest org.psito.Shell '
          '--object-path /org/psito/Shell --method org.psito.Shell.Run '
          '&quot;\'launcher\'&quot;"',
        ),
      );
    });

    test('troca só a seção <keyboard> do rc.xml', () {
      const rc = '''<?xml version="1.0"?>
<labwc_config>
  <core><gap>0</gap></core>
  <keyboard>
    <keybind key="C-x"><action name="Close" /></keybind>
  </keyboard>
  <mouse />
</labwc_config>
''';
      final out = replaceKeyboard(rc, '  <keyboard>novo</keyboard>');
      expect(out, contains('<core><gap>0</gap></core>'));
      expect(out, contains('<mouse />'));
      expect(out, contains('  <keyboard>novo</keyboard>'));
      expect(out, isNot(contains('C-x')));
      // De novo, sem duplicar
      expect(
        replaceKeyboard(out, '  <keyboard>outro</keyboard>'),
        isNot(contains('novo')),
      );
    });

    test('um comentário que cita <keyboard> não conta', () {
      const rc = '''<?xml version="1.0"?>
<!-- A seção <keyboard> é da ponte. -->
<labwc_config>
  <!-- troca o <keyboard> abaixo -->
  <keyboard>
    <default />
  </keyboard>
</labwc_config>
''';
      final out = replaceKeyboard(rc, '  <keyboard>novo</keyboard>');
      expect(out, contains('<!-- A seção <keyboard> é da ponte. -->'));
      expect(out, contains('<!-- troca o <keyboard> abaixo -->'));
      expect(out, contains('  <keyboard>novo</keyboard>\n</labwc_config>'));
    });

    test('rc.xml sem <keyboard> ganha uma antes do fim', () {
      final out = replaceKeyboard(
        '<labwc_config>\n  <core />\n</labwc_config>\n',
        '  <keyboard />',
      );
      expect(
        out,
        '<labwc_config>\n  <core />\n  <keyboard />\n</labwc_config>\n',
      );
    });

    test('o themerc com a cor de destaque', () {
      final theme = labwcThemerc(_green);
      expect(theme, contains('window.active.title.bg.color: #4CAF50'));
      expect(theme, contains('window.inactive.title.bg.color: #12181B'));
    });
  });

  group('Wayfire', () {
    test('as opções: activators juntos e as ações do shell no command', () {
      final options = wayfireOptions(compositorBindings(), _green);
      expect(
        options['core/close_top_view'],
        '<alt> KEY_F4 | <super> KEY_Q | <ctrl> <alt> KEY_W',
      );
      expect(
        options['grid/slot_l'],
        '<super> KEY_LEFT | <alt> <shift> KEY_LEFT',
      );

      final bindings = options['command/bindings']! as Map<String, Object>;
      final launcher = bindings['psito_launcher']! as Map<String, String>;
      expect(launcher['binding'], '<ctrl> KEY_SPACE | <super>');
      expect(launcher['command'], shellCommand(ShellAction.launcher));
      expect(bindings.keys, contains('psito_volumeMute'));

      final repeat =
          options['command/repeatable_bindings']! as Map<String, Object>;
      expect(
        repeat.keys,
        containsAll(['psito_switchNext', 'psito_volumeUp', 'psito_volumeDown']),
      );
      expect(options['decoration/active_color'], '0.298 0.686 0.314 1.000');
    });

    test('o enquadramento das mensagens do IPC', () {
      final bytes = encodeMessage('list-methods', {});
      final length = ByteData.sublistView(
        bytes,
        0,
        4,
      ).getUint32(0, Endian.little);
      expect(length, bytes.length - 4);
      expect(jsonDecode(utf8.decode(bytes.sublist(4))), {
        'method': 'list-methods',
        'data': {},
      });

      // Duas mensagens chegando em pedaços quebrados
      final decoder = MessageDecoder();
      final both = [
        ...encodeMessage('a', {}),
        ...encodeMessage('b', {'x': 1}),
      ];
      expect(decoder.add(both.sublist(0, 3)), isEmpty);
      expect(
        decoder.add(both.sublist(3, bytes.length + 2)).map((m) => m['method']),
        ['a'],
      );
      expect(decoder.add(both.sublist(bytes.length + 2)).single['data'], {
        'x': 1,
      });
    });
  });

  group('tema GTK', () {
    late Directory home;
    setUp(() => home = Directory.systemTemp.createTempSync('psito-gtk'));
    tearDown(() => home.deleteSync(recursive: true));

    test('grava o CSS e o settings.ini nos dois GTK', () async {
      expect(await applyGtkTheme(home, _green), isEmpty);
      for (final v in ['gtk-3.0', 'gtk-4.0']) {
        final css = File('${home.path}/$v/gtk.css').readAsStringSync();
        expect(css, startsWith(gtkThemeHeader));
        expect(css, contains('@define-color accent_bg_color #4CAF50;'));
        expect(css, contains('@define-color theme_selected_bg_color #4CAF50;'));
        expect(
          File('${home.path}/$v/settings.ini').readAsStringSync(),
          contains('gtk-application-prefer-dark-theme=1'),
        );
      }
      // Trocar a cor regrava
      await applyGtkTheme(home, const Color(0xFF2196F3));
      expect(
        File('${home.path}/gtk-4.0/gtk.css').readAsStringSync(),
        contains('#2196F3'),
      );
    });

    test('não sobrescreve o gtk.css do usuário', () async {
      final mine = File('${home.path}/gtk-3.0/gtk.css')
        ..createSync(recursive: true)
        ..writeAsStringSync('window { color: red; }');
      expect(await applyGtkTheme(home, _green), [mine.path]);
      expect(mine.readAsStringSync(), 'window { color: red; }');
    });
  });

  test('o compositor vem do ambiente', () {
    expect(detectCompositor({'LABWC_PID': '1'}), Compositor.labwc);
    expect(detectCompositor({'WAYFIRE_SOCKET': '/tmp/s'}), Compositor.wayfire);
    expect(detectCompositor({}), Compositor.unknown);
  });
}
