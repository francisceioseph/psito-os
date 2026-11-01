// greeter/lib/main.dart
//
// A tela de login, cliente do greetd dentro do cage. Quando a sessão fica
// pronta o processo sai, e é isso que faz o greetd abrir ela.
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/session_service.dart';
import 'package:psito_services/time_service.dart';

import 'greetd_client.dart';
import 'greeter_screen.dart';
import 'l10n/greeter_localizations.dart';

const _session = ['/usr/bin/psito-session'];
const _sessionEnv = ['XDG_SESSION_TYPE=wayland', 'XDG_SESSION_DESKTOP=psito'];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final socket = Platform.environment['GREETD_SOCK'];
  if (socket == null) {
    debugPrint('🦜 greeter: sem o GREETD_SOCK');
    exit(1);
  }
  final locale = resolvePsitoLocale('');
  await initializeDateFormatting(locale.toString());
  final client = await GreetdClient.connect(socket);
  final flow = LoginFlow(
    client.request,
    command: _session,
    environment: _sessionEnv,
  );
  flow.addListener(() {
    if (flow.state == LoginState.started) exit(0);
  });
  final bus = DBusClient.system();
  final session = LogindSessionService(bus);
  final time = TimedatedTimeService(bus);
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: psitoTheme(PsitoSettings.defaults.accent),
      locale: locale,
      localizationsDelegates: psitoLocalizationsDelegates(const [
        GreeterLocalizations.delegate,
      ]),
      supportedLocales: psitoLocales,
      home: GreeterScreen(
        flow: flow,
        users: loginUsers(File('/etc/passwd').readAsStringSync()),
        session: session,
        now: time.now,
      ),
    ),
  );
}
