// packages/psito_fs/lib/src/mime_database.dart
//
// Os tipos MIME pelo shared-mime-info (/usr/share/mime): o tipo pelo nome
// (os globs2), os apelidos, de quem cada tipo é subtipo, os ícones e a
// descrição traduzida. Quando o nome não diz, o tipo vem do começo do
// arquivo (o package:mime e uma olhada se é texto).
import 'dart:convert';
import 'dart:io';

import 'package:mime/mime.dart' show MimeTypeResolver;

const directoryType = 'inode/directory';
const symlinkType = 'inode/symlink';
const textType = 'text/plain';
const binaryType = 'application/octet-stream';

class _Glob {
  final int weight;
  final String type;
  final String pattern;
  final bool caseSensitive;

  const _Glob(this.weight, this.type, this.pattern, this.caseSensitive);
}

/// O banco do shared-mime-info, lido uma vez. Só tem dados (mapas e listas),
/// então vai inteiro para um Isolate.
class MimeDatabase {
  /// Os globs sem curinga (`Makefile`), pelo nome.
  final Map<String, List<_Glob>> _literals;

  /// Os `*.ext`, pela extensão em minúsculas (sem o ponto).
  final Map<String, List<_Glob>> _extensions;

  /// Os outros (`*.[ch]`, `README*`).
  final List<_Glob> _others;
  final Map<String, String> _aliases;
  final Map<String, List<String>> _parents;
  final Map<String, String> _icons;
  final Map<String, String> _genericIcons;

  /// As pastas `mime/`, para a descrição de cada tipo.
  final List<String> dirs;
  final Map<String, String?> _descriptions = {};

  MimeDatabase._(
    this._literals,
    this._extensions,
    this._others,
    this._aliases,
    this._parents,
    this._icons,
    this._genericIcons,
    this.dirs,
  );

  /// Um banco vazio: tudo é texto ou binário, pelo conteúdo.
  factory MimeDatabase.empty() =>
      MimeDatabase._({}, {}, [], {}, {}, {}, {}, const []);

  /// As pastas `mime/` do `XDG_DATA_HOME` e do `XDG_DATA_DIRS`, a mais
  /// importante primeiro.
  static List<String> dirsFor(Map<String, String> env) {
    final home = env['HOME'] ?? '';
    return [
      '${env['XDG_DATA_HOME'] ?? '$home/.local/share'}/mime',
      for (final dir
          in (env['XDG_DATA_DIRS'] ?? '/usr/local/share:/usr/share').split(':'))
        if (dir.isNotEmpty) '$dir/mime',
    ];
  }

  static MimeDatabase load(List<String> dirs) {
    final literals = <String, List<_Glob>>{};
    final extensions = <String, List<_Glob>>{};
    final others = <_Glob>[];
    final aliases = <String, String>{};
    final parents = <String, List<String>>{};
    final icons = <String, String>{};
    final genericIcons = <String, String>{};
    // Do menos para o mais importante: o último ganha
    for (final dir in dirs.reversed) {
      for (final line in _lines('$dir/globs2')) {
        final parts = line.split(':');
        if (parts.length < 3) continue;
        final weight = int.tryParse(parts[0]) ?? 50;
        final type = parts[1];
        final pattern = parts[2];
        final cs = parts.length > 3 && parts[3].split(',').contains('cs');
        final glob = _Glob(weight, type, pattern, cs);
        final ext = RegExp(r'^\*\.([^*?\[\]]+)$').firstMatch(pattern);
        if (ext != null) {
          (extensions[ext.group(1)!.toLowerCase()] ??= []).add(glob);
        } else if (!pattern.contains(RegExp(r'[*?\[]'))) {
          (literals[cs ? pattern : pattern.toLowerCase()] ??= []).add(glob);
        } else {
          others.add(glob);
        }
      }
      for (final line in _lines('$dir/aliases')) {
        final [alias, type] = _pair(line, ' ') ?? const ['', ''];
        if (alias.isNotEmpty) aliases[alias] = type;
      }
      for (final line in _lines('$dir/subclasses')) {
        final [type, parent] = _pair(line, ' ') ?? const ['', ''];
        if (type.isNotEmpty) (parents[type] ??= []).add(parent);
      }
      for (final line in _lines('$dir/icons')) {
        final [type, icon] = _pair(line, ':') ?? const ['', ''];
        if (type.isNotEmpty) icons[type] = icon;
      }
      for (final line in _lines('$dir/generic-icons')) {
        final [type, icon] = _pair(line, ':') ?? const ['', ''];
        if (type.isNotEmpty) genericIcons[type] = icon;
      }
    }
    return MimeDatabase._(
      literals,
      extensions,
      others,
      aliases,
      parents,
      icons,
      genericIcons,
      dirs,
    );
  }

