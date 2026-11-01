// apps/settings/lib/main.dart
import 'package:psito_runtime/psito_runtime.dart';

import 'settings_app.dart';

Future<void> main(List<String> args) =>
    runPsitoApp(const SettingsApp(), args: args);
