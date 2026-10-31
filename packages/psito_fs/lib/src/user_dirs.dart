// packages/psito_fs/lib/src/user_dirs.dart
//
// As pastas do usuário do xdg-user-dirs (~/.config/user-dirs.dirs): Área de
// Trabalho, Documentos, Downloads, Imagens, Música e Vídeos, com o nome que
// o xdg-user-dirs-update deu no idioma da sessão.
import 'dart:io';

enum UserDir {
  desktop('DESKTOP', 'user-desktop'),
  documents('DOCUMENTS', 'folder-documents'),
  download('DOWNLOAD', 'folder-download'),
  pictures('PICTURES', 'folder-pictures'),
  music('MUSIC', 'folder-music'),
  videos('VIDEOS', 'folder-videos'),
  templates('TEMPLATES', 'folder-templates'),
  publicShare('PUBLICSHARE', 'folder-publicshare');

  /// O `XDG_<chave>_DIR`.
  final String key;

  /// O ícone no tema.
  final String icon;

  const UserDir(this.key, this.icon);
}

/// Lê o `user-dirs.dirs`. As pastas que apontam para o próprio home (o
/// xdg-user-dirs faz isso com as desligadas) ficam de fora.
Map<UserDir, String> loadUserDirs(Map<String, String> env) {
  final home = env['HOME'] ?? '';
  final config = env['XDG_CONFIG_HOME'] ?? '$home/.config';
  final String text;
  try {
    text = File('$config/user-dirs.dirs').readAsStringSync();
  } on FileSystemException {
    return const {};
  }
  return parseUserDirs(text, home);
}

Map<UserDir, String> parseUserDirs(String text, String home) {
  final values = <String, String>{};
  for (final m in RegExp(
    r'^\s*XDG_([A-Z]+)_DIR\s*=\s*"((?:[^"\\]|\\.)*)"',
    multiLine: true,
  ).allMatches(text)) {
    var path = m.group(2)!.replaceAllMapped(RegExp(r'\\(.)'), (e) => e[1]!);
    if (path.startsWith(r'$HOME')) path = '$home${path.substring(5)}';
    if (!path.startsWith('/')) continue;
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    values[m.group(1)!] = path;
  }
  return {
    for (final dir in UserDir.values)
      if (values[dir.key] case final path? when path != home) dir: path,
  };
}
