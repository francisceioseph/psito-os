#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk-layer-shell.h>

#include <cstring>
#include <initializer_list>
#include <vector>

#include "flutter/generated_plugin_registrant.h"
#include "psito_runtime/psito_dnd.h"
#include "clipboard_keeper.h"
#include "idle.h"
#include "toplevels.h"

// O shell do Psito como cliente layer-shell: um engine, uma FlView por
// superfície, cada uma na sua GtkWindow. O Dart (lib/views.dart) desenha
// cada view e pede a sobreposição, os toasts e o OSD pelo canal
// psito/surfaces. PSITO_SURFACES=background,topbar,... cria só as pedidas
// (o fundo sempre), para medir o custo de cada view.
//
// As seis ficam no monitor principal. Cada outro monitor ganha um fundo e uma
// top bar só dele (Secondary). Quando ele sai, as views ficam guardadas,
// escondidas, para o próximo: destruir uma view com o engine rodando deixa
// 1,75 MB para trás a cada ciclo (docs/FASE-12.md).

// As mesmas medidas do system_shell: TopBar.height e a reserva da dock (a
// do tamanho padrão; a de verdade vem do Dart, pelo método dock)
constexpr int kTopBarHeight = 40;
constexpr int kDockReserve = 100;
// Espaço transparente embaixo da top bar para os tooltips, que o Flutter
// desenha dentro da própria view; fora da região de input e da zona exclusiva
constexpr int kTooltipSpace = 48;
// Toasts no canto de cima à direita e o OSD acima da dock, como no
// DesktopScreen do system_shell. A margem da dock (20) e a dos toasts (8 e
// 12) ficam dentro da superfície, no espaço da sombra (lib/views.dart)
constexpr int kToastsTop = kTopBarHeight + 8 - 20;
constexpr int kOsdBottom = kDockReserve + 16;

// O fundo e a top bar de um monitor que não é o principal. Sem monitor, estão
// guardados
struct Secondary {
  int id;
  GdkMonitor* monitor;
  FlView* background;
  FlView* topbar;
  GtkWindow* background_window;
  GtkWindow* topbar_window;
};

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlView* views[6];
  GtkWindow* windows[6];
  FlMethodChannel* surfaces_channel;
  FlEngine* engine;
  GdkMonitor* primary;
  std::vector<Secondary>* secondaries;
  int next_secondary;
  int next_monitor;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

enum { kBackground, kTopBar, kDock, kOverlay, kToasts, kOsd, kSurfaces };
const char* kSurfaceNames[] = {"background", "topbar", "dock",
                               "overlay",    "toasts", "osd"};

static int surface_index(FlValue* name) {
  if (name == nullptr || fl_value_get_type(name) != FL_VALUE_TYPE_STRING) {
    return -1;
  }
  for (int i = 0; i < kSurfaces; i++) {
    if (strcmp(fl_value_get_string(name), kSurfaceNames[i]) == 0) return i;
  }
  return -1;
}

// Sem PSITO_SURFACES, todas
static bool surface_wanted(int i) {
  const gchar* wanted = g_getenv("PSITO_SURFACES");
  if (i == kBackground || wanted == nullptr || *wanted == '\0') return true;
  g_auto(GStrv) names = g_strsplit(wanted, ",", -1);
  return g_strv_contains(names, kSurfaceNames[i]);
}

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

// A dock, os toasts e o OSD têm o tamanho do conteúdo, que o Dart mede e
// manda pelo canal. As views dimensionadas pelo conteúdo do embedder
// (fl_view_new_sized_to_content) não servem: elas pedem o tamanho novo à
// GtkWindow, mas a superfície layer-shell fica no tamanho do primeiro
// configure e a view nunca aparece.
// A borda [input] (esquerda, cima, direita, baixo) é o espaço da sombra e
// fica fora da região de input: os cliques ali vão para as janelas.
static void sized_window_resize(GtkWindow* window, int width, int height,
                                const int input[4]) {
  width = MAX(width, 1);
  height = MAX(height, 1);
  gtk_widget_set_size_request(GTK_WIDGET(window), width, height);
  gtk_window_resize(window, width, height);
  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
  if (gdk_window == nullptr || input == nullptr) return;
  cairo_rectangle_int_t rect = {input[0], input[1],
                                MAX(width - input[0] - input[2], 0),
                                MAX(height - input[1] - input[3], 0)};
  cairo_region_t* region = cairo_region_create_rectangle(&rect);
  gdk_window_input_shape_combine_region(gdk_window, region, 0, 0);
  cairo_region_destroy(region);
}

