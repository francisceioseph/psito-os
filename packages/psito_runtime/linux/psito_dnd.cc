// packages/psito_runtime/linux/psito_dnd.cc
//
// Arrastar e soltar arquivos entre processos, pelo arrastar do GTK3 (o do
// Wayland), só com text/uri-list. O Flutter Linux não traz isso. O canal
// psito/dnd leva o id da view em cada mensagem:
//   C -> Dart: "over" {view, x, y, uris} -> "copy" | "move" | "link" | null
//              "leave" {view}
//              "drop" {view, x, y, uris, action} -> bool
//              "dragEnd" {view} (de um arrastar que começou nesta view)
//   Dart -> C: "startDrag" {view, uris, icon?, x?, y?} (icon: um PNG, com o
//              ponto de pega em x, y)
// Enquanto o arrastar do GTK anda, a view não recebe mais os eventos do
// ponteiro, e o Draggable do Flutter que começou tudo fica parado. Por isso,
// quando o arrastar volta para a própria view, os movimentos e o soltar vão
// para o Flutter como eventos sintéticos (e o Draggable solta onde estiver);
// quando termina em outro lugar, um soltar fora da view encerra o Draggable.
#include "include/psito_runtime/psito_dnd.h"

#include <gtk/gtk.h>

#include <cstring>

static const gchar kUriList[] = "text/uri-list";

struct ViewDnd {
  FlView* view;
  int64_t id;

  // O arrastar em cima da view agora, com uma referência
  GdkDragContext* context;
  gchar** uris;
  bool requested;
  bool dropping;
  // Um "over" esperando o Dart, e se chegou outro movimento nesse meio
  bool pending;
  bool queued;
  int x;
  int y;
  guint time;

  // O arrastar que começou aqui, e se o Flutter já recebeu o soltar
  gchar** source_uris;
  bool released;
};

static FlMethodChannel* channel = nullptr;
static GHashTable* views = nullptr;  // id -> ViewDnd*

static void reset(ViewDnd* d) {
  g_clear_object(&d->context);
  g_clear_pointer(&d->uris, g_strfreev);
  d->requested = d->dropping = d->pending = d->queued = false;
}

static bool offers_uris(GtkWidget* widget, GdkDragContext* context) {
  return gtk_drag_dest_find_target(widget, context, nullptr) != GDK_NONE;
}

static void track(ViewDnd* d, GdkDragContext* context, int x, int y,
                  guint time) {
  if (d->context != context) {
    reset(d);
    d->context = GDK_DRAG_CONTEXT(g_object_ref(context));
  }
  d->x = x;
  d->y = y;
  d->time = time;
}

static FlValue* position_args(ViewDnd* d) {
  FlValue* args = fl_value_new_map();
  fl_value_set_string_take(args, "view", fl_value_new_int(d->id));
  fl_value_set_string_take(args, "x", fl_value_new_int(d->x));
  fl_value_set_string_take(args, "y", fl_value_new_int(d->y));
  FlValue* uris = fl_value_new_list();
  for (gchar** uri = d->uris; uri != nullptr && *uri != nullptr; uri++) {
    fl_value_append_take(uris, fl_value_new_string(*uri));
  }
  fl_value_set_string_take(args, "uris", uris);
  return args;
}

static GdkDragAction parse_action(FlValue* value) {
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) {
    return static_cast<GdkDragAction>(0);
  }
  const gchar* name = fl_value_get_string(value);
  if (strcmp(name, "copy") == 0) return GDK_ACTION_COPY;
  if (strcmp(name, "move") == 0) return GDK_ACTION_MOVE;
  if (strcmp(name, "link") == 0) return GDK_ACTION_LINK;
  return static_cast<GdkDragAction>(0);
}

static const gchar* action_name(GdkDragAction action) {
  switch (action) {
    case GDK_ACTION_MOVE:
      return "move";
    case GDK_ACTION_LINK:
      return "link";
    default:
      return "copy";
  }
}

// O widget em que o Flutter recebe o ponteiro: a GtkEventBox dentro da view
static GtkWidget* event_widget(GtkWidget* widget) {
  if (GTK_IS_EVENT_BOX(widget)) return widget;
  if (!GTK_IS_CONTAINER(widget)) return nullptr;
  g_autoptr(GList) children =
      gtk_container_get_children(GTK_CONTAINER(widget));
  for (GList* child = children; child != nullptr; child = child->next) {
    GtkWidget* found = event_widget(GTK_WIDGET(child->data));
    if (found != nullptr) return found;
  }
  return nullptr;
}

