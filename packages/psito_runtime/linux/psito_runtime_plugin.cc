// packages/psito_runtime/linux/psito_runtime_plugin.cc
//
// O lado C do runtime dos apps do Psito: o canal psito/window, sobre a
// GtkWindow em que o runner pôs a view. Como é um plugin, entra em qualquer
// app que dependa do psito_runtime sem mexer no runner dele.
#include "include/psito_runtime/psito_runtime_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <cstring>

// Todo app do Psito cabe em 240x160
static const int kMinWidth = 240;
static const int kMinHeight = 160;

#define PSITO_RUNTIME_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), psito_runtime_plugin_get_type(), \
                              PsitoRuntimePlugin))

struct _PsitoRuntimePlugin {
  GObject parent_instance;
  FlView* view;
  FlMethodChannel* channel;
};

G_DEFINE_TYPE(PsitoRuntimePlugin, psito_runtime_plugin, g_object_get_type())

static GtkWindow* plugin_window(PsitoRuntimePlugin* self) {
  GtkWidget* toplevel = gtk_widget_get_toplevel(GTK_WIDGET(self->view));
  return GTK_IS_WINDOW(toplevel) ? GTK_WINDOW(toplevel) : nullptr;
}

static void set_min_size(GtkWindow* window) {
  GdkGeometry hints = {};
  hints.min_width = kMinWidth;
  hints.min_height = kMinHeight;
  gtk_window_set_geometry_hints(window, nullptr, &hints, GDK_HINT_MIN_SIZE);
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* call,
                           gpointer user_data) {
  PsitoRuntimePlugin* self = PSITO_RUNTIME_PLUGIN(user_data);
  const gchar* method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);
  GtkWindow* window = plugin_window(self);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (window == nullptr) {
    response = FL_METHOD_RESPONSE(fl_method_error_response_new(
        "no_window", "a view não está numa GtkWindow", nullptr));
  } else if (strcmp(method, "setTitle") == 0 &&
             fl_value_get_type(args) == FL_VALUE_TYPE_STRING) {
    const gchar* title = fl_value_get_string(args);
    // O runner do modelo usa uma GtkHeaderBar no Wayland
    GtkWidget* titlebar = gtk_window_get_titlebar(window);
    if (titlebar != nullptr && GTK_IS_HEADER_BAR(titlebar)) {
      gtk_header_bar_set_title(GTK_HEADER_BAR(titlebar), title);
    }
    gtk_window_set_title(window, title);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "setSize") == 0 &&
             fl_value_get_type(args) == FL_VALUE_TYPE_LIST &&
             fl_value_get_length(args) == 2) {
    int width = fl_value_get_int(fl_value_get_list_value(args, 0));
    int height = fl_value_get_int(fl_value_get_list_value(args, 1));
    set_min_size(window);
    gtk_window_set_default_size(window, width, height);
    gtk_window_resize(window, width, height);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "close") == 0) {
    gtk_window_close(window);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(call, response, nullptr);
}

static void psito_runtime_plugin_dispose(GObject* object) {
  g_clear_object(&PSITO_RUNTIME_PLUGIN(object)->channel);
  G_OBJECT_CLASS(psito_runtime_plugin_parent_class)->dispose(object);
}

static void psito_runtime_plugin_class_init(PsitoRuntimePluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = psito_runtime_plugin_dispose;
}

static void psito_runtime_plugin_init(PsitoRuntimePlugin* self) {}

void psito_runtime_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  PsitoRuntimePlugin* plugin = PSITO_RUNTIME_PLUGIN(
      g_object_new(psito_runtime_plugin_get_type(), nullptr));
  plugin->view = fl_plugin_registrar_get_view(registrar);

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "psito/window",
      FL_METHOD_CODEC(codec));
  // O plugin vive tanto quanto o app: a referência fica com o canal
  fl_method_channel_set_method_call_handler(plugin->channel, method_call_cb,
                                            plugin, g_object_unref);
}
