import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:psito_shell/autostart.dart';
import 'package:psito_shell/desktop_entries.dart';

void main() {
  late Directory tmp;
  late Map<String, String> env;
  late Autostart autostart;

  void write(String dir, String id, String body) {
    final file = File('${tmp.path}/$dir/autostart/$id.desktop');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '[Desktop Entry]\nType=Application\nName=$id\n$body',
    );
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('psito_autostart_');
    env = {
      'HOME': tmp.path,
      'XDG_CONFIG_HOME': '${tmp.path}/user',
      'XDG_CONFIG_DIRS': '${tmp.path}/xdg',
      'XDG_CURRENT_DESKTOP': 'Psito:labwc',
      'XDG_RUNTIME_DIR': '${tmp.path}/run',
      'WAYLAND_DISPLAY': 'wayland-0',
    };
    autostart = Autostart(env, canExec: (program) => program != 'ausente');
  });
  tearDown(() => tmp.delete(recursive: true));

  test('segue os desktops, o TryExec, o Hidden e o do usuário', () async {
    write('xdg', 'dirs', 'Exec=xdg-user-dirs-update\nNoDisplay=true');
    write('xdg', 'gnome', 'Exec=g\nOnlyShowIn=GNOME;');
    write('xdg', 'nao-labwc', 'Exec=n\nNotShowIn=labwc;');
    write('xdg', 'sem-programa', 'Exec=x\nTryExec=ausente');
    write('xdg', 'desligado', 'Exec=d\nX-GNOME-Autostart-enabled=false');
    write('xdg', 'escondido', 'Exec=e');
    write('user', 'escondido', 'Exec=e\nHidden=true');
    write('user', 'foot', 'Exec=foot\nOnlyShowIn=labwc;');
    final ids = [for (final entry in await autostart.entries()) entry.id]
      ..sort();
    expect(ids, ['dirs', 'foot']);
    expect(autostart.enabled('foot'), isTrue);
    expect(autostart.enabled('escondido'), isFalse);
  });

  test('ligar copia o .desktop do app; desligar apaga ou esconde', () async {
    final source = File('${tmp.path}/foot.desktop')
      ..writeAsStringSync('[Desktop Entry]\nName=Foot\nExec=foot\nIcon=foot');
    final foot = DesktopEntry(
      id: 'foot',
      name: 'Foot',
      command: const ['foot'],
      path: source.path,
    );
    await autostart.set(foot, true);
    expect(
      autostart.userFile('foot').readAsStringSync(),
      contains('Icon=foot'),
    );
    expect(autostart.enabled('foot'), isTrue);
    await autostart.set(foot, false);
    expect(autostart.userFile('foot').existsSync(), isFalse);

    // Um do sistema com o mesmo nome fica escondido pelo do usuário
    write('xdg', 'foot', 'Exec=foot');
    expect(autostart.enabled('foot'), isTrue);
    await autostart.set(foot, false);
    expect(
      autostart.userFile('foot').readAsStringSync(),
      contains('Hidden=true'),
    );
    expect(autostart.enabled('foot'), isFalse);
  });

  test('abre uma vez por sessão do compositor', () async {
    write('user', 'foot', 'Exec=foot');
    final socket = File('${tmp.path}/run/wayland-0')
      ..createSync(recursive: true);
    final launched = <String>[];
    Future<void> launch(DesktopEntry entry) async => launched.add(entry.id);
    expect(await autostart.runOnce(launch), ['foot']);
    // O shell reiniciou na mesma sessão
    expect(await autostart.runOnce(launch), isEmpty);
    // O compositor subiu de novo: o socket é outro
    socket.setLastModifiedSync(DateTime(2020));
    expect(await autostart.runOnce(launch), ['foot']);
    expect(launched, ['foot', 'foot']);
  });
}