static void anchor_all(GtkWindow* window) {
  for (auto edge : {GTK_LAYER_SHELL_EDGE_LEFT, GTK_LAYER_SHELL_EDGE_RIGHT,
                    GTK_LAYER_SHELL_EDGE_TOP, GTK_LAYER_SHELL_EDGE_BOTTOM}) {
    gtk_layer_set_anchor(window, edge, TRUE);
  }
}

// Altura 0: nenhum clique
static void set_input_region(GtkWidget* widget, int y, int height) {
  GdkWindow* window = gtk_widget_get_window(widget);
  if (window == nullptr) return;
  cairo_rectangle_int_t rect = {0, y, gtk_widget_get_allocated_width(widget),
                                height};
  cairo_region_t* region = height > 0 ? cairo_region_create_rectangle(&rect)
                                      : cairo_region_create();
  gdk_window_input_shape_combine_region(window, region, 0, 0);
  cairo_region_destroy(region);
}

// A sobreposição só desenhando, sem input nem teclado: o ícone que segue o
// ponteiro quando se arrasta da dock (o ponteiro continua com a dock)
static gboolean overlay_passive = FALSE;

// A faixa da top bar fica fora da região de input da sobreposição: com um
// painel aberto, clicar na top bar troca de painel
static void overlay_input(GtkWidget* widget) {
  if (overlay_passive) {
    set_input_region(widget, 0, 0);
  } else {
    set_input_region(widget, kTopBarHeight,
                     gtk_widget_get_allocated_height(widget) - kTopBarHeight);
  }
}

static void overlay_size_allocate_cb(GtkWidget* widget, GdkRectangle*,
                                     gpointer) {
  overlay_input(widget);
}

// Só a barra recebe cliques; o espaço dos tooltips deixa passar
static void topbar_size_allocate_cb(GtkWidget* widget, GdkRectangle*,
                                    gpointer) {
  set_input_region(widget, 0, kTopBarHeight);
}

// O OSD só avisa: os cliques vão para o que estiver embaixo
static void osd_size_allocate_cb(GtkWidget* widget, GdkRectangle*, gpointer) {
  set_input_region(widget, 0, 0);
}

// O compositor fecha a superfície de um monitor que saiu, e o gtk-layer-shell
// pede para fechar a janela. Ela fica: o principal muda de monitor e continua,
// e um secundário é guardado no monitor-removed.
static gboolean layer_delete_cb(GtkWidget*, GdkEvent*, gpointer) {
  return TRUE;
}

static GtkWindow* background_window_new(MyApplication* self, FlView* view) {
  GtkWindow* window =
      layer_window(self, view, GTK_LAYER_SHELL_LAYER_BACKGROUND, "background");
  anchor_all(window);
  gtk_layer_set_exclusive_zone(window, -1);
  g_signal_connect(window, "delete-event", G_CALLBACK(layer_delete_cb),
                   nullptr);
  return window;
}

static GtkWindow* topbar_window_new(MyApplication* self, FlView* view) {
  GtkWindow* window =
      layer_window(self, view, GTK_LAYER_SHELL_LAYER_TOP, "topbar");
  gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_TOP, TRUE);
  gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_LEFT, TRUE);
  gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_RIGHT, TRUE);
  gtk_widget_set_size_request(GTK_WIDGET(window), -1,
                              kTopBarHeight + kTooltipSpace);
  gtk_layer_set_exclusive_zone(window, kTopBarHeight);
  g_signal_connect_after(window, "size-allocate",
                         G_CALLBACK(topbar_size_allocate_cb), nullptr);
  g_signal_connect(window, "delete-event", G_CALLBACK(layer_delete_cb),
                   nullptr);
  return window;
}