// Um evento do ponteiro sintético para o Flutter, em coordenadas da view
static void synthesize(ViewDnd* d, GdkEventType type, double x, double y) {
  GtkWidget* target = event_widget(GTK_WIDGET(d->view));
  if (target == nullptr) target = GTK_WIDGET(d->view);
  GdkWindow* window = gtk_widget_get_window(target);
  if (window == nullptr) return;
  GdkSeat* seat = gdk_display_get_default_seat(gtk_widget_get_display(target));
  GdkDevice* pointer = gdk_seat_get_pointer(seat);
  GdkEvent* event = gdk_event_new(type);
  guint32 time = g_get_monotonic_time() / 1000;
  if (type == GDK_MOTION_NOTIFY) {
    event->motion.window = GDK_WINDOW(g_object_ref(window));
    event->motion.time = time;
    event->motion.x = x;
    event->motion.y = y;
    event->motion.state = GDK_BUTTON1_MASK;
  } else {
    event->button.window = GDK_WINDOW(g_object_ref(window));
    event->button.time = time;
    event->button.x = x;
    event->button.y = y;
    event->button.button = 1;
    event->button.state = GDK_BUTTON1_MASK;
  }
  gdk_event_set_device(event, pointer);
  gdk_event_set_source_device(event, pointer);
  gtk_widget_event(target, event);
  gdk_event_free(event);
}

static bool own_drag(GtkWidget* widget, GdkDragContext* context) {
  return gtk_drag_get_source_widget(context) == widget;
}

static void send_over(ViewDnd* d);

static void over_reply_cb(GObject* object, GAsyncResult* result,
                          gpointer user_data) {
  ViewDnd* d = static_cast<ViewDnd*>(user_data);
  g_autoptr(FlMethodResponse) response = fl_method_channel_invoke_method_finish(
      FL_METHOD_CHANNEL(object), result, nullptr);
  d->pending = false;
  if (d->context == nullptr || d->dropping) return;
  FlValue* value = response != nullptr && FL_IS_METHOD_SUCCESS_RESPONSE(response)
                       ? fl_method_success_response_get_result(
                             FL_METHOD_SUCCESS_RESPONSE(response))
                       : nullptr;
  gdk_drag_status(d->context, parse_action(value), d->time);
  if (d->queued) {
    d->queued = false;
    send_over(d);
  }
}

// Pergunta ao Dart se aceita no ponto; um de cada vez, com o último ponto
static void send_over(ViewDnd* d) {
  if (d->pending) {
    d->queued = true;
    return;
  }
  d->pending = true;
  g_autoptr(FlValue) args = position_args(d);
  fl_method_channel_invoke_method(channel, "over", args, nullptr,
                                  over_reply_cb, d);
}

static void drop_reply_cb(GObject* object, GAsyncResult* result,
                          gpointer user_data) {
  ViewDnd* d = static_cast<ViewDnd*>(user_data);
  g_autoptr(FlMethodResponse) response = fl_method_channel_invoke_method_finish(
      FL_METHOD_CHANNEL(object), result, nullptr);
  FlValue* value = response != nullptr && FL_IS_METHOD_SUCCESS_RESPONSE(response)
                       ? fl_method_success_response_get_result(
                             FL_METHOD_SUCCESS_RESPONSE(response))
                       : nullptr;
  bool ok = value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_BOOL &&
            fl_value_get_bool(value);
  if (d->context != nullptr) {
    gtk_drag_finish(d->context, ok, FALSE, d->time);
  }
  reset(d);
}

static void send_drop(ViewDnd* d) {
  g_autoptr(FlValue) args = position_args(d);
  fl_value_set_string_take(
      args, "action",
      fl_value_new_string(
          action_name(gdk_drag_context_get_selected_action(d->context))));
  fl_method_channel_invoke_method(channel, "drop", args, nullptr,
                                  drop_reply_cb, d);
}

static void request(GtkWidget* widget, ViewDnd* d) {
  if (d->requested) return;
  d->requested = true;
  gtk_drag_get_data(widget, d->context,
                    gdk_atom_intern_static_string(kUriList), d->time);
}

static gboolean drag_motion_cb(GtkWidget* widget, GdkDragContext* context,
                               gint x, gint y, guint time, gpointer data) {
  ViewDnd* d = static_cast<ViewDnd*>(data);
  if (own_drag(widget, context)) {
    synthesize(d, GDK_MOTION_NOTIFY, x, y);
    gdk_drag_status(context, GDK_ACTION_MOVE, time);
    return TRUE;
  }
  if (!offers_uris(widget, context)) return FALSE;
  track(d, context, x, y, time);
  if (d->uris == nullptr) {
    // Os caminhos ainda não chegaram: recusa até o Dart poder decidir
    request(widget, d);
    gdk_drag_status(context, static_cast<GdkDragAction>(0), time);
    return TRUE;
  }
  send_over(d);
  return TRUE;
}

