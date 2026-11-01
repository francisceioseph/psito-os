// shell/lib/opener.dart
//
// Abrir arquivos: o app de cada um (o padrão do tipo, pelo psito_fs), o
// comando com os códigos de campo do Exec e o que o sandbox do app precisa
// montar para ele ver o arquivo. O org.psito.Launcher (launcher_bus.dart)
// chama daqui.
import 'package:psito_fs/psito_fs.dart';

import 'desktop_entries.dart';

/// Um app a abrir com os seus arquivos.
class OpenPlan {
  final DesktopEntry app;

  /// Os caminhos como o app vai ver (os de dentro do sandbox).
  final List<String> paths;

  /// Os comandos, um por instância (o `%f` abre uma por arquivo).
  final List<List<String>> commands;

  /// Os `--file` do sandbox: o caminho de fora e o de dentro.
  final List<(String, String)> files;

  const OpenPlan(this.app, this.paths, this.commands, this.files);
}

/// Nenhum app abre o arquivo.
class NoAppException implements Exception {
  final String path;

  const NoAppException(this.path);

  @override
  String toString() => 'NoAppException($path)';
}

class Opener {
  final Map<String, String> env;
  final MimeDatabase mime;

  /// O `psito-sandbox`, ou null sem o sandbox.
  final String? sandbox;

  /// Os apps instalados agora.
  final List<DesktopEntry> Function() apps;

  /// Lidos de novo a cada pedido: o usuário pode ter mudado o padrão.
  final MimeApps Function() mimeApps;

  int _nextDoc = 0;

  Opener({
    required this.env,
    required this.mime,
    required this.sandbox,
    required this.apps,
    MimeApps Function()? mimeApps,
  }) : mimeApps = mimeApps ?? (() => MimeApps.load(MimeApps.filesFor(env)));

  String get home => env['HOME'] ?? '/';
  String get runtimeDir => env['XDG_RUNTIME_DIR'] ?? '/run/user/1000';

  /// O `$HOME` privado de um app sem `files:home`.
  String dataDir(String appId) =>
      '${env['XDG_DATA_HOME'] ?? '$home/.local/share'}/psito/apps/$appId';

  DesktopEntry? entry(String id) {
    for (final app in apps()) {
      if (app.id == id) return app;
    }
    return null;
  }

  bool _sandboxed(DesktopEntry? app) => app != null && app.sandboxed(sandbox);

  /// O caminho de verdade de um caminho que o app [callerId] mandou, como
  /// ele vê no sandbox dele, ou null se ele não poderia ver esse caminho.
  /// Quem chama no barramento é o xdg-dbus-proxy do app, fora do sandbox,
  /// então o shell refaz a conta pelas permissões do manifesto.
  String? fromCaller(String? callerId, String path) {
    final normal = normalizePath(path);
    if (normal == null) return null;
    final caller = callerId == null ? null : entry(callerId);
    if (!_sandboxed(caller)) return normal;
    if (_systemPath(normal)) return normal;
    if (isWithin(home, normal) && !isWithin(runtimeDir, normal)) {
      if (caller!.permissions.contains('files:home')) return normal;
      final rest = normal.substring(home.length);
      return '${dataDir(caller.id)}$rest';
    }
    return null;
  }

  /// O `/usr` e o `/etc`, que todo sandbox vê como são.
  static bool _systemPath(String path) =>
      isWithin('/usr', path) || isWithin('/etc', path);

  /// Se o app vê [path] sem o shell montar nada.
  bool visibleTo(DesktopEntry app, String path) {
    if (!_sandboxed(app)) return true;
    if (_systemPath(path)) return true;
    return app.permissions.contains('files:home') &&
        isWithin(home, path) &&
        !isWithin(runtimeDir, path);
  }

  /// Os apps instalados com os tipos que eles abrem, os do Psito primeiro.
  Map<String, List<String>> _installed() {
    final all = apps();
    return {
      for (final app in [
        ...all.where((a) => a.psitoApp != null),
        ...all.where((a) => a.psitoApp == null),
      ])
        app.id: app.mimeTypes,
    };
  }

  /// Os apps que abrem o tipo, o padrão primeiro. Sem tipo (`''`), todos os
  /// que recebem arquivos (o "Outro…" do "Abrir com").
  List<DesktopEntry> appsFor(String mimeType) {
    if (mimeType.isEmpty) {
      return [
        for (final id in _installed().keys)
          if (entry(id) case final app? when app.acceptsFiles) app,
      ];
    }
    return [
      for (final id in mimeApps().appsFor(mimeType, _installed(), mime))
        ?entry(id),
    ];
  }

  /// Se o app abre todos os [paths] (o `MimeType=` do `.desktop`).
  bool accepts(String appId, List<String> paths) => paths.every(
    (path) => appsFor(mime.typeOf(path)).any((app) => app.id == appId),
  );

  /// Um app para cada arquivo: [withApp] ou o padrão do tipo. Lança
  /// [NoAppException] para o primeiro que nenhum app abre.
  List<OpenPlan> plan(List<String> paths, {String? withApp}) {
    final forced = withApp == null ? null : entry(withApp);
    if (withApp != null && forced == null) {
      throw NoAppException(paths.firstOrNull ?? withApp);
    }
    final byApp = <String, (DesktopEntry, List<String>)>{};
    for (final path in paths) {
      final app = forced ?? appsFor(mime.typeOf(path)).firstOrNull;
      if (app == null) throw NoAppException(path);
      final group = byApp[app.id] ??= (app, <String>[]);
      group.$2.add(path);
    }
    return [for (final (app, list) in byApp.values) _planFor(app, list)];
  }

  OpenPlan _planFor(DesktopEntry app, List<String> paths) {
    final inside = <String>[];
    final files = <(String, String)>[];
    for (final path in paths) {
      if (visibleTo(app, path)) {
        inside.add(path);
      } else {
        // Uma pasta por arquivo: dois com o mesmo nome não se cobrem
        final doc = '$runtimeDir/doc/${_nextDoc++}/${baseName(path)}';
        files.add((path, doc));
        inside.add(doc);
      }
    }
    return OpenPlan(app, inside, app.commandsFor(inside), files);
  }
}

/// O caminho absoluto sem `.`, `..` e `//`. Null se não for absoluto.
String? normalizePath(String path) {
  if (!path.startsWith('/')) return null;
  final out = <String>[];
  for (final part in path.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (out.isNotEmpty) out.removeLast();
    } else {
      out.add(part);
    }
  }
  return '/${out.join('/')}';
}
