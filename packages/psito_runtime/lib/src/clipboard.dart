// packages/psito_runtime/lib/src/clipboard.dart
//
// A área de transferência de arquivos, entre processos, pelo canal
// psito/clipboard (o lado C é o linux/psito_clipboard.cc). Os formatos são os
// do Nautilus: x-special/gnome-copied-files (com copy ou cut), text/uri-list
// e os caminhos como texto, para colar num terminal.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dnd.dart' show filePaths;

/// Arquivos copiados ou recortados.
@immutable
class FileClip {
  final List<String> paths;
  final bool cut;

  const FileClip(this.paths, {this.cut = false});

  /// O `x-special/gnome-copied-files`: a ação e uma URI por linha. Null sem
  /// nenhum arquivo.
  static FileClip? parseGnome(String text) {
    final lines = const LineSplitter().convert(text);
    if (lines.length < 2 || !const {'copy', 'cut'}.contains(lines.first)) {
      return null;
    }
    final paths = filePaths(lines.skip(1));
    return paths.isEmpty ? null : FileClip(paths, cut: lines.first == 'cut');
  }

  /// O `text/uri-list`, em que as linhas com `#` são comentários.
  static FileClip? parseUris(String text) {
    final paths = filePaths(
      const LineSplitter().convert(text).where((line) => !line.startsWith('#')),
    );
    return paths.isEmpty ? null : FileClip(paths);
  }

  List<String> get _uris => [
    for (final path in paths) Uri.file(path).toString(),
  ];

  String get gnome => [if (cut) 'cut' else 'copy', ..._uris].join('\n');
  String get uris => _uris.map((uri) => '$uri\r\n').join();
  String get text => paths.join('\n');

  @override
  bool operator ==(Object other) =>
      other is FileClip && other.cut == cut && listEquals(other.paths, paths);

  @override
  int get hashCode => Object.hash(cut, Object.hashAll(paths));
}

class PsitoClipboard {
  PsitoClipboard([this._channel = const MethodChannel('psito/clipboard')]) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') await read();
    });
  }

  static final instance = PsitoClipboard();

  final MethodChannel _channel;

  /// Sem o plugin (nos testes e no laboratório), fica só neste processo.
  FileClip? _memory;

  /// O que está copiado, até onde se sabe. No Wayland, só quem tem o foco do
  /// teclado vê a oferta: o [read] pergunta de novo.
  final current = ValueNotifier<FileClip?>(null);

  /// Copia ou recorta [paths].
  Future<void> copy(List<String> paths, {bool cut = false}) async {
    final clip = FileClip(paths, cut: cut);
    _memory = current.value = clip;
    try {
      await _channel.invokeMethod('set', {
        'gnome': clip.gnome,
        'uris': clip.uris,
        'text': clip.text,
      });
    } on MissingPluginException {
      // Fica o _memory
    }
  }

  /// Os arquivos copiados agora, por este app ou por outro. Null se não há
  /// arquivos (um texto copiado, por exemplo).
  Future<FileClip?> read() async {
    FileClip? clip;
    try {
      clip = switch (await _read('x-special/gnome-copied-files')) {
        final text? => FileClip.parseGnome(text),
        null => null,
      };
      if (clip == null) {
        if (await _read('text/uri-list') case final text?) {
          clip = FileClip.parseUris(text);
        }
      }
    } on MissingPluginException {
      clip = _memory;
    }
    current.value = clip;
    return clip;
  }

  Future<String?> _read(String target) async {
    final bytes = await _channel.invokeMethod<Uint8List>('read', target);
    return bytes == null ? null : utf8.decode(bytes, allowMalformed: true);
  }

  /// Esquece o que está copiado: um recortado só cola uma vez.
  Future<void> clear() async {
    _memory = current.value = null;
    try {
      await _channel.invokeMethod('clear');
    } on MissingPluginException {
      // Fica o _memory
    }
  }
}
