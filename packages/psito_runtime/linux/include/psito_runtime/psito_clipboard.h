#ifndef FLUTTER_PLUGIN_PSITO_CLIPBOARD_H_
#define FLUTTER_PLUGIN_PSITO_CLIPBOARD_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

// Abre o canal psito/clipboard, a área de transferência de arquivos.
void psito_clipboard_register(FlBinaryMessenger* messenger);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_PSITO_CLIPBOARD_H_
