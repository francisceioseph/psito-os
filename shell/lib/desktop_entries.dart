// shell/lib/desktop_entries.dart
//
// Os apps instalados, lidos dos arquivos .desktop (Desktop Entry
// Specification), e como abrir cada um. O .desktop de um app do Psito é
// também o manifesto dele: as chaves X-Psito-* dizem o id curto, a cor e as
// permissões.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

class DesktopEntry {
  /// Nome do arquivo sem o `.desktop`. Bate com o `app_id` das janelas na
  /// maioria dos apps (firefox-esr, foot, org.gtk.Demo4).
  final String id;
  final String name;

  /// O `Exec` já sem os códigos de campo (`%u`, `%F`…), em argumentos.
  final List<String> command;

  /// O `Exec` em argumentos, com os códigos de campo, para abrir arquivos
  /// ([commandsFor]).
  final List<String> exec;

  /// O `MimeType=`: os tipos que o app abre.
  final List<String> mimeTypes;

  /// Nome no tema de ícones ou caminho absoluto.
  final String? icon;
  final bool terminal;

  /// O `X-Psito-App`: o id curto do app do Psito (o `PsitoApp.id`). Null nos
  /// apps de fora.
  final String? psitoApp;

  /// O `X-Psito-Color` (`#RRGGBB`) em ARGB.
  final int? color;

  /// O `X-Psito-Permissions`: `network`, `settings`, `files:home`,
  /// `notifications`.
  final List<String> permissions;

  /// O arquivo `.desktop` de onde veio.
  final String? path;

  const DesktopEntry({
    required this.id,
    required this.name,
    required this.command,
    List<String>? exec,
    this.mimeTypes = const [],
    this.icon,
    this.terminal = false,
    this.psitoApp,
    this.color,
    this.permissions = const [],
    this.path,
  }) : exec = exec ?? command;

  /// As chaves do grupo `[Desktop Entry]`.
  static Map<String, String> fields(String content) {
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
    return values;
  }

  /// Lê o grupo `[Desktop Entry]`. Devolve null para o que não aparece no
  /// launcher: outros tipos, `NoDisplay`, `Hidden` ou sem `Exec`. No
  /// [autostart], o `NoDisplay` vale (os do autostart costumam ter).
  static DesktopEntry? parse(
    String id,
    String content, {
    String? locale,
    String? path,
    bool autostart = false,
  }) {
    final values = fields(content);
    if ((values['Type'] ?? 'Application') != 'Application') return null;
    if ((!autostart && values['NoDisplay'] == 'true') ||
        values['Hidden'] == 'true') {
      return null;
    }
    final exec = values['Exec'];
    final name = _localized(values, 'Name', locale);
    if (exec == null || name == null) return null;
    final args = splitExec(exec);
    final command = [
      for (final arg in args)
        if (!_fieldCode.hasMatch(arg)) arg.replaceAll('%%', '%'),
    ];
    if (command.isEmpty) return null;
    return DesktopEntry(
      id: id,
      name: name,
      command: command,
      exec: args,
      mimeTypes: _list(values['MimeType']),
      icon: values['Icon'],
      terminal: values['Terminal'] == 'true',
      psitoApp: values['X-Psito-App'],
      color: _color(values['X-Psito-Color']),
      permissions: _list(values['X-Psito-Permissions']),
      path: path,
    );
  }

  /// Uma lista separada por `;` (`MimeType`, `OnlyShowIn`).
  static List<String> list(String? value) => _list(value);

  static List<String> _list(String? value) => [
    for (final item in (value ?? '').split(';'))
      if (item.trim().isNotEmpty) item.trim(),
  ];

  static final _hexColor = RegExp(r'^#([0-9a-fA-F]{6})$');

