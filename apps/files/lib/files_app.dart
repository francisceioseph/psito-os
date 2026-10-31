// apps/files/lib/files_app.dart
//
// O Psito Files, um Finder: a barra lateral com os favoritos, os modos
// ícones, lista e colunas, a pré-visualização no Espaço, o "Obter
// informações", as abas, a lixeira, copiar e mover com progresso e arrastar
// entre pastas e abas. A base dos arquivos é o psito_fs, e abrir cada
// arquivo no app certo é com o shell (o PsitoAppContext.open).
import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'src/controller.dart';
import 'src/env.dart';
import 'src/window.dart';

export 'src/controller.dart' show FilesController;
export 'src/env.dart' show FilesConfig, FilesEnv, ViewMode;

class FilesView extends StatefulWidget {
  final PsitoAppContext appContext;

  /// O sistema e a configuração; sem eles, os de verdade (os testes passam
  /// pastas temporárias).
  final FilesEnv? env;
  final FilesConfig? config;

  const FilesView({super.key, required this.appContext, this.env, this.config});

  @override
  State<FilesView> createState() => _FilesViewState();
}

class _FilesViewState extends State<FilesView> {
  late final FilesEnv _env =
      widget.env ?? FilesEnv.fromPlatform(now: widget.appContext.now);
  late final FilesConfig _config = widget.config ?? FilesConfig.load(_env);
  late final FilesController _controller = FilesController(
    ctx: widget.appContext,
    env: _env,
    config: _config,
    opened: widget.appContext.openedPaths,
  );

  @override
  void dispose() {
    _controller.dispose();
    if (widget.config == null) _config.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _config,
    builder: (context, _) => FilesWindow(controller: _controller),
  );
}

class FilesApp extends PsitoApp {
  const FilesApp();

  @override
  String get id => 'files';

  @override
  String get name => 'Files';

  @override
  IconData get icon => Icons.folder_open_rounded;

  @override
  Color get color => const Color(0xFFFFC107);

  @override
  Size get defaultSize => const Size(900, 560);

  /// Uma janela com abas: abrir uma pasta com o Files aberto vira uma aba.
  @override
  bool get singleInstance => true;

  @override
  Widget build(PsitoAppContext context) => FilesView(appContext: context);
}
