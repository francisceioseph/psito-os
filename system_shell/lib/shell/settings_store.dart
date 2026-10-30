// system_shell/lib/shell/settings_store.dart
//
// Configurações do sistema em JSON: $XDG_CONFIG_HOME/psito/settings.json.
// Sem shared_preferences, que não tem plugin no flutter-pi.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:psito_sdk/psito_sdk.dart';

File defaultSettingsFile() {
  final env = Platform.environment;
  final configHome = env['XDG_CONFIG_HOME'] ?? '${env['HOME'] ?? '.'}/.config';
  return File('$configHome/psito/settings.json');
}

class SettingsStore extends ValueNotifier<PsitoSettings> {
  /// Null: só em memória (testes).
  final File? file;

  SettingsStore._(super.value, this.file);

  SettingsStore.memory([PsitoSettings initial = PsitoSettings.defaults])
    : this._(initial, null);

  /// Arquivo ausente ou corrompido não impede o boot: ficam os padrões.
  static Future<SettingsStore> load(File file) async {
    var settings = PsitoSettings.defaults;
    try {
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        if (json is Map<String, Object?>) {
          settings = PsitoSettings.fromJson(json);
        } else {
          debugPrint('🦜 ${file.path} não é um objeto JSON; usando padrões');
        }
      }
    } catch (e) {
      debugPrint('🦜 Erro lendo ${file.path}: $e; usando padrões');
    }
    return SettingsStore._(settings, file);
  }

  Future<void> update(PsitoSettings settings) async {
    if (settings == value) return;
    value = settings;
    await _save();
  }

  // Grava num .tmp e renomeia: um desligamento no meio não corrompe o arquivo
  Future<void> _save() async {
    final file = this.file;
    if (file == null) return;
    try {
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(
        const JsonEncoder.withIndent('  ').convert(value.toJson()),
      );
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('🦜 Erro gravando ${file.path}: $e');
    }
  }
}