// O GTK manda o leave também logo antes do drop: os caminhos ficam até
// chegar outro arrastar ou o drop terminar
static void drag_leave_cb(GtkWidget* widget, GdkDragContext* context, guint,
                          gpointer data) {
  ViewDnd* d = static_cast<ViewDnd*>(data);
  // O próprio arrastar saiu: os alvos do Flutter deixam de estar embaixo
  if (own_drag(widget, context)) {
    synthesize(d, GDK_MOTION_NOTIFY, -1, -1);
    return;
  }
  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "view", fl_value_new_int(d->id));
  fl_method_channel_invoke_method(channel, "leave", args, nullptr, nullptr,
                                  nullptr);
}

static gboolean drag_drop_cb(GtkWidget* widget, GdkDragContext* context,
                             gint x, gint y, guint time, gpointer data) {
  ViewDnd* d = static_cast<ViewDnd*>(data);
  if (own_drag(widget, context)) {
    // De volta à própria view: o Draggable do Flutter solta ali
    synthesize(d, GDK_MOTION_NOTIFY, x, y);
    synthesize(d, GDK_BUTTON_RELEASE, x, y);
    d->released = true;
    gtk_drag_finish(context, TRUE, FALSE, time);
    return TRUE;
  }
  if (!offers_uris(widget, context)) return FALSE;
  track(d, context, x, y, time);
  d->dropping = true;
  if (d->uris != nullptr) {
    send_drop(d);
  } else {
    request(widget, d);
  }
  return TRUE;
}

static void drag_data_received_cb(GtkWidget*, GdkDragContext* context, gint,
                                  gint, GtkSelectionData* selection, guint,
                                  guint, gpointer data) {
  ViewDnd* d = static_cast<ViewDnd*>(data);
  if (context != d->context) return;
  g_clear_pointer(&d->uris, g_strfreev);
  d->uris = gtk_selection_data_get_uris(selection);
  if (d->uris == nullptr) d->uris = g_new0(gchar*, 1);
  if (d->dropping) {
    send_drop(d);
  } else {
    send_over(d);
  }
}

static void drag_data_get_cb(GtkWidget*, GdkDragContext*,
                             GtkSelectionData* selection, guint, guint,
                             gpointer data) {
  ViewDnd* d = static_cast<ViewDnd*>(data);
  if (d->source_uris != nullptr) {
    gtk_selection_data_set_uris(selection, d->source_uris);
  }
}

static void drag_end_cb(GtkWidget*, GdkDragContext*, gpointer data) {
  ViewDnd* d = static_cast<ViewDnd*>(data);
  g_clear_pointer(&d->source_uris, g_strfreev);
  // Soltou em outro lugar: o Draggable do Flutter termina fora da view
  if (!d->released) synthesize(d, GDK_BUTTON_RELEASE, -1, -1);
  d->released = false;
  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "view", fl_value_new_int(d->id));
  fl_method_channel_invoke_method(channel, "dragEnd", args, nullptr, nullptr,
                                  nullptr);
}

// Lê o PNG da memória para o cairo
struct PngReader {
  const uint8_t* data;
  size_t length;
  size_t offset;
};

static cairo_status_t read_png(void* closure, unsigned char* out,
                               unsigned int length) {
  PngReader* reader = static_cast<PngReader*>(closure);
  if (reader->offset + length > reader->length) return CAIRO_STATUS_READ_ERROR;
  memcpy(out, reader->data + reader->offset, length);
  reader->offset += length;
  return CAIRO_STATUS_SUCCESS;
}

// O ícone que o compositor desenha embaixo do ponteiro; sem um PNG válido,
// o padrão do GTK
static void set_icon(GdkDragContext* context, FlValue* icon, FlValue* x,
                     FlValue* y) {
  if (icon == nullptr || fl_value_get_type(icon) != FL_VALUE_TYPE_UINT8_LIST) {
    gtk_drag_set_icon_default(context);
    return;
  }
  PngReader reader = {fl_value_get_uint8_list(icon), fl_value_get_length(icon),
                      0};
  cairo_surface_t* surface =
      cairo_image_surface_create_from_png_stream(read_png, &reader);
  if (cairo_surface_status(surface) != CAIRO_STATUS_SUCCESS) {
    cairo_surface_destroy(surface);
    gtk_drag_set_icon_default(context);
    return;
  }
  auto coordinate = [](FlValue* value) {
    return value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_INT
               ? static_cast<double>(fl_value_get_int(value))
               : 0.0;
  };
  // O GTK põe o ponto de pega no avesso do deslocamento da superfície
  cairo_surface_set_device_offset(surface, -coordinate(x), -coordinate(y));
  gtk_drag_set_icon_surface(context, surface);
  cairo_surface_destroy(surface);
}

