// Os apps (apps/<id>/) só falam com o shell pelo psito_sdk e pelo
// psito_runtime: cada um é um processo e um pacote à parte, e qualquer import
// do shell ou dos serviços quebraria essa fronteira.
import 'dart:io';

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

  test('o .desktop de cada app bate com o PsitoApp', () {
    for (final app in registeredApps) {
      final text = File('../apps/${app.id}/org.psito.${app.id}.desktop')
          .readAsStringSync();
      expect(text, contains('Name=${app.name}\n'));
      expect(
        text,
        contains('Exec=/opt/psito/apps/${app.id}/psito_${app.id}\n'),
      );
      expect(text, contains('StartupWMClass=org.psito.${app.id}\n'));
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