  static Iterable<String> _lines(String path) {
    try {
      return File(path)
          .readAsLinesSync()
          .where((line) => line.isNotEmpty && !line.startsWith('#'));
    } on FileSystemException {
      return const [];
    }
  }

  static List<String>? _pair(String line, String separator) {
    final cut = line.indexOf(separator);
    if (cut <= 0) return null;
    return [line.substring(0, cut), line.substring(cut + 1)];
  }

  /// O tipo canônico (sem apelido).
  String canonical(String type) => _aliases[type] ?? type;

  /// O tipo pelo nome do arquivo, ou null se nenhum glob bate. Entre os que
  /// batem, o de maior peso e, empatados, o glob mais longo (a
  /// especificação).
  String? typeForName(String name) {
    final lower = name.toLowerCase();
    final found = <_Glob>[
      ...?_literals[name],
      if (lower != name) ...?_literals[lower]?.where((g) => !g.caseSensitive),
    ];
    if (found.isEmpty) {
      // Da extensão mais longa (`tar.gz`) para a mais curta (`gz`)
      for (var dot = name.indexOf('.'); dot >= 0;) {
        final ext = lower.substring(dot + 1);
        for (final glob in _extensions[ext] ?? const <_Glob>[]) {
          if (!glob.caseSensitive || name.endsWith(glob.pattern.substring(1))) {
            found.add(glob);
          }
        }
        if (found.isNotEmpty) break;
        dot = name.indexOf('.', dot + 1);
      }
    }
    for (final glob in _others) {
      if (_globRegExp(glob).hasMatch(glob.caseSensitive ? name : lower)) {
        found.add(glob);
      }
    }
    if (found.isEmpty) return null;
    found.sort((a, b) {
      final byWeight = b.weight.compareTo(a.weight);
      return byWeight != 0
          ? byWeight
          : b.pattern.length.compareTo(a.pattern.length);
    });
    return canonical(found.first.type);
  }

  static final _regExps = <String, RegExp>{};

  static RegExp _globRegExp(_Glob glob) =>
      _regExps.putIfAbsent(glob.pattern, () {
        final out = StringBuffer('^');
        final pattern = glob.caseSensitive
            ? glob.pattern
            : glob.pattern.toLowerCase();
        for (var i = 0; i < pattern.length; i++) {
          final c = pattern[i];
          switch (c) {
            case '*':
              out.write('.*');
            case '?':
              out.write('.');
            case '[':
              final end = pattern.indexOf(']', i + 1);
              if (end < 0) {
                out.write(r'\[');
              } else {
                out.write(
                  '[${pattern.substring(i + 1, end).replaceAll(r'\', r'\\')}]',
                );
                i = end;
              }
            default:
              out.write(RegExp.escape(c));
          }
        }
        out.write(r'$');
        return RegExp(out.toString());
      });

  static final _sniffer = MimeTypeResolver();

  /// O tipo pelo começo do conteúdo ([header], uns 512 bytes): o
  /// package:mime, o ELF, e por fim texto (sem NUL e em UTF-8) ou binário.
  /// Um arquivo vazio conta como texto, para abrir num editor.
  String typeForContent(List<int> header) {
    if (header.isEmpty) return textType;
    if (header.length >= 4 &&
        header[0] == 0x7f &&
        header[1] == 0x45 &&
        header[2] == 0x4c &&
        header[3] == 0x46) {
      return 'application/x-executable';
    }
    final sniffed = _sniffer.lookup('', headerBytes: header);
    if (sniffed != null) return canonical(sniffed);
    if (header.contains(0)) return binaryType;
    try {
      // O último caractere pode ter sido cortado no meio
      utf8.decode(header.sublist(0, header.length - _cut(header)));
      return textType;
    } on FormatException {
      return binaryType;
    }
  }

