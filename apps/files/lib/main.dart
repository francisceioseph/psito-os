// apps/files/lib/main.dart
import 'package:psito_runtime/psito_runtime.dart';

import 'files_app.dart';

Future<void> main(List<String> args) =>
    runPsitoApp(const FilesApp(), args: args);
