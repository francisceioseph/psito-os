#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <gdk/gdkwayland.h>
#include <security/pam_appl.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#include "ext-session-lock-v1-client-protocol.h"

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// A sessão bloqueada pelo ext-session-lock: o compositor não mostra nada nem
// entrega entrada a ninguém além destas superfícies, mesmo se este processo
// cair. Um processo novo pode assumir o bloqueio de um que morreu.
static ext_session_lock_manager_v1* lock_manager = nullptr;
static ext_session_lock_v1* session_lock = nullptr;

// Sai quando o processo pode voltar pela unidade (o monitor com o campo sumiu)
static constexpr int kExitRestart = 3;

// Um monitor bloqueado. O campo de senha fica só no primeiro: nos outros, uma
// janela GTK vazia, sem o custo de outra view do Flutter.
struct LockOutput {
  GdkMonitor* monitor;
  GtkWindow* window;
  ext_session_lock_surface_v1* surface;
  bool flutter;
};

static GList* lock_outputs = nullptr;

static void registry_global(void*, wl_registry* registry, uint32_t name,
                            const char* interface, uint32_t) {
  if (strcmp(interface, ext_session_lock_manager_v1_interface.name) == 0) {
    lock_manager = static_cast<ext_session_lock_manager_v1*>(wl_registry_bind(
        registry, name, &ext_session_lock_manager_v1_interface, 1));
  }
}

static void registry_global_remove(void*, wl_registry*, uint32_t) {}

static const wl_registry_listener registry_listener = {
    registry_global, registry_global_remove};

// Avisa o systemd (Type=notify) de que a tela já está bloqueada: é o que o
// shell espera antes de deixar o computador suspender.
static void notify_ready() {
  const char* path = g_getenv("NOTIFY_SOCKET");
  if (path == nullptr || path[0] == '\0') return;
  int fd = socket(AF_UNIX, SOCK_DGRAM | SOCK_CLOEXEC, 0);
  if (fd < 0) return;
  sockaddr_un address = {};
  address.sun_family = AF_UNIX;
  g_strlcpy(address.sun_path, path, sizeof(address.sun_path));
  // O @ é um socket abstrato
  if (address.sun_path[0] == '@') address.sun_path[0] = '\0';
  socklen_t size = offsetof(sockaddr_un, sun_path) + strlen(path);
  static const char kReady[] = "READY=1";
  if (sendto(fd, kReady, sizeof(kReady) - 1, 0,
             reinterpret_cast<sockaddr*>(&address), size) < 0) {
    g_warning("psito-lock: sem o aviso ao systemd");
  }
  close(fd);
}

static void lock_locked(void*, ext_session_lock_v1*) { notify_ready(); }

// O compositor recusou: outro cliente vivo já bloqueia, e a tela segue segura
static void lock_finished(void*, ext_session_lock_v1*) {
  g_message("psito-lock: outro bloqueio já está valendo");
  notify_ready();
  exit(0);
}

static const ext_session_lock_v1_listener lock_listener = {lock_locked,
                                                           lock_finished};

static void surface_configure(void* data, ext_session_lock_surface_v1* surface,
                              uint32_t serial, uint32_t width,
                              uint32_t height) {
  auto* output = static_cast<LockOutput*>(data);
  gtk_window_resize(output->window, width, height);
  gtk_widget_set_size_request(GTK_WIDGET(output->window), width, height);
  ext_session_lock_surface_v1_ack_configure(surface, serial);
}

static const ext_session_lock_surface_v1_listener surface_listener = {
    surface_configure};

static void add_output(GdkMonitor* monitor, GtkWindow* window, bool flutter) {
  auto* output = g_new0(LockOutput, 1);
  output->monitor = monitor;
  output->window = window;
  output->flutter = flutter;
  lock_outputs = g_list_append(lock_outputs, output);

  // A superfície sem papel de xdg_toplevel: quem dá o papel é o bloqueio
  gtk_window_set_decorated(window, FALSE);
  gtk_widget_realize(GTK_WIDGET(window));
  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
  gdk_wayland_window_set_use_custom_surface(gdk_window);
  gtk_widget_show(GTK_WIDGET(window));

  output->surface = ext_session_lock_v1_get_lock_surface(
      session_lock, gdk_wayland_window_get_wl_surface(gdk_window),
      gdk_wayland_monitor_get_wl_output(monitor));
  ext_session_lock_surface_v1_add_listener(output->surface, &surface_listener,
                                           output);
}

static void monitor_added(GdkDisplay*, GdkMonitor* monitor, gpointer) {
  add_output(monitor, GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL)), false);
}

static void monitor_removed(GdkDisplay*, GdkMonitor* monitor, gpointer) {
  for (GList* item = lock_outputs; item != nullptr; item = item->next) {
    auto* output = static_cast<LockOutput*>(item->data);
    if (output->monitor != monitor) continue;
    // O campo de senha foi junto: um processo novo escolhe outro monitor
    if (output->flutter) exit(kExitRestart);
    ext_session_lock_surface_v1_destroy(output->surface);
    gtk_widget_destroy(GTK_WIDGET(output->window));
    lock_outputs = g_list_delete_link(lock_outputs, item);
    g_free(output);
    return;
  }
}

