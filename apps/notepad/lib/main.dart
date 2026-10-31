// apps/notepad/lib/main.dart
import 'package:psito_runtime/psito_runtime.dart';

import 'notepad_app.dart';

Future<void> main(List<String> args) =>
    runPsitoApp(const NotepadApp(), args: args);