  static int? _color(String? value) {
    final match = _hexColor.firstMatch(value ?? '');
    if (match == null) return null;
    return 0xFF000000 | int.parse(match.group(1)!, radix: 16);
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

  /// Se o `Exec` recebe arquivos (`%f`, `%F`, `%u` ou `%U`).
  bool get acceptsFiles => exec.any((arg) => RegExp('%[fFuU]').hasMatch(arg));

  /// Os comandos que abrem [paths], pelos códigos de campo do `Exec`: um só
  /// com `%F` ou `%U` (todos de uma vez), um por arquivo com `%f` ou `%u`.
  /// Sem código, o app não recebe arquivos e abre uma vez, sozinho. Os `%u`
  /// e `%U` levam a URL `file://`.
  List<List<String>> commandsFor(List<String> paths) {
    if (paths.isEmpty) return [command];
    String uri(String path) => Uri.file(path).toString();
    final many = exec.contains('%F') || exec.contains('%U');
    final one = exec.any((arg) => arg.contains('%f') || arg.contains('%u'));
    if (!many && !one) return [command];
    List<String> expand(List<String> files) => [
      for (final arg in exec)
        if (arg == '%F')
          ...files
        else if (arg == '%U')
          ...files.map(uri)
        else if (!_fieldCode.hasMatch(arg) ||
            (!many && (arg == '%f' || arg == '%u')))
          arg
              .replaceAll('%f', files.first)
              .replaceAll('%u', uri(files.first))
              .replaceAll('%%', '%'),
    ];
    return many
        ? [expand(paths)]
        : [
            for (final p in paths) expand([p]),
          ];
  }

  /// Abre o app num cgroup próprio (uma unidade `.scope` do systemd do
  /// usuário): se o shell cair, o systemd não leva o app junto, e o log do
  /// app sai separado no journal. Sem o systemd-run, abre direto. Um app do
  /// Psito abre no [sandbox] (o `psito-sandbox`), se for dado.
  /// [command] troca o comando do `.desktop` (o de [commandsFor]), e
  /// [files] são os arquivos que o sandbox monta para o app (o caminho de
  /// fora e o de dentro).
  Future<void> launch({
    String? sandbox,
    List<String>? command,
    List<(String, String)> files = const [],
  }) async {
    final args = launchCommand(
      random: _random.nextInt(1 << 32),
      sandbox: sandbox,
      command: command,
      files: files,
    );
    try {
      await Process.start(
        args.first,
        args.sublist(1),
        mode: ProcessStartMode.detached,
      );
    } on ProcessException {
      final direct = args.sublist(args.indexOf('--') + 1);
      await Process.start(
        direct.first,
        direct.sublist(1),
        mode: ProcessStartMode.detached,
      );
    }
  }

  static final _random = Random();

  /// O `systemd-run` que abre o app. A unidade segue o nome da
  /// especificação do XDG (`app-<launcher>-<id>-<aleatório>.scope`), pelo
  /// qual o xdg-desktop-portal reconhece apps sem Flatpak. Os apps do Psito
  /// passam pelo [sandbox] com as permissões do manifesto; os de fora, não.
  /// O log fica em `journalctl --user -u <unidade>`.
  List<String> launchCommand({
    required int random,
    String? sandbox,
    List<String>? command,
    List<(String, String)> files = const [],
  }) => [
    'systemd-run',
    '--user',
    '--scope',
    '--collect',
    '--quiet',
    '--unit=${unitName(id, random)}',
    '--',
    // A saída do app (e do sandbox) vai para o journal, na unidade dele
    'systemd-cat',
    '--identifier=$id',
    if (sandbox != null && psitoApp != null) ...[
      sandbox,
      '--app',
      id,
      '--permissions',
      permissions.join(';'),
      for (final (outside, inside) in files) ...['--file', outside, inside],
      '--',
    ],
    if (terminal) 'foot',
    ...(command ?? this.command),
  ];

  /// Se o app roda no sandbox (um app do Psito, com o sandbox ligado).
  bool sandboxed(String? sandbox) => sandbox != null && psitoApp != null;
}

/// `app-psito-<id>-<aleatório>.scope`, com o id escapado como no
/// `systemd-escape` (o `-` vira `\x2d`).
String unitName(String id, int random) =>
    'app-psito-${systemdEscape(id)}-${random.toRadixString(16)}.scope';

/// O id do app dono de um processo, pelo `/proc/<pid>/cgroup`: a unidade
/// `app-psito-<id>-<aleatório>.scope` de [unitName]. Null fora de um app.
String? appIdFromCgroup(String cgroup) {
  final match = RegExp(
    r'/app-psito-(.+)-[0-9a-f]+\.scope(?:/|$)',
    multiLine: true,
  ).firstMatch(cgroup);
  if (match == null) return null;
  return systemdUnescape(match.group(1)!);
}

/// O inverso de [systemdEscape].
String systemdUnescape(String text) {
  final bytes = <int>[];
  for (var i = 0; i < text.length; i++) {
    if (text.startsWith(r'\x', i) && i + 3 < text.length) {
      final byte = int.tryParse(text.substring(i + 2, i + 4), radix: 16);
      if (byte != null) {
        bytes.add(byte);
        i += 3;
        continue;
      }
    }
    bytes.addAll(utf8.encode(text[i]));
  }
  return utf8.decode(bytes, allowMalformed: true);
}

/// O escape do `systemd-escape`: fora de `[A-Za-z0-9:_.]` (e o `.` no
/// começo) vira `\xNN`.
String systemdEscape(String text) {
  final out = StringBuffer();
  final bytes = utf8.encode(text);
  for (var i = 0; i < bytes.length; i++) {
    final c = bytes[i];
    final plain =
        (c >= 0x30 && c <= 0x39) ||
        (c >= 0x41 && c <= 0x5a) ||
        (c >= 0x61 && c <= 0x7a) ||
        c == 0x3a ||
        c == 0x5f ||
        (c == 0x2e && i > 0);
    out.write(
      plain
          ? String.fromCharCode(c)
          : '\\x${c.toRadixString(16).padLeft(2, '0')}',
    );
  }
  return out.toString();
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
          path: file.path,
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
