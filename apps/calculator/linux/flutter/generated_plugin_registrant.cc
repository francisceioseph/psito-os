//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <psito_runtime/psito_runtime_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) psito_runtime_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "PsitoRuntimePlugin");
  psito_runtime_plugin_register_with_registrar(psito_runtime_registrar);
}
