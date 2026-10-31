// apps/lib/main.dart
//
// O host dos apps do Psito: `psito_apps <id>` roda um PsitoApp do
// system_shell pelo runtime (packages/psito_runtime), com o app_id
// org.psito.<id> (o runner) e o .desktop de apps/desktop/.
import 'dart:io';

import 'package:psito_runtime/psito_runtime.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/shell/app_registry.dart';

/// O app do registro com esse id, ou null.
PsitoApp? appById(String id) {
  for (final app in registeredApps) {
    if (app.id == id) return app;
  }
  return null;
}

Future<void> main(List<String> args) async {
  final app = args.isEmpty ? null : appById(args.first);
  if (app == null) {
    stderr.writeln(
      'Uso: psito_apps <id>, com id: '
      '${registeredApps.map((a) => a.id).join(', ')}',
    );
    exit(2);
  }
  await runPsitoApp(app);
}
