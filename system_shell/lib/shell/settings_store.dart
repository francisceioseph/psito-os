// system_shell/lib/shell/settings_store.dart
//
// Configurações do sistema em JSON: $XDG_CONFIG_HOME/psito/settings.json.
// Um arquivo só para o shell e os apps, cada um no seu processo: quem grava
// é o app de Configurações, e o shell vê a mudança pelo [SettingsStore.watch].
import 'dart:async';
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
  static Future<SettingsStore> load(File file) async =>
      SettingsStore._(await _read(file) ?? PsitoSettings.defaults, file);

  /// Null: arquivo ausente ou ilegível.
  static Future<PsitoSettings?> _read(File file) async {
    try {
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is Map<String, Object?>) return PsitoSettings.fromJson(json);
      debugPrint('🦜 ${file.path} não é um objeto JSON; usando padrões');
    } catch (e) {
      debugPrint('🦜 Erro lendo ${file.path}: $e; usando padrões');
    }
    return null;
  }

  StreamSubscription<FileSystemEvent>? _watch;
  Timer? _debounce;

  /// Relê o arquivo quando outro processo grava nele. Vigia o diretório,
  /// porque a gravação troca o arquivo (rename do .tmp). Uma gravação gera
  /// vários eventos, então espera [debounce] sem eventos antes de reler; a
  /// própria gravação relê o mesmo valor e não avisa ninguém.
  Future<void> watch({
    Duration debounce = const Duration(milliseconds: 150),
  }) async {
    final file = this.file;
    if (file == null || _watch != null) return;
    try {
      await file.parent.create(recursive: true);
    } catch (e) {
      debugPrint('🦜 Sem como vigiar ${file.path}: $e');
      return;
    }
    _watch = file.parent.watch().listen((event) {
      final hit =
          event.path == file.path ||
          (event is FileSystemMoveEvent && event.destination == file.path);
      if (!hit) return;
      _debounce?.cancel();
      _debounce = Timer(debounce, () async {
        final settings = await _read(file);
        if (settings != null) value = settings;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(_watch?.cancel());
    super.dispose();
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
