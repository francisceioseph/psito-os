// system_shell/lib/shell/clipboard_history.dart
//
// O histórico da área de transferência, sem UI: as últimas cópias de qualquer
// app, só na memória e por pouco tempo. Quem lê e oferece no sistema é o
// clipboard_keeper do shell.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:psito_runtime/psito_runtime.dart';
import 'package:system_shell/l10n/system_localizations.dart';

enum ClipKind { text, image, files, other }

/// Uma cópia, em todos os formatos que o app ofereceu.
@immutable
class ClipEntry {
  final Map<String, Uint8List> formats;
  final DateTime copiedAt;
  final ClipKind kind;

  /// Uma linha para mostrar.
  final String preview;

  /// A imagem, num [ClipKind.image].
  final Uint8List? image;

  /// Quantos arquivos, num [ClipKind.files].
  final int fileCount;

  const ClipEntry._(
    this.formats,
    this.copiedAt,
    this.kind,
    this.preview, {
    this.image,
    this.fileCount = 0,
  });

  /// A linha no idioma de quem usa.
  String text(SystemLocalizations l) => switch (kind) {
    ClipKind.image => l.clipImage,
    ClipKind.files when fileCount > 1 => l.clipFiles(fileCount, preview),
    _ => preview,
  };

  static const previewLength = 200;
  static const _textTypes = [
    'text/plain;charset=utf-8',
    'UTF8_STRING',
    'text/plain',
    'STRING',
    'TEXT',
  ];

  /// Null se não há nada para guardar: um texto em branco é o que fica quando
  /// alguém limpa a área de transferência.
  static ClipEntry? from(Map<String, Uint8List> formats, DateTime copiedAt) {
    String? read(String type) => switch (formats[type]) {
      final bytes? => utf8.decode(bytes, allowMalformed: true),
      null => null,
    };

    final gnome = read('x-special/gnome-copied-files');
    final uris = read('text/uri-list');
    final files =
        (gnome == null ? null : FileClip.parseGnome(gnome)) ??
        (uris == null ? null : FileClip.parseUris(uris));
    if (files != null) {
      return ClipEntry._(
        formats,
        copiedAt,
        ClipKind.files,
        _filesPreview(files.paths),
        fileCount: files.paths.length,
      );
    }
    for (final MapEntry(key: type, value: bytes) in formats.entries) {
      if (type.startsWith('image/') && bytes.isNotEmpty) {
        return ClipEntry._(formats, copiedAt, ClipKind.image, '', image: bytes);
      }
    }
    for (final type in _textTypes) {
      if (read(type) case final text?) {
        final line = text.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (line.isEmpty) return null;
        return ClipEntry._(
          formats,
          copiedAt,
          ClipKind.text,
          line.length > previewLength
              ? '${line.substring(0, previewLength)}…'
              : line,
        );
      }
    }
    final other = formats.keys.where((type) => formats[type]!.isNotEmpty);
    if (other.isEmpty) return null;
    return ClipEntry._(formats, copiedAt, ClipKind.other, other.first);
  }

  static String _filesPreview(List<String> paths) {
    final names = [for (final path in paths) path.split('/').last];
    return names.take(3).join(', ');
  }

  bool sameContent(ClipEntry other) {
    if (formats.length != other.formats.length) return false;
    for (final MapEntry(key: type, value: bytes) in formats.entries) {
      if (!listEquals(bytes, other.formats[type])) return false;
    }
    return true;
  }

  ClipEntry _at(DateTime when) => ClipEntry._(
    formats,
    when,
    kind,
    preview,
    image: image,
    fileCount: fileCount,
  );
}

class ClipboardHistory extends ChangeNotifier {
  static const limit = 5;
  static const lifetime = Duration(minutes: 15);

  ClipboardHistory({
    required this.now,
    required this.offer,
    required this.clearSystem,
  });

  final DateTime Function() now;

  /// Passa a oferecer estes formatos no sistema.
  final void Function(Map<String, Uint8List> formats) offer;

  /// Esvazia a área de transferência do sistema.
  final VoidCallback clearSystem;

  List<ClipEntry> _entries = const [];

  // O que está valendo agora: é o que volta quando o dono fecha. Fica fora do
  // prazo do histórico, porque um Ctrl+V sempre cola a última cópia
  Map<String, Uint8List>? _current;
  Timer? _timer;

  /// Os mais novos primeiro. A posição é a do atalho.
  List<ClipEntry> get entries => _entries;

  /// Um app copiou.
  void copied(Map<String, Uint8List> formats) {
    _current = formats;
    final entry = ClipEntry.from(formats, now());
    if (entry == null) return;
    _put(entry);
  }

  /// Um app copiou algo que não dá para guardar: a cópia de antes não pode
  /// voltar no lugar dela.
  void skipped() => _current = null;

  /// O dono fechou: a última cópia continua colando.
  void lost() {
    if (_current case final formats?) offer(formats);
  }

  /// Copia de novo o item [index]. Ele vira o primeiro e o prazo recomeça,
  /// porque é uma cópia nova. Devolve o item, ou null se a posição está vazia.
  ClipEntry? recopy(int index) {
    _purge();
    if (index < 0 || index >= _entries.length) return null;
    final entry = _entries[index]._at(now());
    _current = entry.formats;
    offer(entry.formats);
    _put(entry);
    return entry;
  }

  /// Esquece tudo, inclusive o que está copiado agora.
  void clear() {
    _current = null;
    _entries = const [];
    _timer?.cancel();
    clearSystem();
    notifyListeners();
  }

  void _put(ClipEntry entry) {
    _entries = [
      entry,
      for (final old in _entries)
        if (!old.sameContent(entry)) old,
    ].take(limit).toList();
    _purge();
    notifyListeners();
  }

  void _purge() {
    final time = now();
    final alive = [
      for (final entry in _entries)
        if (time.difference(entry.copiedAt) < lifetime) entry,
    ];
    final changed = alive.length != _entries.length;
    _entries = alive;
    _timer?.cancel();
    if (alive.isNotEmpty) {
      // Da lista saem sempre os mais velhos, que são os últimos
      final left = lifetime - time.difference(alive.last.copiedAt);
      _timer = Timer(left, () {
        _purge();
        notifyListeners();
      });
    }
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
