#ifndef RUNNER_IDLE_H_
#define RUNNER_IDLE_H_

#include <flutter_linux/flutter_linux.h>

// A inatividade do ext-idle-notify para o Dart, no canal psito/idle
// (lib/idle.dart). Sem o protocolo no compositor, nunca avisa.
void idle_init(FlBinaryMessenger* messenger);

#endif  // RUNNER_IDLE_H_
