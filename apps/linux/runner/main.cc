#include "my_application.h"

#include <string>

// psito_apps <id>: o app_id da janela é org.psito.<id>, o mesmo do .desktop,
// para a dock e o Alt+Tab do shell acharem o app. Um id inválido fica com o
// APPLICATION_ID genérico; o Dart avisa e sai.
int main(int argc, char** argv) {
  std::string app_id;
  if (argc > 1) {
    app_id = std::string("org.psito.") + argv[1];
    if (!g_application_id_is_valid(app_id.c_str())) app_id.clear();
  }
  g_autoptr(MyApplication) app =
      my_application_new(app_id.empty() ? nullptr : app_id.c_str());
  return g_application_run(G_APPLICATION(app), argc, argv);
}