static void start_drag(ViewDnd* d, FlValue* uris, FlValue* icon, FlValue* x,
                       FlValue* y) {
  size_t count = fl_value_get_length(uris);
  g_strfreev(d->source_uris);
  d->released = false;
  d->source_uris = g_new0(gchar*, count + 1);
  for (size_t i = 0; i < count; i++) {
    d->source_uris[i] =
        g_strdup(fl_value_get_string(fl_value_get_list_value(uris, i)));
  }
  g_autoptr(GtkTargetList) targets = gtk_target_list_new(nullptr, 0);
  gtk_target_list_add_uri_targets(targets, 0);
  // Sem evento: o GTK usa o serial do botão que ainda está apertado
  GdkDragContext* context = gtk_drag_begin_with_coordinates(
      GTK_WIDGET(d->view), targets,
      static_cast<GdkDragAction>(GDK_ACTION_COPY | GDK_ACTION_MOVE |
                                 GDK_ACTION_LINK),
      1, nullptr, -1, -1);
  if (context != nullptr) set_icon(context, icon, x, y);
}

static void method_call_cb(FlMethodChannel*, FlMethodCall* call, gpointer) {
  FlValue* args = fl_method_call_get_args(call);
  if (strcmp(fl_method_call_get_name(call), "startDrag") != 0 ||
      args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  FlValue* view = fl_value_lookup_string(args, "view");
  FlValue* uris = fl_value_lookup_string(args, "uris");
  ViewDnd* d =
      view != nullptr && fl_value_get_type(view) == FL_VALUE_TYPE_INT
          ? static_cast<ViewDnd*>(g_hash_table_lookup(
                views, GINT_TO_POINTER(fl_value_get_int(view))))
          : nullptr;
  if (d == nullptr || uris == nullptr ||
      fl_value_get_type(uris) != FL_VALUE_TYPE_LIST) {
    fl_method_call_respond_error(call, "no_view", "view sem arrastar", nullptr,
                                 nullptr);
    return;
  }
  start_drag(d, uris, fl_value_lookup_string(args, "icon"),
             fl_value_lookup_string(args, "x"),
             fl_value_lookup_string(args, "y"));
  fl_method_call_respond_success(call, nullptr, nullptr);
}

void psito_dnd_attach(FlView* view) {
  if (channel == nullptr) {
    FlEngine* engine = fl_view_get_engine(view);
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    channel = fl_method_channel_new(fl_engine_get_binary_messenger(engine),
                                    "psito/dnd", FL_METHOD_CODEC(codec));
    fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                              nullptr, nullptr);
    views = g_hash_table_new(g_direct_hash, g_direct_equal);
  }
  int64_t id = fl_view_get_id(view);
  if (g_hash_table_contains(views, GINT_TO_POINTER(id))) return;

  // Vive tanto quanto a view, que vive tanto quanto o processo
  ViewDnd* d = g_new0(ViewDnd, 1);
  d->view = view;
  d->id = id;
  g_hash_table_insert(views, GINT_TO_POINTER(id), d);

  GtkWidget* widget = GTK_WIDGET(view);
  static const GtkTargetEntry targets[] = {
      {const_cast<gchar*>(kUriList), 0, 0},
  };
  gtk_drag_dest_set(widget, static_cast<GtkDestDefaults>(0), targets, 1,
                    static_cast<GdkDragAction>(GDK_ACTION_COPY |
                                               GDK_ACTION_MOVE |
                                               GDK_ACTION_LINK));
  g_signal_connect(widget, "drag-motion", G_CALLBACK(drag_motion_cb), d);
  g_signal_connect(widget, "drag-leave", G_CALLBACK(drag_leave_cb), d);
  g_signal_connect(widget, "drag-drop", G_CALLBACK(drag_drop_cb), d);
  g_signal_connect(widget, "drag-data-received",
                   G_CALLBACK(drag_data_received_cb), d);
  g_signal_connect(widget, "drag-data-get", G_CALLBACK(drag_data_get_cb), d);
  g_signal_connect(widget, "drag-end", G_CALLBACK(drag_end_cb), d);
}
