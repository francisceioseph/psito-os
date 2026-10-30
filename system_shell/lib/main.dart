import 'package:flutter/material.dart';

import 'app.dart';
import 'shell/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.load(defaultSettingsFile());
  runApp(PsitoOSApp(settings: settings));
}
