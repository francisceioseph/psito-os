// packages/psito_fs/lib/src/mime_apps.dart
//
// Os apps de cada tipo pela especificação "Association between MIME types
// and applications" do freedesktop: os mimeapps.list (o padrão, os
// acrescentados e os tirados, do usuário ao sistema, com os da sessão
// `psito-mimeapps.list` antes) e o `MimeType=` dos .desktop instalados.
import 'dart:io';

import 'mime_database.dart';

class _MimeAppsFile {
  final Map<String, List<String>> defaults;
  final Map<String, List<String>> added;
  final Map<String, List<String>> removed;

  const _MimeAppsFile(this.defaults, this.added, this.removed);
}

class MimeApps {
  /// Do mais importante para o menos.
  final List<_MimeAppsFile> _files;

  MimeApps._(this._files);

  factory MimeApps.empty() => MimeApps._(const []);

  /// Os `mimeapps.list` na ordem da especificação, com os da sessão
  /// (`<desktop>-mimeapps.list`, do `XDG_CURRENT_DESKTOP`) antes de cada um.
  static List<String> filesFor(Map<String, String> env) {
    final home = env['HOME'] ?? '';
    final desktops = [
      for (final d in (env['XDG_CURRENT_DESKTOP'] ?? '').split(':'))
        if (d.isNotEmpty) d.toLowerCase(),
    ];
    final configDirs = [
      env['XDG_CONFIG_HOME'] ?? '$home/.config',
      ...(env['XDG_CONFIG_DIRS'] ?? '/etc/xdg')
          .split(':')
          .where((d) => d.isNotEmpty),
    ];
    final dataDirs = [
      env['XDG_DATA_HOME'] ?? '$home/.local/share',
      ...(env['XDG_DATA_DIRS'] ?? '/usr/local/share:/usr/share')
          .split(':')
          .where((d) => d.isNotEmpty),
    ];
    return [
      for (final dir in [
        ...configDirs,
        for (final d in dataDirs) '$d/applications',
      ]) ...[
        for (final desktop in desktops) '$dir/$desktop-mimeapps.list',
        '$dir/mimeapps.list',
      ],
    ];
  }

  /// O arquivo em que o usuário grava o padrão.
  static String userFile(Map<String, String> env) =>
      '${env['XDG_CONFIG_HOME'] ?? '${env['HOME'] ?? ''}/.config'}/mimeapps.list';

  static MimeApps load(List<String> paths) => MimeApps._([
    for (final path in paths)
      if (_read(path) case final text?) _parse(text),
  ]);

  static String? _read(String path) {
    try {
      return File(path).readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

  static _MimeAppsFile _parse(String text) {
    final sections = <String, Map<String, List<String>>>{};
    Map<String, List<String>>? current;
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('[')) {
        current = sections[line] ??= {};
        continue;
      }
      final eq = line.indexOf('=');
      if (current == null || eq <= 0) continue;
      current[line.substring(0, eq).trim()] = [
        for (final id in line.substring(eq + 1).split(';'))
          if (id.trim().isNotEmpty) _id(id.trim()),
      ];
    }
    return _MimeAppsFile(
      sections['[Default Applications]'] ?? const {},
      sections['[Added Associations]'] ?? const {},
      sections['[Removed Associations]'] ?? const {},
    );
  }

  /// O id do `.desktop` sem a extensão, como o shell guarda.
  static String _id(String desktopFile) => desktopFile.endsWith('.desktop')
      ? desktopFile.substring(0, desktopFile.length - 8)
      : desktopFile;

  /// Os apps que abrem [type], o padrão primeiro. [installed] diz, para cada
  /// app instalado (pelo id do `.desktop`), os tipos do `MimeType=` dele, na
  /// ordem em que o shell prefere (os do Psito primeiro). Os apps dos tipos
  /// de que [type] é subtipo vêm depois (um editor de texto abre um script).
  List<String> appsFor(
    String type,
    Map<String, List<String>> installed,
    MimeDatabase mime,
  ) {
    final out = <String>[];
    void add(String id, Set<String> removed) {
      if (installed.containsKey(id) &&
          !removed.contains(id) &&
          !out.contains(id)) {
        out.add(id);
      }
    }

    for (final t in [mime.canonical(type), ...mime.parentsOf(type)]) {
      // Um tirado num arquivo vale para os menos importantes que ele
      final removed = <String>{};
      for (final file in _files) {
        for (final id in file.defaults[t] ?? const <String>[]) {
          add(id, removed);
        }
        removed.addAll(file.removed[t] ?? const []);
      }
      removed.clear();
      for (final file in _files) {
        for (final id in file.added[t] ?? const <String>[]) {
          add(id, removed);
        }
        removed.addAll(file.removed[t] ?? const []);
      }
      for (final MapEntry(key: id, value: types) in installed.entries) {
        if (types.map(mime.canonical).contains(t)) add(id, removed);
      }
    }
    return out;
  }

  String? defaultFor(
    String type,
    Map<String, List<String>> installed,
    MimeDatabase mime,
  ) {
    final apps = appsFor(type, installed, mime);
    return apps.isEmpty ? null : apps.first;
  }

  /// Grava [desktopId] como o padrão de [type] no `mimeapps.list` do
  /// usuário, mantendo o resto do arquivo.
  static Future<void> setDefault(
    String path,
    String type,
    String desktopId,
  ) async {
    final file = File(path);
    final text = await file.exists() ? await file.readAsString() : '';
    await file.parent.create(recursive: true);
    await file.writeAsString(withDefault(text, type, desktopId), flush: true);
  }

  /// O texto de um `mimeapps.list` com o padrão de [type] trocado.
  static String withDefault(String text, String type, String desktopId) {
    const group = '[Default Applications]';
    final value = '$type=$desktopId.desktop';
    final lines = text.isEmpty ? <String>[] : text.split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    var start = lines.indexWhere((l) => l.trim() == group);
    if (start < 0) {
      if (lines.isNotEmpty) lines.add('');
      lines.addAll([group, value]);
      return '${lines.join('\n')}\n';
    }
    var end = start + 1;
    while (end < lines.length && !lines[end].trim().startsWith('[')) {
      end++;
    }
    final existing = lines.indexWhere(
      (l) => l.trim().startsWith('$type='),
      start + 1,
    );
    if (existing >= 0 && existing < end) {
      lines[existing] = value;
    } else {
      // Antes das linhas em branco do fim da seção
      var at = end;
      while (at > start + 1 && lines[at - 1].trim().isEmpty) {
        at--;
      }
      lines.insert(at, value);
    }
    return '${lines.join('\n')}\n';
  }
}
