// Os apps (apps/<id>/) só falam com o shell pelo psito_sdk e pelo
// psito_runtime: cada um é um processo e um pacote à parte, e qualquer import
// do shell ou dos serviços quebraria essa fronteira.
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/shell/app_registry.dart';

final _import = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

const _forbidden = [
  'package:system_shell/',
  'package:psito_shell/',
  'package:psito_services/',
];

final _appsDir = Directory('../apps');

List<Directory> _appProjects() =>
    _appsDir.listSync().whereType<Directory>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));

String _name(FileSystemEntity entity) =>
    entity.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty);

void main() {
  test('apps não importam o shell nem os serviços', () {
    final violations = <String>[];
    for (final project in _appProjects()) {
      final lib = Directory('${project.path}/lib');
      for (final file in lib.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        for (final match in _import.allMatches(file.readAsStringSync())) {
          final uri = match.group(1)!;
          if (uri.startsWith('../') || _forbidden.any(uri.startsWith)) {
            violations.add('${file.path}: $uri');
          }
        }
      }
    }
    expect(violations, isEmpty);
  });

  test('ids dos apps são únicos', () {
    final ids = registeredApps.map((app) => app.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('todo app do laboratório é um projeto em apps/, e só eles', () {
    expect(_appProjects().map(_name).toSet(), {
      for (final app in registeredApps) app.id,
    });
  });

  test('o .desktop (o manifesto) de cada app bate com o PsitoApp', () {
    for (final app in registeredApps) {
      final appId = 'org.psito.${app.id}';
      final text = File('../apps/${app.id}/$appId.desktop').readAsStringSync();
      final rgb = (app.color.toARGB32() & 0xFFFFFF)
          .toRadixString(16)
          .padLeft(6, '0')
          .toUpperCase();
      expect(text, contains('Name=${app.name}\n'));
      // O nome traduzido do .desktop é o que o launcher e a dock mostram
      final pt = app.localizedName(const Locale('pt'));
      if (pt != app.name) expect(text, contains('Name[pt]=$pt\n'));
      // O código de campo (%f, %U) é de quem abre arquivos
      expect(
        text,
        matches(
          RegExp(
            '^Exec=/usr/lib/psito/apps/$appId/psito_${app.id}( %[fFuU])?\$',
            multiLine: true,
          ),
        ),
      );
      expect(text, contains('Icon=$appId\n'));
      expect(text, contains('StartupWMClass=$appId\n'));
      expect(text, contains('X-Psito-App=${app.id}\n'));
      expect(text, contains('X-Psito-Color=#$rgb\n'));
      expect(File('../apps/${app.id}/icon.svg').existsSync(), isTrue);
    }
  });

  test('as permissões são conhecidas, e settings só com canChangeSettings', () {
    const known = {
      'network',
      'audio',
      'settings',
      'files:home',
      'files:removable',
      'notifications',
    };
    final line = RegExp(r'^X-Psito-Permissions=(.*)$', multiLine: true);
    for (final app in registeredApps) {
      final text = File('../apps/${app.id}/org.psito.${app.id}.desktop')
          .readAsStringSync();
      final permissions = line
          .firstMatch(text)!
          .group(1)!
          .split(';')
          .where((p) => p.isNotEmpty)
          .toSet();
      expect(known.containsAll(permissions), isTrue, reason: app.id);
      expect(
        permissions.contains('settings'),
        app.canChangeSettings,
        reason: app.id,
      );
    }
  });

  test('o APPLICATION_ID de cada app é org.psito.<id>', () {
    for (final app in registeredApps) {
      final cmake = File('../apps/${app.id}/linux/CMakeLists.txt')
          .readAsStringSync();
      expect(cmake, contains('set(APPLICATION_ID "org.psito.${app.id}")'));
    }
  });
}
