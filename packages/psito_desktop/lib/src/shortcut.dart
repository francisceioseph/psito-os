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
