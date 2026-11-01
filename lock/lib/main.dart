// lock/lib/main.dart
//
// A tela de bloqueio. Quem bloqueia e desbloqueia é o runner em C
// (`linux/runner/my_application.cc`); aqui só se pede a senha.
import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/session_service.dart';

import 'l10n/lock_localizations.dart';
import 'lock_screen.dart';

const _channel = MethodChannel('psito/lock');

/// As configurações direto do arquivo: o shell pode estar parado.
PsitoSettings readSettings(Map<String, String> env) {
  final config = env['XDG_CONFIG_HOME'] ?? '${env['HOME']}/.config';
  try {
    final json = jsonDecode(
      File('$config/psito/settings.json').readAsStringSync(),
    );
    if (json is Map<String, Object?>) return PsitoSettings.fromJson(json);
  } on FileSystemException catch (e) {
    debugPrint('🦜 bloqueio: sem as configurações ($e)');
  } on FormatException catch (e) {
    debugPrint('🦜 bloqueio: configurações inválidas ($e)');
  }
  return PsitoSettings.defaults;
}

/// O nome completo do `/etc/passwd`, ou o login.
String displayName(String user, String passwd) {
  for (final line in const LineSplitter().convert(passwd)) {
    final fields = line.split(':');
    if (fields.length > 4 && fields.first == user) {
      final name = fields[4].split(',').first.trim();
      if (name.isNotEmpty) return name;
    }
  }
  return user;
}

String _userName(Map<String, String> env) {
  final user = env['USER'] ?? '';
  try {
    return displayName(user, File('/etc/passwd').readAsStringSync());
  } on FileSystemException {
    return user;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final env = Platform.environment;
  final settings = readSettings(env);
  final session = LogindSessionService(DBusClient.system());
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: psitoTheme(settings.accent),
      locale: resolvePsitoLocale(settings.language),
      localizationsDelegates: psitoLocalizationsDelegates(const [
        LockLocalizations.delegate,
      ]),
      supportedLocales: psitoLocales,
      home: LockScreen(
        settings: settings,
        userName: _userName(env),
        session: session,
        authenticate: (password) async =>
            await _channel.invokeMethod<bool>('authenticate', password) ??
            false,
      ),
    ),
  );
}
