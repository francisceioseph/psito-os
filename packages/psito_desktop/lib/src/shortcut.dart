// packages/psito_desktop/lib/src/shortcut.dart
//
// Os atalhos de programas: os `.desktop` da pasta da mesa. Quem está em
// outra pasta só passou por ela, e um arquivo qualquer pode ter esse nome,
// então um atalho só abre direto se for confiável.
import 'package:psito_fs/psito_fs.dart';

bool isDeskShortcut(FsEntry entry) =>
    entry.kind == FsKind.file && entry.name.endsWith('.desktop');

/// Executável e sem escrita para os outros: copiar não dá o `+x`, e os que a
/// própria mesa cria já nascem com ele.
bool deskShortcutTrusted(FsEntry entry) =>
    entry.executable && entry.mode & 0x2 == 0; // 0o002

/// O texto do `.desktop` com o nome [name]: o `Name=` do grupo principal muda
/// e os traduzidos saem, porque valeriam mais que ele.
String renamedDeskShortcut(String text, String name) {
  final out = <String>[];
  var main = false;
  var done = false;
  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('[')) {
      if (main && !done) {
        out.add('Name=$name');
        done = true;
      }
      main = trimmed == '[Desktop Entry]';
    } else if (main && RegExp(r'^Name(\[[^\]]*\])?\s*=').hasMatch(trimmed)) {
      if (!done) {
        out.add('Name=$name');
        done = true;
      }
      continue;
    }
    out.add(line);
  }
  if (main && !done) out.add('Name=$name');
  return out.join('\n');
}