  /// Quantos bytes do fim são um caractere UTF-8 incompleto.
  static int _cut(List<int> bytes) {
    for (var back = 1; back <= 3 && back <= bytes.length; back++) {
      final b = bytes[bytes.length - back];
      if (b & 0xC0 != 0x80) {
        final need = b >= 0xF0
            ? 4
            : b >= 0xE0
            ? 3
            : b >= 0xC0
            ? 2
            : 1;
        return need > back ? back : 0;
      }
    }
    return 0;
  }

  /// O tipo de um arquivo: pelo nome e, se não der, pelo conteúdo. Pastas
  /// são `inode/directory`.
  String typeOf(String path, {bool? isDirectory}) {
    final dir = isDirectory ?? FileSystemEntity.isDirectorySync(path);
    if (dir) return directoryType;
    final name = path.substring(path.lastIndexOf('/') + 1);
    final byName = typeForName(name);
    if (byName != null) return byName;
    try {
      final file = File(path).openSync();
      try {
        return typeForContent(file.readSync(512));
      } finally {
        file.closeSync();
      }
    } on FileSystemException {
      return binaryType;
    }
  }

  /// De quem o tipo é subtipo, do mais perto para o mais longe: os
  /// `subclasses`, o `text/plain` de todo `text/*` e o
  /// `application/octet-stream` de todo arquivo.
  List<String> parentsOf(String type) {
    final out = <String>[];
    final queue = [canonical(type)];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final parent in _parents[current] ?? const <String>[]) {
        final canon = canonical(parent);
        if (canon != type && !out.contains(canon)) {
          out.add(canon);
          queue.add(canon);
        }
      }
    }
    if (type.startsWith('text/') &&
        type != textType &&
        !out.contains(textType)) {
      out.add(textType);
    }
    if (!type.startsWith('inode/') &&
        type != binaryType &&
        !out.contains(binaryType)) {
      out.add(binaryType);
    }
    return out;
  }

  /// Se [type] é [other] ou um subtipo dele.
  bool isA(String type, String other) =>
      canonical(type) == canonical(other) ||
      parentsOf(type).contains(canonical(other));

  /// Os nomes de ícone do tema para o tipo, do mais exato para o mais
  /// genérico (`text-x-python`, `text-x-script`, `text-x-generic`).
  List<String> iconNames(String type) {
    final canon = canonical(type);
    final media = canon.split('/').first;
    final names = <String>[
      ?_icons[canon],
      if (canon == directoryType) 'folder',
      canon.replaceAll('/', '-'),
      ?_genericIcons[canon],
      for (final parent in parentsOf(canon))
        if (parent != binaryType) ?_genericIcons[parent],
      '$media-x-generic',
      if (media != 'text') 'application-x-generic',
      'text-x-generic',
    ];
    return [
      for (final (i, name) in names.indexed)
        if (names.indexOf(name) == i) name,
    ];
  }

  /// A descrição do tipo no idioma de [locale] (`pt_BR.UTF-8`), pelo
  /// `<tipo>.xml` do shared-mime-info: "Documento de texto simples".
  String description(String type, {String? locale}) {
    final canon = canonical(type);
    final key = '$canon|$locale';
    return _descriptions.putIfAbsent(
          key,
          () => _readDescription(canon, locale),
        ) ??
        canon;
  }

  String? _readDescription(String type, String? locale) {
    for (final dir in dirs) {
      final String xml;
      try {
        xml = File('$dir/$type.xml').readAsStringSync();
      } on FileSystemException {
        continue;
      }
      final comments = {
        for (final m in RegExp(
          r'<comment(?:\s+xml:lang="([^"]+)")?\s*>([^<]*)</comment>',
        ).allMatches(xml))
          m.group(1) ?? '': _unescapeXml(m.group(2)!),
      };
      if (locale != null) {
        final full = locale.split('.').first;
        final lang = full.split('_').first;
        for (final tag in [full, lang]) {
          if (comments[tag] case final text?) return text;
        }
      }
      if (comments[''] case final text?) return text;
    }
    return null;
  }

  static String _unescapeXml(String text) => text
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}
