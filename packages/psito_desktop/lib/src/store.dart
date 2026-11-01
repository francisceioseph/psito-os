// packages/psito_desktop/lib/src/store.dart
//
// As posições dos ícones, em $XDG_CONFIG_HOME/psito/desktop.json: o nome do
// arquivo e a célula. Só o shell grava.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'grid.dart';

File defaultDeskFile([Map<String, String>? env]) {
  env ??= Platform.environment;
  final configHome = env['XDG_CONFIG_HOME'] ?? '${env['HOME'] ?? '.'}/.config';
  return File('$configHome/psito/desktop.json');
}

class DeskStore {
  /// Null: só em memória (testes e o laboratório).
  final File? file;
  final Map<String, DeskCell> _cells;

  DeskStore._(this._cells, this.file);

  DeskStore.memory([Map<String, DeskCell> cells = const {}])
    : this._({...cells}, null);

  static Future<DeskStore> load(File file) async =>
      DeskStore._(await _read(file), file);

  static Future<Map<String, DeskCell>> _read(File file) async {
    try {
      final json = jsonDecode(await file.readAsString());
      if (json case {'cells': final Map<String, Object?> cells}) {
        return {
          for (final MapEntry(:key, :value) in cells.entries)
            if (value case [final int column, final int row])
              key: DeskCell(column, row),
        };
      }
      debugPrint('🦜 ${file.path} sem as células; os ícones vão se arrumar');
    } on PathNotFoundException {
      // A primeira vez
    } catch (e) {
      debugPrint('🦜 Erro lendo ${file.path}: $e; os ícones vão se arrumar');
    }
    return {};
  }

  Map<String, DeskCell> get cells => Map.unmodifiable(_cells);

  /// Grava as células de [cells], por cima das que já existiam.
  Future<void> put(Map<String, DeskCell> cells) async {
    if (cells.isEmpty) return;
    _cells.addAll(cells);
    await _save();
  }

  /// Esquece quem não está em [keys] (o arquivo que saiu da pasta).
  Future<void> retain(Set<String> keys) async {
    final before = _cells.length;
    _cells.removeWhere((key, _) => !keys.contains(key));
    if (_cells.length != before) await _save();
  }

  Future<void> _saving = Future.value();

  // Uma gravação de cada vez: duas no mesmo .tmp se atropelam, e renomear um
  // ícone já faz o put e, logo depois, o retain
  Future<void> _save() => _saving = _saving.then((_) => _write());

  // Grava num .tmp e renomeia: um desligamento no meio não corrompe o arquivo
  Future<void> _write() async {
    final file = this.file;
    if (file == null) return;
    try {
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'cells': {
            for (final MapEntry(:key, :value) in _cells.entries)
              key: [value.column, value.row],
          },
        }),
      );
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('🦜 Erro gravando ${file.path}: $e');
    }
  }
}