static int pam_conversation(int count, const pam_message** messages,
                            pam_response** responses, void* data) {
  auto* replies =
      static_cast<pam_response*>(calloc(count, sizeof(pam_response)));
  if (replies == nullptr) return PAM_BUF_ERR;
  for (int i = 0; i < count; i++) {
    if (messages[i]->msg_style == PAM_PROMPT_ECHO_OFF) {
      replies[i].resp = strdup(static_cast<const char*>(data));
    }
  }
  *responses = replies;
  return PAM_SUCCESS;
}

static bool check_password(const char* password) {
  const pam_conv conversation = {pam_conversation,
                                 const_cast<char*>(password)};
  pam_handle_t* handle = nullptr;
  int result =
      pam_start("psito-lock", g_get_user_name(), &conversation, &handle);
  if (result == PAM_SUCCESS) result = pam_authenticate(handle, 0);
  if (result == PAM_SUCCESS) result = pam_acct_mgmt(handle, 0);
  pam_end(handle, result);
  return result == PAM_SUCCESS;
}

// O PAM demora de propósito ao errar: numa thread, para a tela não parar
static void check_thread(GTask* task, gpointer, gpointer data, GCancellable*) {
  g_task_return_boolean(task, check_password(static_cast<char*>(data)));
}

static void free_password(gpointer data) {
  auto* password = static_cast<char*>(data);
  explicit_bzero(password, strlen(password));
  g_free(password);
}

static void check_done(GObject*, GAsyncResult* result, gpointer data) {
  g_autoptr(FlMethodCall) call = FL_METHOD_CALL(data);
  bool ok = g_task_propagate_boolean(G_TASK(result), nullptr);
  g_autoptr(FlValue) value = fl_value_new_bool(ok);
  fl_method_call_respond_success(call, value, nullptr);
  if (!ok) return;
  // O desbloqueio fica aqui, e o Dart não tem como pedir sem a senha certa
  ext_session_lock_v1_unlock_and_destroy(session_lock);
  wl_display_roundtrip(
      gdk_wayland_display_get_wl_display(gdk_display_get_default()));
  exit(0);
}

static void lock_method(FlMethodChannel*, FlMethodCall* call, gpointer) {
  FlValue* args = fl_method_call_get_args(call);
  if (g_strcmp0(fl_method_call_get_name(call), "authenticate") != 0 ||
      fl_value_get_type(args) != FL_VALUE_TYPE_STRING) {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  const char* password = fl_value_get_string(args);
  if (password[0] == '\0') {
    g_autoptr(FlValue) value = fl_value_new_bool(false);
    fl_method_call_respond_success(call, value, nullptr);
    return;
  }
  g_autoptr(GTask) task =
      g_task_new(nullptr, nullptr, check_done, g_object_ref(call));
  g_task_set_task_data(task, g_strdup(password), free_password);
  g_task_run_in_thread(task, check_thread);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GdkDisplay* display = gdk_display_get_default();
  if (!GDK_IS_WAYLAND_DISPLAY(display)) {
    g_warning("psito-lock: só no Wayland");
    exit(1);
  }
  wl_display* wl = gdk_wayland_display_get_wl_display(display);
  wl_registry* registry = wl_display_get_registry(wl);
  wl_registry_add_listener(registry, &registry_listener, nullptr);
  wl_display_roundtrip(wl);
  if (lock_manager == nullptr) {
    g_warning("psito-lock: o compositor não tem o ext-session-lock");
    exit(1);
  }

  GtkWindow* window = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
  gtk_window_set_application(window, GTK_APPLICATION(application));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlBinaryMessenger* messenger =
      fl_engine_get_binary_messenger(fl_view_get_engine(view));
  static FlMethodChannel* channel = fl_method_channel_new(
      messenger, "psito/lock", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, lock_method, nullptr,
                                            nullptr);

  // Bloqueia antes de qualquer quadro: a tela some já aqui
  session_lock = ext_session_lock_manager_v1_lock(lock_manager);
  ext_session_lock_v1_add_listener(session_lock, &lock_listener, nullptr);

  GdkMonitor* primary = gdk_display_get_primary_monitor(display);
  if (primary == nullptr) primary = gdk_display_get_monitor(display, 0);
  if (primary != nullptr) add_output(primary, window, true);
  for (int i = 0; i < gdk_display_get_n_monitors(display); i++) {
    GdkMonitor* monitor = gdk_display_get_monitor(display, i);
    if (monitor != primary) monitor_added(display, monitor, nullptr);
  }
  g_signal_connect(display, "monitor-added", G_CALLBACK(monitor_added),
                   nullptr);
  g_signal_connect(display, "monitor-removed", G_CALLBACK(monitor_removed),
                   nullptr);
  wl_display_roundtrip(wl);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
