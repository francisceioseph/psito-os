// As cores moram na paleta do SDK (`context.palette`). Cada cor escrita num
// widget é um lugar a mais que o tema claro teria de achar depois.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _literal = RegExp(r'\bColors\.(?!transparent\b)\w+|\bColor\(0x');

/// A cor de cada app no manifesto, e o que precisa da cor antes do Flutter (a
/// moldura do labwc e o tema GTK, na ponte).
bool _exempt(String path, String line) =>
    line.contains('get color') ||
    line.trimLeft().startsWith('//') ||
    path.contains('/bridge/') ||
    path.contains('/l10n/');

void main() {
  test('nenhuma cor escrita fora da paleta', () {
    final found = <String>[];
    for (final root in [
      '../shell',
      '../lock',
      '.',
      for (final parent in ['../apps', '../examples'])
        ...Directory(parent)
            .listSync()
            .whereType<Directory>()
            .map((d) => d.path),
      '../packages/psito_files_ui',
      '../packages/psito_runtime',
    ]) {
      final lib = Directory('$root/lib');
      for (final file in lib.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (_literal.hasMatch(lines[i]) && !_exempt(file.path, lines[i])) {
            found.add('${file.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
    }
    expect(found.join('\n'), isEmpty);
  });
}
