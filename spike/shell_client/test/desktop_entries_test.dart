import 'package:flutter_test/flutter_test.dart';
import 'package:psito_shell_client/desktop_entries.dart';

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
}
