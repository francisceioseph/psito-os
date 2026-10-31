#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk-layer-shell.h>

#include <cstring>
#include <initializer_list>

#include "flutter/generated_plugin_registrant.h"
#include "toplevels.h"

// O shell do Psito como cliente layer-shell: um engine, uma FlView por
// superfície, cada uma na sua GtkWindow. O Dart (lib/views.dart) desenha
// cada view e pede a sobreposição pelo canal psito/surfaces.

// As mesmas medidas do system_shell: TopBar.height e a reserva da dock
constexpr int kTopBarHeight = 40;
constexpr int kDockMargin = 20;
constexpr int kDockReserve = 100;
// Espaço transparente embaixo da top bar para os tooltips, que o Flutter
// desenha dentro da própria view; fora da região de input e da zona exclusiva
constexpr int kTooltipSpace = 48;

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlView* views[4];
  GtkWindow* overlay;
  FlMethodChannel* surfaces_channel;
  FlMethodChannel* icons_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

enum { kBackground, kTopBar, kDock, kOverlay };
const char* kSurfaceNames[] = {"background", "topbar", "dock", "overlay"};

// Janela transparente numa camada do layer-shell, com a view dentro
static GtkWindow* layer_window(MyApplication* self, FlView* view,
                               GtkLayerShellLayer layer, const char* name) {
  GtkWindow* window = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
  gtk_window_set_application(window, GTK_APPLICATION(self));
  gtk_layer_init_for_window(window);
  gtk_layer_set_layer(window, layer);
  g_autofree gchar* ns = g_strdup_printf("psito-%s", name);
  gtk_layer_set_namespace(window, ns);
  gtk_layer_set_keyboard_mode(window, GTK_LAYER_SHELL_KEYBOARD_MODE_NONE);

  GdkVisual* visual =
      gdk_screen_get_rgba_visual(gtk_widget_get_screen(GTK_WIDGET(window)));
  if (visual != nullptr) gtk_widget_set_visual(GTK_WIDGET(window), visual);
  gtk_widget_set_app_paintable(GTK_WIDGET(window), TRUE);

  GdkRGBA transparent = {0, 0, 0, 0};
  fl_view_set_background_color(view, &transparent);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));
  return window;
}

static void anchor_all(GtkWindow* window) {
  for (auto edge : {GTK_LAYER_SHELL_EDGE_LEFT, GTK_LAYER_SHELL_EDGE_RIGHT,
                    GTK_LAYER_SHELL_EDGE_TOP, GTK_LAYER_SHELL_EDGE_BOTTOM}) {
    gtk_layer_set_anchor(window, edge, TRUE);
  }
}

static void set_input_region(GtkWidget* widget, int y, int height) {
  GdkWindow* window = gtk_widget_get_window(widget);
  if (window == nullptr) return;
  cairo_rectangle_int_t rect = {0, y, gtk_widget_get_allocated_width(widget),
                                height};
  cairo_region_t* region = cairo_region_create_rectangle(&rect);
  gdk_window_input_shape_combine_region(window, region, 0, 0);
  cairo_region_destroy(region);
}

// A faixa da top bar fica fora da região de input da sobreposição: com um
// painel aberto, clicar na top bar troca de painel
static void overlay_size_allocate_cb(GtkWidget* widget, GdkRectangle* alloc,
                                     gpointer) {
  set_input_region(widget, kTopBarHeight, alloc->height - kTopBarHeight);
}

// Só a barra recebe cliques; o espaço dos tooltips deixa passar
static void topbar_size_allocate_cb(GtkWidget* widget, GdkRectangle*,
                                    gpointer) {
  set_input_region(widget, 0, kTopBarHeight);
}

static void surfaces_call_cb(FlMethodChannel*, FlMethodCall* call,
                             gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);

  if (strcmp(method, "surfaces") == 0) {
    g_autoptr(FlValue) ids = fl_value_new_map();
    for (int i = 0; i < 4; i++) {
      fl_value_set_string_take(ids, kSurfaceNames[i],
                               fl_value_new_int(fl_view_get_id(self->views[i])));
    }
    fl_method_call_respond_success(call, ids, nullptr);
  } else if (strcmp(method, "showOverlay") == 0) {
    bool exclusive = args != nullptr &&
                     fl_value_get_type(args) == FL_VALUE_TYPE_STRING &&
                     strcmp(fl_value_get_string(args), "exclusive") == 0;
    gtk_layer_set_keyboard_mode(self->overlay,
                                exclusive
                                    ? GTK_LAYER_SHELL_KEYBOARD_MODE_EXCLUSIVE
                                    : GTK_LAYER_SHELL_KEYBOARD_MODE_ON_DEMAND);
    gtk_widget_show(GTK_WIDGET(self->overlay));
    gtk_widget_grab_focus(GTK_WIDGET(self->views[kOverlay]));
    fl_method_call_respond_success(call, nullptr, nullptr);
  } else if (strcmp(method, "hideOverlay") == 0) {
    gtk_widget_hide(GTK_WIDGET(self->overlay));
    fl_method_call_respond_success(call, nullptr, nullptr);
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
  }
}