static FlValue* secondaries_value(MyApplication* self) {
  FlValue* list = fl_value_new_list();
  for (const Secondary& secondary : *self->secondaries) {
    FlValue* map = fl_value_new_map();
    fl_value_set_string_take(map, "id", fl_value_new_int(secondary.id));
    fl_value_set_string_take(
        map, "background",
        fl_value_new_int(fl_view_get_id(secondary.background)));
    fl_value_set_string_take(
        map, "topbar", fl_value_new_int(fl_view_get_id(secondary.topbar)));
    fl_value_append_take(list, map);
  }
  return list;
}

static void notify_secondaries(MyApplication* self) {
  if (self->surfaces_channel == nullptr) return;
  g_autoptr(FlValue) list = secondaries_value(self);
  fl_method_channel_invoke_method(self->surfaces_channel, "secondaries", list,
                                  nullptr, nullptr, nullptr);
}

// O monitor como o Dart vê: o id, que dura enquanto ele está ligado, e a
// geometria. Um monitor sem id já saiu, mesmo que o GDK ainda liste
static FlValue* monitors_value(MyApplication* self) {
  GdkDisplay* display = gdk_display_get_default();
  FlValue* list = fl_value_new_list();
  for (int i = 0; i < gdk_display_get_n_monitors(display); i++) {
    GdkMonitor* monitor = gdk_display_get_monitor(display, i);
    int id = GPOINTER_TO_INT(g_object_get_data(G_OBJECT(monitor), kMonitorIdKey));
    if (id == 0) continue;
    GdkRectangle rect;
    gdk_monitor_get_geometry(monitor, &rect);
    const char* model = gdk_monitor_get_model(monitor);
    FlValue* map = fl_value_new_map();
    fl_value_set_string_take(map, "id", fl_value_new_int(id));
    fl_value_set_string_take(map, "x", fl_value_new_int(rect.x));
    fl_value_set_string_take(map, "y", fl_value_new_int(rect.y));
    fl_value_set_string_take(map, "width", fl_value_new_int(rect.width));
    fl_value_set_string_take(map, "height", fl_value_new_int(rect.height));
    fl_value_set_string_take(
        map, "scale", fl_value_new_int(gdk_monitor_get_scale_factor(monitor)));
    fl_value_set_string_take(map, "model",
                             fl_value_new_string(model == nullptr ? "" : model));
    fl_value_set_string_take(map, "primary",
                             fl_value_new_bool(monitor == self->primary));
    fl_value_append_take(list, map);
  }
  return list;
}

static void notify_monitors(MyApplication* self) {
  if (self->surfaces_channel == nullptr) return;
  g_autoptr(FlValue) list = monitors_value(self);
  fl_method_channel_invoke_method(self->surfaces_channel, "monitors", list,
                                  nullptr, nullptr, nullptr);
  // Uma janela entra num monitor que o GDK ainda não conhecia, ou fica com um
  // que já saiu: o id dela só se acerta aqui
  toplevels_monitors_changed();
}

static void monitor_notify_cb(GdkMonitor*, GParamSpec*, gpointer user_data) {
  notify_monitors(MY_APPLICATION(user_data));
}

static void monitor_track(MyApplication* self, GdkMonitor* monitor) {
  int id = self->next_monitor++;
  g_object_set_data(G_OBJECT(monitor), kMonitorIdKey, GINT_TO_POINTER(id));
  g_message("monitor %d ligado: %s", id, gdk_monitor_get_model(monitor));
  g_signal_connect_object(monitor, "notify::geometry",
                          G_CALLBACK(monitor_notify_cb), self,
                          G_CONNECT_DEFAULT);
  g_signal_connect_object(monitor, "notify::scale-factor",
                          G_CALLBACK(monitor_notify_cb), self,
                          G_CONNECT_DEFAULT);
}

