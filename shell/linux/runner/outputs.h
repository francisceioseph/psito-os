#ifndef RUNNER_OUTPUTS_H_
#define RUNNER_OUTPUTS_H_

#include <flutter_linux/flutter_linux.h>

// Os monitores do compositor pelo wlr-output-management, para o Dart, no canal
// psito/outputs (lib/displays.dart): a lista com os modos, aplicar e testar.
// Sem o protocolo no compositor, a lista fica vazia.
void outputs_init(FlBinaryMessenger* messenger);

#endif  // RUNNER_OUTPUTS_H_
