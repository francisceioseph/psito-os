cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES C CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
# O código do wlr-foreign-toplevel-management sai do XML em linux/protocols/
# (nenhum pacote do Debian traz o XML)
find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)
set(TOPLEVEL_XML
  "${CMAKE_CURRENT_SOURCE_DIR}/../protocols/wlr-foreign-toplevel-management-unstable-v1.xml")
set(TOPLEVEL_PROTOCOL
  "${CMAKE_CURRENT_BINARY_DIR}/wlr-foreign-toplevel-management-unstable-v1")
add_custom_command(
  OUTPUT "${TOPLEVEL_PROTOCOL}-client-protocol.h" "${TOPLEVEL_PROTOCOL}-protocol.c"
  COMMAND ${WAYLAND_SCANNER} client-header "${TOPLEVEL_XML}" "${TOPLEVEL_PROTOCOL}-client-protocol.h"
  COMMAND ${WAYLAND_SCANNER} private-code "${TOPLEVEL_XML}" "${TOPLEVEL_PROTOCOL}-protocol.c"
  DEPENDS "${TOPLEVEL_XML}"
)

# O do wlr-data-control também (o clipboard_keeper.cc)
set(CLIPBOARD_XML
  "${CMAKE_CURRENT_SOURCE_DIR}/../protocols/wlr-data-control-unstable-v1.xml")
set(CLIPBOARD_PROTOCOL
  "${CMAKE_CURRENT_BINARY_DIR}/wlr-data-control-unstable-v1")
add_custom_command(
  OUTPUT "${CLIPBOARD_PROTOCOL}-client-protocol.h" "${CLIPBOARD_PROTOCOL}-protocol.c"
  COMMAND ${WAYLAND_SCANNER} client-header "${CLIPBOARD_XML}" "${CLIPBOARD_PROTOCOL}-client-protocol.h"
  COMMAND ${WAYLAND_SCANNER} private-code "${CLIPBOARD_XML}" "${CLIPBOARD_PROTOCOL}-protocol.c"
  DEPENDS "${CLIPBOARD_XML}"
)

# O do ext-idle-notify também (o idle.cc)
set(IDLE_XML "${CMAKE_CURRENT_SOURCE_DIR}/../protocols/ext-idle-notify-v1.xml")
set(IDLE_PROTOCOL "${CMAKE_CURRENT_BINARY_DIR}/ext-idle-notify-v1")
add_custom_command(
  OUTPUT "${IDLE_PROTOCOL}-client-protocol.h" "${IDLE_PROTOCOL}-protocol.c"
  COMMAND ${WAYLAND_SCANNER} client-header "${IDLE_XML}" "${IDLE_PROTOCOL}-client-protocol.h"
  COMMAND ${WAYLAND_SCANNER} private-code "${IDLE_XML}" "${IDLE_PROTOCOL}-protocol.c"
  DEPENDS "${IDLE_XML}"
)

# O do wlr-output-management também (o outputs.cc)
set(OUTPUTS_XML
  "${CMAKE_CURRENT_SOURCE_DIR}/../protocols/wlr-output-management-unstable-v1.xml")
set(OUTPUTS_PROTOCOL
  "${CMAKE_CURRENT_BINARY_DIR}/wlr-output-management-unstable-v1")
add_custom_command(
  OUTPUT "${OUTPUTS_PROTOCOL}-client-protocol.h" "${OUTPUTS_PROTOCOL}-protocol.c"
  COMMAND ${WAYLAND_SCANNER} client-header "${OUTPUTS_XML}" "${OUTPUTS_PROTOCOL}-client-protocol.h"
  COMMAND ${WAYLAND_SCANNER} private-code "${OUTPUTS_XML}" "${OUTPUTS_PROTOCOL}-protocol.c"
  DEPENDS "${OUTPUTS_XML}"
)

add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "toplevels.cc"
  "clipboard_keeper.cc"
  "idle.cc"
  "outputs.cc"
  "${OUTPUTS_PROTOCOL}-protocol.c"
  "${OUTPUTS_PROTOCOL}-client-protocol.h"
  "${IDLE_PROTOCOL}-protocol.c"
  "${IDLE_PROTOCOL}-client-protocol.h"
  "${TOPLEVEL_PROTOCOL}-protocol.c"
  "${TOPLEVEL_PROTOCOL}-client-protocol.h"
  "${CLIPBOARD_PROTOCOL}-protocol.c"
  "${CLIPBOARD_PROTOCOL}-client-protocol.h"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK_LAYER_SHELL)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::WAYLAND_CLIENT)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
