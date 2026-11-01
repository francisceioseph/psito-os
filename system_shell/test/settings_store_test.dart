import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/shell/settings_store.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('psito_settings_');
    file = File('${dir.path}/psito/settings.json');
  });

  tearDown(() => dir.delete(recursive: true));

  test('arquivo ausente dá os padrões', () async {
    final store = await SettingsStore.load(file);
    expect(store.value, PsitoSettings.defaults);
  });

  test('arquivo corrompido ou que não é objeto dá os padrões', () async {
    await file.parent.create(recursive: true);
    await file.writeAsString('{ isso não é json');
    expect((await SettingsStore.load(file)).value, PsitoSettings.defaults);

    await file.writeAsString('[1, 2]');
    expect((await SettingsStore.load(file)).value, PsitoSettings.defaults);
  });

  test('JSON parcial ou com tipo errado completa com os padrões', () async {
    await file.parent.create(recursive: true);
    await file.writeAsString('{"use24h": false, "accent": "azul"}');
    final settings = (await SettingsStore.load(file)).value;
    expect(settings.use24h, isFalse);
    expect(settings.accent, PsitoSettings.defaults.accent);
    expect(settings.wallpaperId, PsitoSettings.defaults.wallpaperId);
  });

  test('update grava e um load novo lê o mesmo valor', () async {
    final store = await SettingsStore.load(file);
    const changed = PsitoSettings(
      accent: Color(0xFF2196F3),
      wallpaperId: 'oceano',
      use24h: false,
      showSeconds: true,
      doNotDisturb: true,
    );
    await store.update(changed);

    expect(file.existsSync(), isTrue);
    expect(File('${file.path}.tmp').existsSync(), isFalse);
    expect((await SettingsStore.load(file)).value, changed);
  });

  test('watch relê o que outro processo grava', () async {
    final shell = await SettingsStore.load(file);
    final settingsApp = await SettingsStore.load(file);
    await shell.watch(debounce: const Duration(milliseconds: 20));
    var notified = 0;
    shell.addListener(() => notified++);

    final changed = PsitoSettings.defaults.copyWith(
      accent: const Color(0xFF2196F3),
    );
    await settingsApp.update(changed);
    for (var i = 0; i < 50 && shell.value != changed; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(shell.value, changed);
    expect(notified, 1);

    // A própria gravação não avisa de novo
    await shell.update(changed);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(notified, 1);
    shell.dispose();
  });

  test('toJson e fromJson não perdem dados', () {
    final s = PsitoSettings.defaults.copyWith(
      accent: const Color(0xFFE91E63),
      wallpaperId: 'floresta',
      showSeconds: true,
      showBatteryPercentage: false,
      dockIconSize: 72,
      dockMagnification: false,
      dockPosition: PsitoDockPosition.left,
      dockAutoHide: true,
      desktopShowIcons: false,
      desktopIconSize: 64,
      desktopShowHome: true,
      desktopShowTrash: true,
      desktopAutoArrange: true,
    );
    expect(PsitoSettings.fromJson(s.toJson()), s);
  });

  test('o tamanho da dock fica entre o mínimo e o máximo', () {
    expect(PsitoSettings.fromJson({'dockIconSize': 500}).dockIconSize, 96);
    expect(PsitoSettings.fromJson({'dockIconSize': 'x'}).dockIconSize, 52);
  });

  test('posição da dock desconhecida cai no padrão', () {
    expect(
      PsitoSettings.fromJson({'dockPosition': 'top'}).dockPosition,
      PsitoDockPosition.bottom,
    );
    expect(
      PsitoSettings.fromJson({'dockPosition': 'right'}).dockPosition,
      PsitoDockPosition.right,
    );
  });

  test('papel de parede desconhecido cai no padrão', () {
    expect(wallpaperById('não existe').id, 'noite');
  });
}