static void secondary_add(MyApplication* self, GdkMonitor* monitor) {
  Secondary* free_slot = nullptr;
  for (Secondary& secondary : *self->secondaries) {
    if (secondary.monitor == nullptr) {
      free_slot = &secondary;
      break;
    }
  }
  if (free_slot == nullptr) {
    Secondary secondary = {};
    secondary.id = self->next_secondary++;
    secondary.background = fl_view_new_for_engine(self->engine);
    secondary.topbar = fl_view_new_for_engine(self->engine);
    secondary.background_window =
        background_window_new(self, secondary.background);
    secondary.topbar_window = topbar_window_new(self, secondary.topbar);
    self->secondaries->push_back(secondary);
    free_slot = &self->secondaries->back();
  }
  free_slot->monitor = monitor;
  gtk_layer_set_monitor(free_slot->background_window, monitor);
  gtk_layer_set_monitor(free_slot->topbar_window, monitor);
  gtk_widget_show(GTK_WIDGET(free_slot->background_window));
  gtk_widget_show(GTK_WIDGET(free_slot->topbar_window));
}

static void secondary_remove(MyApplication* self, GdkMonitor* monitor) {
  for (Secondary& secondary : *self->secondaries) {
    if (secondary.monitor != monitor) continue;
    gtk_widget_hide(GTK_WIDGET(secondary.background_window));
    gtk_widget_hide(GTK_WIDGET(secondary.topbar_window));
    secondary.monitor = nullptr;
    return;
  }
}

// As seis superfícies vão para [monitor]; o gtk-layer-shell refaz as que estão
// na tela, e sem monitor elas esperam o próximo
static void primary_set(MyApplication* self, GdkMonitor* monitor) {
  self->primary = monitor;
  if (monitor == nullptr) return;
  for (GtkWindow* window : self->windows) {
    if (window != nullptr) gtk_layer_set_monitor(window, monitor);
  }
}

static void monitor_added_cb(GdkDisplay*, GdkMonitor* monitor,
                             gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  monitor_track(self, monitor);
  if (self->primary == nullptr) {
    primary_set(self, monitor);
  } else {
    secondary_add(self, monitor);
  }
  notify_secondaries(self);
  notify_monitors(self);
}

// [monitor] passa a ter a dock, a mesa e as sobreposições, e troca de lugar
// com o principal de agora: as views dele ficam com o outro.
static bool primary_change(MyApplication* self, int id) {
  GdkDisplay* display = gdk_display_get_default();
  for (int i = 0; i < gdk_display_get_n_monitors(display); i++) {
    GdkMonitor* monitor = gdk_display_get_monitor(display, i);
    if (GPOINTER_TO_INT(g_object_get_data(G_OBJECT(monitor), kMonitorIdKey)) !=
        id) {
      continue;
    }
    if (monitor == self->primary) return true;
    GdkMonitor* previous = self->primary;
    secondary_remove(self, monitor);
    primary_set(self, monitor);
    if (previous != nullptr) secondary_add(self, previous);
    notify_secondaries(self);
    notify_monitors(self);
    return true;
  }
  return false;
}

static void monitor_removed_cb(GdkDisplay* display, GdkMonitor* monitor,
                               gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  g_message("monitor desligado: %s", gdk_monitor_get_model(monitor));
  g_object_set_data(G_OBJECT(monitor), kMonitorIdKey, nullptr);
  if (monitor != self->primary) {
    secondary_remove(self, monitor);
  } else {
    // Um secundário vira o principal, e o fundo e a top bar dele dão lugar
    // aos de sempre
    GdkMonitor* next = nullptr;
    for (int i = 0; i < gdk_display_get_n_monitors(display); i++) {
      GdkMonitor* candidate = gdk_display_get_monitor(display, i);
      if (candidate != monitor) next = candidate;
    }
    if (next != nullptr) secondary_remove(self, next);
    primary_set(self, next);
  }
  notify_secondaries(self);
  notify_monitors(self);
}

