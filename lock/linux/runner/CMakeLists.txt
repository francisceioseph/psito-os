cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES C CXX)

# O código do ext-session-lock sai do XML em linux/protocols/
find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)
set(LOCK_XML "${CMAKE_CURRENT_SOURCE_DIR}/../protocols/ext-session-lock-v1.xml")
set(LOCK_PROTOCOL "${CMAKE_CURRENT_BINARY_DIR}/ext-session-lock-v1")
add_custom_command(
  OUTPUT "${LOCK_PROTOCOL}-client-protocol.h" "${LOCK_PROTOCOL}-protocol.c"
  COMMAND ${WAYLAND_SCANNER} client-header "${LOCK_XML}" "${LOCK_PROTOCOL}-client-protocol.h"
  COMMAND ${WAYLAND_SCANNER} private-code "${LOCK_XML}" "${LOCK_PROTOCOL}-protocol.c"
  DEPENDS "${LOCK_XML}"
)

pkg_check_modules(WAYLAND_CLIENT REQUIRED IMPORTED_TARGET wayland-client)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${LOCK_PROTOCOL}-client-protocol.h"
  "${LOCK_PROTOCOL}-protocol.c"
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
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::WAYLAND_CLIENT)
target_link_libraries(${BINARY_NAME} PRIVATE pam)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
