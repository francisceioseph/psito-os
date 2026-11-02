#ifndef RUNNER_OUTPUTS_H_
#define RUNNER_OUTPUTS_H_

#include <flutter_linux/flutter_linux.h>
#include <gdk/gdk.h>

// Os monitores do compositor pelo wlr-output-management, para o Dart, no canal
// psito/outputs (lib/displays.dart): a lista com os modos, aplicar e testar.
// Sem o protocolo no compositor, a lista fica vazia.
void outputs_init(FlBinaryMessenger* messenger);

// Pergunta o conector de [monitor] ao compositor. O GDK3 não diz, e é o que liga
// o GdkMonitor ao monitor do protocolo. [changed] é chamado com [data] quando a
// resposta chega, e daí vale o outputs_monitor_connector.
void outputs_monitor_watch(GdkMonitor* monitor, void (*changed)(gpointer),
                           GObject* data);
const char* outputs_monitor_connector(GdkMonitor* monitor);

#endif  // RUNNER_OUTPUTS_H_
