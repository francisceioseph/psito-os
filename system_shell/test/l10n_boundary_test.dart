// Os textos que quem usa lê moram nos .arb. Sem esta trava, cada funcionalidade
// nova traz os dela de volta para o código, e a tradução fica para sempre
// pela metade.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// O que é igual em qualquer idioma: nomes próprios e o nome de cada idioma.
const _allowed = {
  'Psito OS',
  'Hello, Psito',
  'Português',
  'English',
  'IPv4',
  'px',
};

/// Linguagem de quem programa, ou o que nunca chega à tela.
final _diagnostic = RegExp(
  r'debugPrint|🦜|print\(|Exception\(|Error\(|_mayChange|const from =|'
  r'Gerado pela ponte',
);

/// Um texto com acento, que no código só pode ser português.
final _accented = RegExp(
  r"""'[^']*(?:[À-ÖØ-öø-ÿ][A-Za-zÀ-ÖØ-öø-ÿ]|[A-Za-z][À-ÖØ-öø-ÿ])[^']*'""",
);

/// Um texto logo num lugar que vai para a tela.
final _visible = RegExp(
  r"""(?:\bText\(\s*|\b(?:tooltip|label|title|message|hintText|labelText|"""
  r"""action|body|helperText):\s*|DockMenuItem\(\s*)'([^']*[A-Za-zÀ-ÿ]{2}[^']*)'""",
);

final List<Directory> _projects = [
  Directory('../shell'),
  Directory('../lock'),
  Directory('../greeter'),
  Directory('.'),
  for (final parent in ['../packages', '../apps', '../examples'])
    ...Directory(parent).listSync().whereType<Directory>(),
];

Iterable<File> _sources(Directory project) sync* {
  final lib = Directory('${project.path}/lib');
  if (!lib.existsSync()) return;
  for (final file in lib.listSync(recursive: true).whereType<File>()) {
    if (file.path.endsWith('.dart') && !file.path.contains('/l10n/')) {
      yield file;
    }
  }
}

Map<String, Object?> _arb(File file) =>
    (jsonDecode(file.readAsStringSync()) as Map).cast();

Set<String> _placeholders(String message) => {
  for (final match in RegExp(
    r'(?<!=\d)(?<!other)\{(\w+)[,}]',
  ).allMatches(message))
    match.group(1)!,
};

void main() {
  test('nenhum texto para a tela fora dos .arb', () {
    final found = <String>[];
    for (final project in _projects) {
      for (final file in _sources(project)) {
        final text = file.readAsStringSync();
        final lines = text.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          if (_diagnostic.hasMatch(line)) continue;
          if (_accented.hasMatch(line) && !_allowed.any(line.contains)) {
            found.add('${file.path}:${i + 1}: $line');
          }
        }
        for (final match in _visible.allMatches(text)) {
          final literal = match
              .group(1)!
              .replaceAll(RegExp(r'\$\{[^}]*\}|\$\w+'), '')
              .trim();
          if (!RegExp('[A-Za-zÀ-ÿ]{2}').hasMatch(literal)) continue;
          if (_allowed.contains(literal)) continue;
          found.add('${file.path}: ${match.group(0)}');
        }
      }
    }
    expect(found.join('\n'), isEmpty);
  });

  test('todo idioma tem as mesmas mensagens, com os mesmos campos', () {
    var checked = 0;
    for (final project in _projects) {
      final dir = Directory('${project.path}/lib/l10n');
      if (!dir.existsSync()) continue;
      final arbs = dir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.arb'))
          .toList();
      final template = arbs.firstWhere((file) => file.path.endsWith('_en.arb'));
      final source = _arb(template);
      for (final file in arbs) {
        final other = _arb(file);
        bool message(String key) => !key.startsWith('@');
        expect(
          other.keys.where(message).toSet(),
          source.keys.where(message).toSet(),
          reason: file.path,
        );
        for (final key in source.keys.where(message)) {
          expect(
            _placeholders(other[key]! as String),
            _placeholders(source[key]! as String),
            reason: '${file.path}: $key',
          );
        }
        checked++;
      }
    }
    expect(checked, greaterThan(0));
  });

  // O gen-l10n faz do =1 o "one" do idioma, e em português o 0 também é "one":
  // sem o =0, uma pasta vazia diria "1 item", e um arquivo vazio, "1 byte".
  test('em português, um plural com =1 tem também o =0', () {
    for (final project in _projects) {
      final dir = Directory('${project.path}/lib/l10n');
      if (!dir.existsSync()) continue;
      for (final file in dir.listSync().whereType<File>()) {
        if (!file.path.endsWith('_pt.arb')) continue;
        for (final MapEntry(:key, :value) in _arb(file).entries) {
          if (value is! String || !value.contains('=1{')) continue;
          expect(value, contains('=0{'), reason: '${file.path}: $key');
        }
      }
    }
  });

  test('os apps do sistema têm os idiomas do sistema', () {
    for (final app in Directory('../apps').listSync().whereType<Directory>()) {
      final dir = Directory('${app.path}/lib/l10n');
      final locales = {
        for (final file in dir.listSync().whereType<File>())
          if (file.path.endsWith('.arb')) _arb(file)['@@locale'],
      };
      expect(locales, {'en', 'pt'}, reason: app.path);
    }
  });

  test('o que os .arb geram está em dia com eles', () {
    for (final project in _projects) {
      final dir = Directory('${project.path}/lib/l10n');
      if (!dir.existsSync()) continue;
      for (final arb in dir.listSync().whereType<File>()) {
        if (!arb.path.endsWith('_en.arb')) continue;
        final prefix = arb.path.replaceFirst('_en.arb', '');
        final generated = File('${prefix}_localizations_en.dart');
        for (final key in _arb(arb).keys) {
          if (key.startsWith('@')) continue;
          expect(
            generated.readAsStringSync(),
            contains(key),
            reason: 'rode o ./l10n.sh: ${arb.path}',
          );
        }
      }
    }
  });
}
