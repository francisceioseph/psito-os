import 'package:flutter/material.dart';

import 'app.dart';
import 'services/system_services.dart';
import 'shell/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.load(defaultSettingsFile());
  final services = SystemServices.start();
  runApp(PsitoOSApp(settings: settings, services: services));
}