static gboolean background_focus_cb(GtkWidget* widget, GdkEventFocus* event,
                                    gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  g_autoptr(FlValue) focused = fl_value_new_bool(event->in);
  fl_method_channel_invoke_method(self->surfaces_channel, "backgroundFocus",
                                  focused, nullptr, nullptr, nullptr);
  return FALSE;
}

static void surfaces_call_cb(FlMethodChannel*, FlMethodCall* call,
                             gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);

  GtkWindow* overlay = self->windows[kOverlay];
  if (strcmp(method, "surfaces") == 0) {
    g_autoptr(FlValue) ids = fl_value_new_map();
    for (int i = 0; i < kSurfaces; i++) {
      if (self->views[i] == nullptr) continue;
      fl_value_set_string_take(ids, kSurfaceNames[i],
                               fl_value_new_int(fl_view_get_id(self->views[i])));
    }
    fl_method_call_respond_success(call, ids, nullptr);
  } else if (strcmp(method, "secondaries") == 0) {
    g_autoptr(FlValue) list = secondaries_value(self);
    fl_method_call_respond_success(call, list, nullptr);
  } else if (strcmp(method, "monitors") == 0) {
    g_autoptr(FlValue) list = monitors_value(self);
    fl_method_call_respond_success(call, list, nullptr);
  } else if (strcmp(method, "setPrimary") == 0 && args != nullptr &&
             fl_value_get_type(args) == FL_VALUE_TYPE_INT) {
    g_autoptr(FlValue) found =
        fl_value_new_bool(primary_change(self, fl_value_get_int(args)));
    fl_method_call_respond_success(call, found, nullptr);
  } else if (strcmp(method, "showOverlay") == 0) {
    const gchar* mode = args != nullptr &&
                                fl_value_get_type(args) == FL_VALUE_TYPE_STRING
                            ? fl_value_get_string(args)
                            : "";
    if (overlay != nullptr) {
      overlay_passive = strcmp(mode, "passive") == 0;
      // "pointer": os cliques, sem tirar o teclado de quem tem (o menu da
      // mesa: fechando, o foco não volta para ela, e o Renomear precisa dele)
      gtk_layer_set_keyboard_mode(
          overlay, strcmp(mode, "exclusive") == 0
                       ? GTK_LAYER_SHELL_KEYBOARD_MODE_EXCLUSIVE
                   : overlay_passive || strcmp(mode, "pointer") == 0
                       ? GTK_LAYER_SHELL_KEYBOARD_MODE_NONE
                       : GTK_LAYER_SHELL_KEYBOARD_MODE_ON_DEMAND);
      gtk_widget_show(GTK_WIDGET(overlay));
      overlay_input(GTK_WIDGET(overlay));
      if (!overlay_passive) {
        gtk_widget_grab_focus(GTK_WIDGET(self->views[kOverlay]));
      }
    }
    fl_method_call_respond_success(call, nullptr, nullptr);
  } else if (strcmp(method, "hideOverlay") == 0) {
    if (overlay != nullptr) gtk_widget_hide(GTK_WIDGET(overlay));
    fl_method_call_respond_success(call, nullptr, nullptr);
  } else if (strcmp(method, "resize") == 0 && args != nullptr &&
             fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
    int i = surface_index(fl_value_lookup_string(args, "surface"));
    int width = fl_value_get_int(fl_value_lookup_string(args, "width"));
    int height = fl_value_get_int(fl_value_lookup_string(args, "height"));
    FlValue* input = fl_value_lookup_string(args, "input");
    int insets[4] = {0, 0, 0, 0};
    if (input != nullptr && fl_value_get_type(input) == FL_VALUE_TYPE_LIST &&
        fl_value_get_length(input) == 4) {
      for (int k = 0; k < 4; k++) {
        insets[k] = fl_value_get_int(fl_value_get_list_value(input, k));
      }
    }
    // O OSD não recebe cliques: a região dele fica vazia (osd_size_allocate_cb)
    if (i >= 0 && self->windows[i] != nullptr) {
      sized_window_resize(self->windows[i], width, height,
                          i == kOsd ? nullptr : insets);
    }
    fl_method_call_respond_success(call, nullptr, nullptr);
  } else if (strcmp(method, "dock") == 0 && args != nullptr &&
             fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
    // A borda da dock (bottom, left ou right) e a zona exclusiva (0 quando
    // ela some sozinha: as janelas ficam com o lugar)
    GtkWindow* dock = self->windows[kDock];
    FlValue* edge = fl_value_lookup_string(args, "edge");
    FlValue* exclusive = fl_value_lookup_string(args, "exclusive");
    if (dock != nullptr && edge != nullptr &&
        fl_value_get_type(edge) == FL_VALUE_TYPE_STRING) {
      const gchar* name = fl_value_get_string(edge);
      GtkLayerShellEdge anchor = strcmp(name, "left") == 0
                                     ? GTK_LAYER_SHELL_EDGE_LEFT
                                 : strcmp(name, "right") == 0
                                     ? GTK_LAYER_SHELL_EDGE_RIGHT
                                     : GTK_LAYER_SHELL_EDGE_BOTTOM;
      for (auto e : {GTK_LAYER_SHELL_EDGE_LEFT, GTK_LAYER_SHELL_EDGE_RIGHT,
                     GTK_LAYER_SHELL_EDGE_TOP, GTK_LAYER_SHELL_EDGE_BOTTOM}) {
        gtk_layer_set_anchor(dock, e, e == anchor);
      }
      if (exclusive != nullptr &&
          fl_value_get_type(exclusive) == FL_VALUE_TYPE_INT) {
        gtk_layer_set_exclusive_zone(dock, fl_value_get_int(exclusive));
      }
    }
    fl_method_call_respond_success(call, nullptr, nullptr);
  } else if (strcmp(method, "show") == 0 || strcmp(method, "hide") == 0) {
    int i = surface_index(args);
    if (i >= 0 && self->windows[i] != nullptr) {
      gtk_widget_set_visible(GTK_WIDGET(self->windows[i]),
                             strcmp(method, "show") == 0);
    }
    fl_method_call_respond_success(call, nullptr, nullptr);
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
  }
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
  GtkWindow* background_window = background_window_new(self, background);
  // A mesa recebe o teclado quando é clicada, e uma janela clicada leva de
  // volta; o labwc só dá o foco se o modo já for on_demand antes do clique
  gtk_layer_set_keyboard_mode(background_window,
                              GTK_LAYER_SHELL_KEYBOARD_MODE_ON_DEMAND);
  gtk_widget_realize(GTK_WIDGET(background));
  FlEngine* engine = fl_view_get_engine(background);
  self->engine = engine;

  self->views[kBackground] = background;
  self->windows[kBackground] = background_window;

  if (surface_wanted(kTopBar)) {
    FlView* topbar = fl_view_new_for_engine(engine);
    GtkWindow* window = topbar_window_new(self, topbar);
    self->views[kTopBar] = topbar;
    self->windows[kTopBar] = window;
  }

  // A dock tem o tamanho do conteúdo (sized_window_resize), centrada na
  // base; a margem até a borda está dentro da superfície, e a zona
  // exclusiva é a reserva do system_shell
  if (surface_wanted(kDock)) {
    FlView* dock = fl_view_new_for_engine(engine);
    GtkWindow* window =
        layer_window(self, dock, GTK_LAYER_SHELL_LAYER_TOP, "dock");
    gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_BOTTOM, TRUE);
    gtk_layer_set_exclusive_zone(window, kDockReserve);
    sized_window_resize(window, 1, 1, nullptr);
    self->views[kDock] = dock;
    self->windows[kDock] = window;
  }

  if (surface_wanted(kOverlay)) {
    FlView* overlay = fl_view_new_for_engine(engine);
    GtkWindow* window =
        layer_window(self, overlay, GTK_LAYER_SHELL_LAYER_OVERLAY, "overlay");
    anchor_all(window);
    gtk_layer_set_exclusive_zone(window, -1);
    g_signal_connect_after(window, "size-allocate",
                           G_CALLBACK(overlay_size_allocate_cb), nullptr);
    self->views[kOverlay] = overlay;
    self->windows[kOverlay] = window;
  }

  // Os toasts e o OSD têm o tamanho do conteúdo e ignoram as zonas
  // exclusivas: as margens já contam a top bar e a dock
  if (surface_wanted(kToasts)) {
    FlView* toasts = fl_view_new_for_engine(engine);
    GtkWindow* window =
        layer_window(self, toasts, GTK_LAYER_SHELL_LAYER_OVERLAY, "toasts");
    gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_TOP, TRUE);
    gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_RIGHT, TRUE);
    gtk_layer_set_margin(window, GTK_LAYER_SHELL_EDGE_TOP, kToastsTop);
    gtk_layer_set_exclusive_zone(window, -1);
    sized_window_resize(window, 1, 1, nullptr);
    self->views[kToasts] = toasts;
    self->windows[kToasts] = window;
  }

  if (surface_wanted(kOsd)) {
    FlView* osd = fl_view_new_for_engine(engine);
    GtkWindow* window =
        layer_window(self, osd, GTK_LAYER_SHELL_LAYER_OVERLAY, "osd");
    gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_BOTTOM, TRUE);
    gtk_layer_set_margin(window, GTK_LAYER_SHELL_EDGE_BOTTOM, kOsdBottom);
    gtk_layer_set_exclusive_zone(window, -1);
    g_signal_connect_after(window, "size-allocate",
                           G_CALLBACK(osd_size_allocate_cb), nullptr);
    sized_window_resize(window, 1, 1, nullptr);
    self->views[kOsd] = osd;
    self->windows[kOsd] = window;
  }

  FlBinaryMessenger* messenger = fl_engine_get_binary_messenger(engine);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->surfaces_channel = fl_method_channel_new(messenger, "psito/surfaces",
                                                 FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->surfaces_channel,
                                            surfaces_call_cb, self, nullptr);
  // A mesa só sabe do teclado por aqui: a janela continua `activated` no
  // foreign-toplevel enquanto o fundo tem o foco
  g_signal_connect(background_window, "focus-in-event",
                   G_CALLBACK(background_focus_cb), self);
  g_signal_connect(background_window, "focus-out-event",
                   G_CALLBACK(background_focus_cb), self);
  toplevels_init(messenger);
  idle_init(messenger);
  clipboard_keeper_init(messenger);

  GdkDisplay* display = gdk_display_get_default();
  for (int i = 0; i < gdk_display_get_n_monitors(display); i++) {
    monitor_track(self, gdk_display_get_monitor(display, i));
  }
  primary_set(self, gdk_display_get_n_monitors(display) > 0
                        ? gdk_display_get_monitor(display, 0)
                        : nullptr);

  // A sobreposição, os toasts e o OSD ficam só realizados (a view existe
  // para o Dart) e aparecem quando o Dart pede
  for (int i = 0; i < kSurfaces; i++) {
    if (self->windows[i] == nullptr) continue;
    if (i == kOverlay || i == kToasts || i == kOsd) {
      gtk_widget_realize(GTK_WIDGET(self->views[i]));
    } else {
      gtk_widget_show(GTK_WIDGET(self->windows[i]));
    }
  }

  fl_register_plugins(FL_PLUGIN_REGISTRY(background));
  // Arquivos soltos na dock (o plugin já ligou o fundo, a view dele)
  if (self->views[kDock] != nullptr) psito_dnd_attach(self->views[kDock]);

  for (int i = 1; i < gdk_display_get_n_monitors(display); i++) {
    secondary_add(self, gdk_display_get_monitor(display, i));
  }
  g_signal_connect(display, "monitor-added", G_CALLBACK(monitor_added_cb),
                   self);
  g_signal_connect(display, "monitor-removed", G_CALLBACK(monitor_removed_cb),
                   self);
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
  delete self->secondaries;
  self->secondaries = nullptr;
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

static void my_application_init(MyApplication* self) {
  self->secondaries = new std::vector<Secondary>();
  self->next_monitor = 1;
}

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
