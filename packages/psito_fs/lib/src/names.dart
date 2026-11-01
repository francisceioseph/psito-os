// packages/psito_fs/lib/src/names.dart
//
// Nomes e caminhos: o nome de um caminho, a extensão, os nomes livres
// ("foto 2.png", "foto copy.png") e a ordem natural ("2" antes de "10").
import 'dart:io';

/// O último pedaço do caminho (`/a/b.txt` → `b.txt`; `/` → `/`).
String baseName(String path) {
  var end = path.length;
  while (end > 1 && path[end - 1] == '/') {
    end--;
  }
  final trimmed = path.substring(0, end);
  if (trimmed == '/') return '/';
  return trimmed.substring(trimmed.lastIndexOf('/') + 1);
}

/// A pasta do caminho (`/a/b.txt` → `/a`; `/a` → `/`).
String dirName(String path) {
  final name = baseName(path);
  if (name == '/') return '/';
  final dir = path.substring(0, path.lastIndexOf(name));
  if (dir.length > 1 && dir.endsWith('/')) {
    return dir.substring(0, dir.length - 1);
  }
  return dir.isEmpty ? '.' : dir;
}

/// [dir] e [name] juntos, sem `//`.
String joinPath(String dir, String name) =>
    dir.endsWith('/') ? '$dir$name' : '$dir/$name';

/// Se [path] é [dir] ou está dentro dela.
bool isWithin(String dir, String path) {
  final base = dir.endsWith('/') ? dir : '$dir/';
  return path == dir || path.startsWith(base);
}

/// O nome sem a extensão e a extensão (com o ponto). Pastas e ocultos sem
/// outro ponto (`.bashrc`) não têm extensão; `.tar.gz` e as irmãs contam
/// inteiras.
(String, String) splitExtension(String name, {bool isDirectory = false}) {
  if (isDirectory) return (name, '');
  final lower = name.toLowerCase();
  for (final ext in const ['.tar.gz', '.tar.xz', '.tar.bz2', '.tar.zst']) {
    if (lower.endsWith(ext) && name.length > ext.length) {
      final cut = name.length - ext.length;
      return (name.substring(0, cut), name.substring(cut));
    }
  }
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return (name, '');
  return (name.substring(0, dot), name.substring(dot));
}

/// O primeiro nome livre em [dir] a partir de [name]: o próprio, depois
/// `nome 2.ext`, `nome 3.ext`… (o "manter os dois" do Finder).
String uniqueName(String dir, String name, {bool isDirectory = false}) {
  if (!_exists(joinPath(dir, name))) return name;
  final (stem, ext) = splitExtension(name, isDirectory: isDirectory);
  for (var n = 2; ; n++) {
    final candidate = '$stem $n$ext';
    if (!_exists(joinPath(dir, candidate))) return candidate;
  }
}

/// O nome de uma duplicata: `nome copy.ext`, depois `nome copy 2.ext`…, com
/// [copyWord] no idioma de quem usa.
String copyName(
  String dir,
  String name, {
  bool isDirectory = false,
  String copyWord = 'copy',
}) {
  final (stem, ext) = splitExtension(name, isDirectory: isDirectory);
  final first = '$stem $copyWord$ext';
  if (!_exists(joinPath(dir, first))) return first;
  for (var n = 2; ; n++) {
    final candidate = '$stem $copyWord $n$ext';
    if (!_exists(joinPath(dir, candidate))) return candidate;
  }
}

bool _exists(String path) =>
    FileSystemEntity.typeSync(path, followLinks: false) !=
    FileSystemEntityType.notFound;

/// Por que [name] não serve de nome de arquivo, ou null se serve.
FsErrorKind? invalidName(String name) {
  if (name.trim().isEmpty) return FsErrorKind.emptyName;
  if (name.contains('/')) return FsErrorKind.slashInName;
  if (name == '.' || name == '..') return FsErrorKind.reservedName;
  if (name.length > 255) return FsErrorKind.nameTooLong;
  return null;
}

/// Os erros que o `psito_fs` conhece: quem mostra é que traduz.
enum FsErrorKind {
  /// Um erro do sistema: [FsError.detail] tem a mensagem dele.
  system,
  emptyName,
  slashInName,
  reservedName,
  nameTooLong,
  nameTaken,
  intoItself,
  replacesParent,
}

/// A ordem dos nomes como o Finder: sem diferença de maiúsculas, e os
/// números pelo valor (`foto 2` antes de `foto 10`).
int naturalCompare(String a, String b) {
  final x = a.toLowerCase(), y = b.toLowerCase();
  var i = 0, j = 0;
  while (i < x.length && j < y.length) {
    final cx = x.codeUnitAt(i), cy = y.codeUnitAt(j);
    if (_isDigit(cx) && _isDigit(cy)) {
      var ei = i, ej = j;
      while (ei < x.length && _isDigit(x.codeUnitAt(ei))) {
        ei++;
      }
      while (ej < y.length && _isDigit(y.codeUnitAt(ej))) {
        ej++;
      }
      final nx = BigInt.parse(x.substring(i, ei));
      final ny = BigInt.parse(y.substring(j, ej));
      final byValue = nx.compareTo(ny);
      if (byValue != 0) return byValue;
      // "02" depois de "2"
      final byLength = (ei - i).compareTo(ej - j);
      if (byLength != 0) return byLength;
      i = ei;
      j = ej;
      continue;
    }
    if (cx != cy) return cx.compareTo(cy);
    i++;
    j++;
  }
  final byRest = (x.length - i).compareTo(y.length - j);
  return byRest != 0 ? byRest : a.compareTo(b);
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