// Ícone do tema (ou de um caminho) como PNG, para o Image.memory do Dart
static void icons_call_cb(FlMethodChannel*, FlMethodCall* call, gpointer) {
  FlValue* args = fl_method_call_get_args(call);
  if (strcmp(fl_method_call_get_name(call), "iconPng") != 0 ||
      args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  const gchar* name = fl_value_get_string(fl_value_lookup_string(args, "name"));
  int size = fl_value_get_int(fl_value_lookup_string(args, "size"));

  g_autoptr(GdkPixbuf) pixbuf = nullptr;
  if (g_path_is_absolute(name)) {
    pixbuf = gdk_pixbuf_new_from_file_at_size(name, size, size, nullptr);
  } else {
    pixbuf = gtk_icon_theme_load_icon(gtk_icon_theme_get_default(), name, size,
                                      GTK_ICON_LOOKUP_FORCE_SIZE, nullptr);
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

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  if (!gtk_layer_is_supported()) {
    g_warning("O compositor não tem o wlr-layer-shell: o shell não sobe.");
    return;
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  // A view implícita é o fundo; realizar ela sobe o engine, e as outras
  // views entram nele
  FlView* background = fl_view_new(project);
  GtkWindow* background_window = layer_window(
      self, background, GTK_LAYER_SHELL_LAYER_BACKGROUND, "background");
  anchor_all(background_window);
  gtk_layer_set_exclusive_zone(background_window, -1);
  gtk_widget_realize(GTK_WIDGET(background));
  FlEngine* engine = fl_view_get_engine(background);

  FlView* topbar = fl_view_new_for_engine(engine);
  GtkWindow* topbar_window =
      layer_window(self, topbar, GTK_LAYER_SHELL_LAYER_TOP, "topbar");
  gtk_layer_set_anchor(topbar_window, GTK_LAYER_SHELL_EDGE_TOP, TRUE);
  gtk_layer_set_anchor(topbar_window, GTK_LAYER_SHELL_EDGE_LEFT, TRUE);
  gtk_layer_set_anchor(topbar_window, GTK_LAYER_SHELL_EDGE_RIGHT, TRUE);
  gtk_widget_set_size_request(GTK_WIDGET(topbar_window), -1,
                              kTopBarHeight + kTooltipSpace);
  gtk_layer_set_exclusive_zone(topbar_window, kTopBarHeight);
  g_signal_connect_after(topbar_window, "size-allocate",
                         G_CALLBACK(topbar_size_allocate_cb), nullptr);

  // A dock tem o tamanho do conteúdo, centrada na base. A zona exclusiva
  // conta a partir da margem: as duas somam a reserva do system_shell
  FlView* dock = fl_view_new_sized_to_content(engine);
  GtkWindow* dock_window =
      layer_window(self, dock, GTK_LAYER_SHELL_LAYER_TOP, "dock");
  gtk_layer_set_anchor(dock_window, GTK_LAYER_SHELL_EDGE_BOTTOM, TRUE);
  gtk_layer_set_margin(dock_window, GTK_LAYER_SHELL_EDGE_BOTTOM, kDockMargin);
  gtk_layer_set_exclusive_zone(dock_window, kDockReserve - kDockMargin);

  FlView* overlay = fl_view_new_for_engine(engine);
  self->overlay =
      layer_window(self, overlay, GTK_LAYER_SHELL_LAYER_OVERLAY, "overlay");
  anchor_all(self->overlay);
  gtk_layer_set_exclusive_zone(self->overlay, -1);
  g_signal_connect_after(self->overlay, "size-allocate",
                         G_CALLBACK(overlay_size_allocate_cb), nullptr);

  self->views[kBackground] = background;
  self->views[kTopBar] = topbar;
  self->views[kDock] = dock;
  self->views[kOverlay] = overlay;

  FlBinaryMessenger* messenger = fl_engine_get_binary_messenger(engine);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->surfaces_channel = fl_method_channel_new(messenger, "psito/surfaces",
                                                 FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->surfaces_channel,
                                            surfaces_call_cb, self, nullptr);
  self->icons_channel =
      fl_method_channel_new(messenger, "psito/icons", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->icons_channel,
                                            icons_call_cb, nullptr, nullptr);
  toplevels_init(messenger);

  // A sobreposição fica só realizada (a view existe para o Dart) e aparece
  // quando o Dart pede
  gtk_widget_realize(GTK_WIDGET(overlay));
  gtk_widget_show(GTK_WIDGET(background_window));
  gtk_widget_show(GTK_WIDGET(topbar_window));
  gtk_widget_show(GTK_WIDGET(dock_window));

  fl_register_plugins(FL_PLUGIN_REGISTRY(background));
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
  g_clear_object(&self->surfaces_channel);
  g_clear_object(&self->icons_channel);
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
