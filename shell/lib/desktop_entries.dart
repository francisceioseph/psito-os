// shell/lib/desktop_entries.dart
//
// Os apps de fora do Psito, lidos dos arquivos .desktop (Desktop Entry
// Specification), e como abrir cada um.
import 'dart:io';

class DesktopEntry {
  /// Nome do arquivo sem o `.desktop`. Bate com o `app_id` das janelas na
  /// maioria dos apps (firefox-esr, foot, org.gtk.Demo4).
  final String id;
  final String name;

  /// O `Exec` já sem os códigos de campo (`%u`, `%F`…), em argumentos.
  final List<String> command;

  /// Nome no tema de ícones ou caminho absoluto.
  final String? icon;
  final bool terminal;

  const DesktopEntry({
    required this.id,
    required this.name,
    required this.command,
    this.icon,
    this.terminal = false,
  });

  /// Lê o grupo `[Desktop Entry]`. Devolve null para o que não aparece no
  /// launcher: outros tipos, `NoDisplay`, `Hidden` ou sem `Exec`.
  static DesktopEntry? parse(String id, String content, {String? locale}) {
    final values = <String, String>{};
    var inEntry = false;
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('[')) {
        inEntry = line == '[Desktop Entry]';
        continue;
      }
      if (!inEntry) continue;
      final eq = line.indexOf('=');
      if (eq < 0) continue;
      values[line.substring(0, eq).trim()] = line.substring(eq + 1).trim();
    }

    if ((values['Type'] ?? 'Application') != 'Application') return null;
    if (values['NoDisplay'] == 'true' || values['Hidden'] == 'true') {
      return null;
    }
    final exec = values['Exec'];
    final name = _localized(values, 'Name', locale);
    if (exec == null || name == null) return null;
    final command = [
      for (final arg in splitExec(exec))
        if (!_fieldCode.hasMatch(arg)) arg.replaceAll('%%', '%'),
    ];
    if (command.isEmpty) return null;
    return DesktopEntry(
      id: id,
      name: name,
      command: command,
      icon: values['Icon'],
      terminal: values['Terminal'] == 'true',
    );
  }

  /// `Name[pt_BR]`, depois `Name[pt]`, depois `Name`.
  static String? _localized(
    Map<String, String> values,
    String key,
    String? locale,
  ) {
    if (locale != null) {
      final full = locale.split('.').first;
      final lang = full.split('_').first;
      for (final tag in [full, lang]) {
        final value = values['$key[$tag]'];
        if (value != null) return value;
      }
    }
    return values[key];
  }

  static final _fieldCode = RegExp(r'^%[fFuUdDnNickvm]$');

  /// Abre o app desligado do shell: matar o shell não fecha o app.
  Future<void> launch() async {
    final args = terminal ? ['foot', ...command] : command;
    await Process.start(
      args.first,
      args.sublist(1),
      mode: ProcessStartMode.detached,
    );
  }
}

/// Divide o `Exec` em argumentos, com as aspas duplas e o `\` da
/// especificação.
List<String> splitExec(String exec) {
  final args = <String>[];
  final current = StringBuffer();
  var quoted = false;
  var hasArg = false;
  for (var i = 0; i < exec.length; i++) {
    final char = exec[i];
    if (char == r'\' && i + 1 < exec.length) {
      current.write(exec[++i]);
      hasArg = true;
    } else if (char == '"') {
      quoted = !quoted;
      hasArg = true;
    } else if (char == ' ' && !quoted) {
      if (hasArg) args.add(current.toString());
      current.clear();
      hasArg = false;
    } else {
      current.write(char);
      hasArg = true;
    }
  }
  if (hasArg) args.add(current.toString());
  return args;
}

/// Pastas padrão dos `.desktop`. As do usuário vêm primeiro e ganham dos do
/// sistema com o mesmo id.
List<String> desktopEntryDirs(Map<String, String> env) {
  final home = env['HOME'] ?? '';
  final dataHome = env['XDG_DATA_HOME'] ?? '$home/.local/share';
  final dataDirs = (env['XDG_DATA_DIRS'] ?? '/usr/local/share:/usr/share')
      .split(':')
      .where((dir) => dir.isNotEmpty);
  return [
    '$dataHome/applications',
    for (final dir in dataDirs) '$dir/applications',
  ];
}

/// Todos os apps visíveis, em ordem alfabética.
Future<List<DesktopEntry>> loadDesktopEntries(
  List<String> dirs, {
  String? locale,
}) async {
  final byId = <String, DesktopEntry?>{};
  for (final path in dirs) {
    final dir = Directory(path);
    if (!await dir.exists()) continue;
    await for (final file in dir.list()) {
      if (file is! File || !file.path.endsWith('.desktop')) continue;
      final id = file.uri.pathSegments.last.replaceAll('.desktop', '');
      if (byId.containsKey(id)) continue;
      try {
        byId[id] = DesktopEntry.parse(
          id,
          await file.readAsString(),
          locale: locale,
        );
      } on FileSystemException {
        byId[id] = null;
      } on FormatException {
        byId[id] = null;
      }
    }
  }
  final entries = byId.values.whereType<DesktopEntry>().toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return entries;
}
