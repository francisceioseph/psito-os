// system_shell/lib/shell/app_registry.dart
import 'package:psito_calculator/calculator_app.dart';
import 'package:psito_clock/clock_app.dart';
import 'package:psito_files/files_app.dart';
import 'package:psito_notepad/notepad_app.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_settings/settings_app.dart';

/// Os apps do laboratório, na ordem em que aparecem na dock dele. Na VM,
/// quem diz quais apps existem são os .desktop instalados.
const List<PsitoApp> registeredApps = [
  CalculatorApp(),
  ClockApp(),
  NotepadApp(),
  FilesApp(),
  SettingsApp(),
];
