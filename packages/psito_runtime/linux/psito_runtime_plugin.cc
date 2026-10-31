// packages/psito_runtime/linux/psito_runtime_plugin.cc
//
// O lado C do runtime dos apps do Psito: o canal psito/window, sobre a
// GtkWindow em que o runner pôs a view, e o id da aplicação; e o canal
// psito/icons, os ícones do tema (o PsitoIcon do SDK). Como é um plugin,
// entra em qualquer app que dependa do psito_runtime sem mexer no runner
// dele (e no shell, que também usa os ícones). O arrastar e soltar de
// arquivos fica no psito_dnd.cc.
#include "include/psito_runtime/psito_runtime_plugin.h"

#include "include/psito_runtime/psito_dnd.h"

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
  FlMethodChannel* icons_channel;
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
  if (strcmp(method, "applicationId") == 0) {
    // O APPLICATION_ID do runner, que é o id do .desktop do app
    GApplication* app = g_application_get_default();
    const gchar* id =
        app != nullptr ? g_application_get_application_id(app) : nullptr;
    g_autoptr(FlValue) result =
        id != nullptr ? fl_value_new_string(id) : fl_value_new_null();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (window == nullptr) {
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

// O ícone do tema como PNG, para o Image.memory do Dart. "names" é a lista
// do mais exato para o mais genérico (o primeiro que o tema tiver); um
// caminho absoluto é lido do arquivo.
static void icons_call_cb(FlMethodChannel*, FlMethodCall* call, gpointer) {
  FlValue* args = fl_method_call_get_args(call);
  if (strcmp(fl_method_call_get_name(call), "iconPng") != 0 ||
      args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  FlValue* names = fl_value_lookup_string(args, "names");
  FlValue* size_value = fl_value_lookup_string(args, "size");
  if (names == nullptr || fl_value_get_type(names) != FL_VALUE_TYPE_LIST ||
      size_value == nullptr) {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  int size = fl_value_get_int(size_value);
  size_t count = fl_value_get_length(names);
  g_autoptr(GdkPixbuf) pixbuf = nullptr;
  g_autofree const gchar** list = g_new0(const gchar*, count + 1);
  size_t themed = 0;
  for (size_t i = 0; i < count; i++) {
    const gchar* name = fl_value_get_string(fl_value_get_list_value(names, i));
    if (g_path_is_absolute(name)) {
      if (pixbuf == nullptr && themed == 0) {
        pixbuf = gdk_pixbuf_new_from_file_at_size(name, size, size, nullptr);
      }
    } else {
      list[themed++] = name;
    }
  }
  if (pixbuf == nullptr && themed > 0) {
    GtkIconTheme* theme = gtk_icon_theme_get_default();
    g_autoptr(GtkIconInfo) info = gtk_icon_theme_choose_icon(
        theme, list, size, GTK_ICON_LOOKUP_FORCE_SIZE);
    if (info != nullptr) pixbuf = gtk_icon_info_load_icon(info, nullptr);
  }
  gchar* buffer = nullptr;
  gsize length = 0;
  if (pixbuf == nullptr ||
      !gdk_pixbuf_save_to_buffer(pixbuf, &buffer, &length, "png", nullptr,
                                 nullptr)) {
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }
  g_autoptr(FlValue) png =
      fl_value_new_uint8_list(reinterpret_cast<uint8_t*>(buffer), length);
  g_free(buffer);
  fl_method_call_respond_success(call, png, nullptr);
}

static void psito_runtime_plugin_dispose(GObject* object) {
  g_clear_object(&PSITO_RUNTIME_PLUGIN(object)->channel);
  g_clear_object(&PSITO_RUNTIME_PLUGIN(object)->icons_channel);
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
  plugin->icons_channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "psito/icons",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(plugin->icons_channel,
                                            icons_call_cb, nullptr, nullptr);
  if (plugin->view != nullptr) psito_dnd_attach(plugin->view);
}
