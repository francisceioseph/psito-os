// Contrato entre o shell e os apps do Psito OS.
//
// Os apps só conhecem o que está aqui: nada de screens/, widgets/ ou shell/.
// Na fase 4 este contrato vira o protocolo entre processos, então tudo que um
// app pede ao shell precisa passar pelo PsitoAppContext.
import 'package:flutter/widgets.dart';

/// Descrição de um app: o que aparece na dock/launcher e como construí-lo.
abstract class PsitoApp {
  const PsitoApp();

  String get id;
  String get name;
  IconData get icon;
  Color get color;

  /// Tamanho da janela ao abrir.
  Size get defaultSize => const Size(480, 360);

  /// Se true, abrir de novo foca a janela existente em vez de criar outra.
  bool get singleInstance => false;

  Widget build(PsitoAppContext context);

  void onOpen(PsitoAppContext context) {}

  void onClose(PsitoAppContext context) {}
}

/// Tudo o que um app pode pedir ao shell, por janela.
abstract class PsitoAppContext {
  /// Id da janela no shell.
  String get windowId;

  void setTitle(String title);

  void close();

  void notify(PsitoNotification notification);
}

class PsitoNotification {
  final String title;
  final String? body;

  const PsitoNotification({required this.title, this.body});
}
