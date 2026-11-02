#ifndef RUNNER_TOPLEVELS_H_
#define RUNNER_TOPLEVELS_H_

#include <flutter_linux/flutter_linux.h>

// Ponte do wlr-foreign-toplevel-management para o Dart, no canal
// psito/toplevels (lib/toplevels.dart). Liga o protocolo no wl_display do
// GDK; os eventos chegam pela fila padrão, que o próprio GDK despacha.
// Sem Wayland ou sem o protocolo no compositor, a lista fica vazia.
void toplevels_init(FlBinaryMessenger* messenger);

// Onde o runner guarda o id de cada GdkMonitor (g_object_set_data).
constexpr char kMonitorIdKey[] = "psito-monitor-id";

// Os monitores mudaram: manda de novo em quais está cada janela.
void toplevels_monitors_changed();

#endif  // RUNNER_TOPLEVELS_H_
