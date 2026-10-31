import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:psito_shell/app_icon.dart';
import 'package:psito_shell/desktop_entries.dart';

const _firefox = '''
[Desktop Entry]
Name=Firefox ESR
Name[pt_BR]=Navegador Firefox
Exec=/usr/lib/firefox-esr/firefox-esr %u
Icon=firefox-esr
Type=Application

[Desktop Action new-window]
Name=New Window
Exec=/usr/lib/firefox-esr/firefox-esr --new-window %u
''';

void main() {
  test('lê nome, comando sem códigos de campo e ícone', () {
    final entry = DesktopEntry.parse('firefox-esr', _firefox)!;
    expect(entry.name, 'Firefox ESR');
    expect(entry.command, ['/usr/lib/firefox-esr/firefox-esr']);
    expect(entry.icon, 'firefox-esr');
    expect(entry.terminal, isFalse);
  });

  test('usa o nome do idioma, e o grupo de ações não sobrescreve', () {
    final entry = DesktopEntry.parse(
      'firefox-esr',
      _firefox,
      locale: 'pt_BR.UTF-8',
    )!;
    expect(entry.name, 'Navegador Firefox');
    expect(entry.command, ['/usr/lib/firefox-esr/firefox-esr']);
  });

  test('cai para o idioma sem região', () {
    final entry = DesktopEntry.parse(
      'x',
      '[Desktop Entry]\nName=Files\nName[pt]=Arquivos\nExec=files',
      locale: 'pt_BR.UTF-8',
    )!;
    expect(entry.name, 'Arquivos');
  });

  test('esconde NoDisplay, Hidden, outros tipos e sem Exec', () {
    for (final extra in ['NoDisplay=true', 'Hidden=true', 'Type=Link']) {
      expect(
        DesktopEntry.parse('x', '[Desktop Entry]\nName=X\nExec=x\n$extra'),
        isNull,
      );
    }
    expect(DesktopEntry.parse('x', '[Desktop Entry]\nName=X'), isNull);
  });

  test('marca os apps de terminal', () {
    final entry = DesktopEntry.parse(
      'vim',
      '[Desktop Entry]\nName=Vim\nExec=vim %F\nTerminal=true',
    )!;
    expect(entry.terminal, isTrue);
    expect(entry.command, ['vim']);
  });

  test('lê o manifesto de um app do Psito (X-Psito-*)', () {
    final entry = DesktopEntry.parse(
      'org.psito.settings',
      '[Desktop Entry]\nName=Configurações\nExec=/usr/lib/psito/x\n'
          'Icon=org.psito.settings\nX-Psito-App=settings\n'
          'X-Psito-Color=#607D8B\nX-Psito-Permissions=settings; network;;\n',
    )!;
    expect(entry.psitoApp, 'settings');
    expect(entry.color, 0xFF607D8B);
    expect(entry.permissions, ['settings', 'network']);
  });

  test('app de fora não tem manifesto; cor inválida vira null', () {
    final firefox = DesktopEntry.parse('firefox-esr', _firefox)!;
    expect(firefox.psitoApp, isNull);
    expect(firefox.color, isNull);
    expect(firefox.permissions, isEmpty);
    final bad = DesktopEntry.parse(
      'x',
      '[Desktop Entry]\nName=X\nExec=x\nX-Psito-App=x\nX-Psito-Color=azul',
    )!;
    expect(bad.color, isNull);
  });

  test('app do Psito tem a cor do manifesto; os de fora, a de destaque', () {
    const accent = Color(0xFFFFC107);
    const clock = DesktopEntry(
      id: 'org.psito.clock',
      name: 'Clock',
      command: ['clock'],
      icon: 'org.psito.clock',
      psitoApp: 'clock',
      color: 0xFFFF9800,
    );
    expect(
      appEntry(clock.id, clock.name, clock, accent).color,
      const Color(0xFFFF9800),
    );
    const foot = DesktopEntry(id: 'foot', name: 'Foot', command: ['foot']);
    expect(appEntry(foot.id, foot.name, foot, accent).color, accent);
  });

  test('loadDesktopEntries lê as pastas e o do usuário ganha', () async {
    final tmp = await Directory.systemTemp.createTemp('psito-apps');
    addTearDown(() => tmp.delete(recursive: true));
    final user = await Directory('${tmp.path}/user').create();
    final system = await Directory('${tmp.path}/system').create();
    await File('${system.path}/a.desktop')
        .writeAsString('[Desktop Entry]\nName=Sistema\nExec=a');
    await File('${user.path}/a.desktop')
        .writeAsString('[Desktop Entry]\nName=Usuário\nExec=a');
    await File('${system.path}/b.desktop')
        .writeAsString('[Desktop Entry]\nName=Beta\nExec=b');
    final entries = await loadDesktopEntries([user.path, system.path]);
    expect(entries.map((e) => e.name), ['Beta', 'Usuário']);
  });

  test('splitExec respeita aspas e escapes', () {
    expect(splitExec('sh -c "echo oi mundo"'), ['sh', '-c', 'echo oi mundo']);
    expect(splitExec(r'app a\ b  ""'), ['app', 'a b', '']);
  });

  test('pastas do usuário vêm antes das do sistema', () {
    expect(desktopEntryDirs({'HOME': '/home/psito'}), [
      '/home/psito/.local/share/applications',
      '/usr/local/share/applications',
      '/usr/share/applications',
    ]);
  });

  test('o systemd-run abre o app numa unidade própria', () {
    const firefox = DesktopEntry(
      id: 'firefox-esr',
      name: 'Firefox',
      command: ['/usr/lib/firefox-esr/firefox-esr', '--new-window'],
    );
    expect(firefox.launchCommand(random: 0xbeef), [
      'systemd-run',
      '--user',
      '--scope',
      '--collect',
      '--quiet',
      r'--unit=app-psito-firefox\x2desr-beef.scope',
      '--',
      'systemd-cat',
      '--identifier=firefox-esr',
      '/usr/lib/firefox-esr/firefox-esr',
      '--new-window',
    ]);

    const htop = DesktopEntry(
      id: 'htop',
      name: 'htop',
      command: ['htop'],
      terminal: true,
    );
    expect(htop.launchCommand(random: 1).sublist(9), ['foot', 'htop']);
  });

  test(
    'um app do Psito abre no sandbox com as permissões; os de fora, não',
    () {
      const notepad = DesktopEntry(
        id: 'org.psito.notepad',
        name: 'Notepad',
        command: ['/usr/lib/psito/apps/org.psito.notepad/psito_notepad'],
        psitoApp: 'notepad',
        permissions: ['notifications', 'network'],
      );
      expect(notepad.launchCommand(random: 1, sandbox: '/sb').sublist(9), [
        '/sb',
        '--app',
        'org.psito.notepad',
        '--permissions',
        'notifications;network',
        '--',
        '/usr/lib/psito/apps/org.psito.notepad/psito_notepad',
      ]);
      expect(notepad.launchCommand(random: 1).sublist(9), [
        '/usr/lib/psito/apps/org.psito.notepad/psito_notepad',
      ]);
      const foot = DesktopEntry(id: 'foot', name: 'Foot', command: ['foot']);
      expect(foot.launchCommand(random: 1, sandbox: '/sb').sublist(9), [
        'foot',
      ]);
    },
  );

  test('o app de um processo sai do cgroup da unidade', () {
    expect(
      appIdFromCgroup(
        '0::/user.slice/user-1000.slice/user@1000.service/app.slice/'
        'app-psito-org.psito.calculator-1a2b.scope\n',
      ),
      'org.psito.calculator',
    );
    expect(
      appIdFromCgroup(
        '0::/user.slice/user-1000.slice/user@1000.service/app.slice/'
        '${unitName('firefox-esr', 0xbeef)}',
      ),
      'firefox-esr',
    );
    expect(
      appIdFromCgroup(
        '0::/user.slice/user-1000.slice/user@1000.service/app.slice/'
        'psito-shell.service',
      ),
      isNull,
    );
  });

  test('systemdEscape como o systemd-escape', () {
    expect(systemdEscape('org.psito.settings'), 'org.psito.settings');
    expect(systemdEscape('firefox-esr'), r'firefox\x2desr');
    expect(systemdEscape('.oculto'), r'\x2eoculto');
    expect(systemdEscape('ação'), r'a\xc3\xa7\xc3\xa3o');
    for (final text in ['org.psito.settings', 'firefox-esr', 'ação']) {
      expect(systemdUnescape(systemdEscape(text)), text);
    }
  });
}
