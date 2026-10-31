#ifndef FLUTTER_PLUGIN_PSITO_DND_H_
#define FLUTTER_PLUGIN_PSITO_DND_H_

#include <flutter_linux/flutter_linux.h>

#include "psito_runtime_plugin.h"

G_BEGIN_DECLS

// Liga o arrastar e soltar de arquivos (o canal psito/dnd) a uma view. O
// plugin liga a view do app sozinho; o runner do shell liga as outras.
FLUTTER_PLUGIN_EXPORT void psito_dnd_attach(FlView* view);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_PSITO_DND_H_
