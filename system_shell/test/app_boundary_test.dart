// Os apps só podem falar com o shell pelo psito_sdk: na fase 4 eles viram
// processos separados e qualquer import do shell quebraria essa fronteira.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/shell/app_registry.dart';

final _import = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

void main() {
  test('apps não importam o shell', () {
    final violations = <String>[];
    for (final file in Directory('lib/apps').listSync().whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      for (final match in _import.allMatches(file.readAsStringSync())) {
        final uri = match.group(1)!;
        if (uri.startsWith('../') || uri.startsWith('package:system_shell/')) {
          violations.add('${file.path}: $uri');
        }
      }
    }
    expect(violations, isEmpty);
  });

  test('ids dos apps são únicos', () {
    final ids = registeredApps.map((app) => app.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
