// system_shell/lib/shell/app_registry.dart
import 'package:psito_sdk/psito_sdk.dart';

import '../apps/browser_app.dart';
import '../apps/buddy_app.dart';
import '../apps/calculator_app.dart';
import '../apps/clock_app.dart';
import '../apps/files_app.dart';
import '../apps/notepad_app.dart';
import '../apps/settings_app.dart';

/// Apps instalados, na ordem em que aparecem na dock.
const List<PsitoApp> registeredApps = [
  BuddyApp(),
  CalculatorApp(),
  ClockApp(),
  NotepadApp(),
  FilesApp(),
  BrowserApp(),
  SettingsApp(),
];
