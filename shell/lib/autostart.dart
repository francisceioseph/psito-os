// shell/lib/autostart.dart
//
// O autostart do XDG (Desktop Application Autostart Specification): os
// `.desktop` de ~/.config/autostart e de /etc/xdg/autostart abrem no começo
// da sessão. O labwc só roda o script autostart dele, então quem roda estes
// é o shell. O "Abrir ao iniciar a sessão" da dock grava aqui.
import 'dart:io';

import 'desktop_entries.dart';

class Autostart {
  final Map<String, String> env;

  /// Se o programa do `TryExec` existe (um caminho ou um nome no `PATH`).
  final bool Function(String program) canExec;

  Autostart(this.env, {bool Function(String program)? canExec})
    : canExec = canExec ?? ((program) => _inPath(program, env));

  /// Os do usuário primeiro: ganham dos do sistema com o mesmo nome.
  List<String> get dirs {
    final home = env['HOME'] ?? '';
    final configDirs = (env['XDG_CONFIG_DIRS'] ?? '/etc/xdg')
        .split(':')
        .where((dir) => dir.isNotEmpty);
    return [
      '${env['XDG_CONFIG_HOME'] ?? '$home/.config'}/autostart',
      for (final dir in configDirs) '$dir/autostart',
    ];
  }

  /// O `XDG_CURRENT_DESKTOP`, para o `OnlyShowIn` e o `NotShowIn`.
  List<String> get desktops =>
      (env['XDG_CURRENT_DESKTOP'] ?? 'Psito').split(':');

  File userFile(String id) => File('${dirs.first}/$id.desktop');

  /// O arquivo que vale para [id]: o primeiro que existe, na ordem de [dirs].
  File? _effective(String id) {
    for (final dir in dirs) {
      final file = File('$dir/$id.desktop');
      if (file.existsSync()) return file;
    }
    return null;
  }

  /// Se o arquivo abre na sessão: `Hidden`, o `X-GNOME-Autostart-enabled`,
  /// os desktops e o `TryExec`.
  bool _runs(Map<String, String> fields) {
    if (fields['Hidden'] == 'true') return false;
    if (fields['X-GNOME-Autostart-enabled'] == 'false') return false;
    final only = DesktopEntry.list(fields['OnlyShowIn']);
    if (only.isNotEmpty && !only.any(desktops.contains)) return false;
    if (DesktopEntry.list(fields['NotShowIn']).any(desktops.contains)) {
      return false;
    }
    final tryExec = fields['TryExec'];
    return tryExec == null || canExec(tryExec);
  }

  /// Se [id] abre ao iniciar a sessão.
  bool enabled(String id) {
    final file = _effective(id);
    if (file == null) return false;
    try {
      return _runs(DesktopEntry.fields(file.readAsStringSync()));
    } on FileSystemException {
      return false;
    }
  }

  /// Liga com uma cópia do `.desktop` do app. Desliga apagando a cópia; um
  /// do sistema com o mesmo nome fica escondido por um `Hidden=true`.
  Future<void> set(DesktopEntry app, bool on) async {
    final file = userFile(app.id);
    final system = dirs
        .skip(1)
        .any((dir) => File('$dir/${app.id}.desktop').existsSync());
    if (!on && !system) {
      if (await file.exists()) await file.delete();
      return;
    }
    String? content;
    final source = on ? app.path : null;
    if (source != null) {
      try {
        content = await File(source).readAsString();
      } on FileSystemException {
        content = null;
      }
    }
    content ??= [
      '[Desktop Entry]',
      'Type=Application',
      'Name=${app.name}',
      'Exec=${app.command.join(' ')}',
      if (!on) 'Hidden=true',
    ].join('\n');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  /// Os que abrem na sessão, um por nome de arquivo.
  Future<List<DesktopEntry>> entries() async {
    final seen = <String>{};
    final result = <DesktopEntry>[];
    for (final path in dirs) {
      final dir = Directory(path);
      if (!await dir.exists()) continue;
      await for (final file in dir.list()) {
        if (file is! File || !file.path.endsWith('.desktop')) continue;
        final id = file.uri.pathSegments.last.replaceAll('.desktop', '');
        if (!seen.add(id)) continue;
        try {
          final content = await file.readAsString();
          if (!_runs(DesktopEntry.fields(content))) continue;
          final entry = DesktopEntry.parse(
            id,
            content,
            locale: env['LANG'],
            path: file.path,
            autostart: true,
          );
          if (entry != null) result.add(entry);
        } on FileSystemException {
          continue;
        }
      }
    }
    return result;
  }

  /// A marca de que a sessão já abriu o autostart: o shell reinicia (o
  /// `Restart` da unidade), e o autostart é uma vez por sessão. Guarda a
  /// data do socket do Wayland, que muda a cada subida do compositor.
  File get _marker =>
      File('${env['XDG_RUNTIME_DIR'] ?? '/tmp'}/psito/autostart-done');

  String _session() {
    final runtime = env['XDG_RUNTIME_DIR'];
    final display = env['WAYLAND_DISPLAY'];
    if (runtime == null || display == null) return '';
    try {
      final socket = File('$runtime/$display').statSync();
      return '$display ${socket.modified.microsecondsSinceEpoch}';
    } on FileSystemException {
      return display;
    }
  }

  /// Abre os do autostart, se esta sessão ainda não abriu. Devolve os que
  /// abriram.
  Future<List<String>> runOnce(
    Future<void> Function(DesktopEntry entry) launch,
  ) async {
    final session = _session();
    final marker = _marker;
    try {
      if (await marker.exists() && await marker.readAsString() == session) {
        return const [];
      }
      await marker.parent.create(recursive: true);
      await marker.writeAsString(session);
    } on FileSystemException {
      return const [];
    }
    final ran = <String>[];
    for (final entry in await entries()) {
      await launch(entry);
      ran.add(entry.id);
    }
    return ran;
  }

  static bool _inPath(String program, Map<String, String> env) {
    if (program.contains('/')) return File(program).existsSync();
    for (final dir in (env['PATH'] ?? '/usr/bin:/bin').split(':')) {
      if (dir.isNotEmpty && File('$dir/$program').existsSync()) return true;
    }
    return false;
  }
}
