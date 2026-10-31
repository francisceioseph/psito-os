#include "toplevels.h"

#include <gdk/gdkwayland.h>

#include <cstring>
#include <map>
#include <string>

#include "wlr-foreign-toplevel-management-unstable-v1-client-protocol.h"

namespace {

struct Toplevel {
  int64_t id;
  zwlr_foreign_toplevel_handle_v1* handle;
  std::string title;
  std::string app_id;
  bool activated = false;
  bool minimized = false;
  bool maximized = false;
};

FlMethodChannel* channel = nullptr;
wl_display* display = nullptr;
wl_seat* seat = nullptr;
zwlr_foreign_toplevel_manager_v1* manager = nullptr;
std::map<int64_t, Toplevel*> toplevels;
int64_t next_id = 1;

FlValue* to_value(const Toplevel* t) {
  FlValue* map = fl_value_new_map();
  fl_value_set_string_take(map, "id", fl_value_new_int(t->id));
  fl_value_set_string_take(map, "title", fl_value_new_string(t->title.c_str()));
  fl_value_set_string_take(map, "appId",
                           fl_value_new_string(t->app_id.c_str()));
  fl_value_set_string_take(map, "activated", fl_value_new_bool(t->activated));
  fl_value_set_string_take(map, "minimized", fl_value_new_bool(t->minimized));
  fl_value_set_string_take(map, "maximized", fl_value_new_bool(t->maximized));
  return map;
}

void send(const char* method, FlValue* args) {
  fl_method_channel_invoke_method(channel, method, args, nullptr, nullptr,
                                  nullptr);
  fl_value_unref(args);
}

void handle_title(void* data, zwlr_foreign_toplevel_handle_v1*,
                  const char* title) {
  static_cast<Toplevel*>(data)->title = title;
}

void handle_app_id(void* data, zwlr_foreign_toplevel_handle_v1*,
                   const char* app_id) {
  static_cast<Toplevel*>(data)->app_id = app_id;
}

void handle_output_enter(void*, zwlr_foreign_toplevel_handle_v1*, wl_output*) {}
void handle_output_leave(void*, zwlr_foreign_toplevel_handle_v1*, wl_output*) {}

void handle_state(void* data, zwlr_foreign_toplevel_handle_v1*,
                  wl_array* state) {
  auto* t = static_cast<Toplevel*>(data);
  t->activated = t->minimized = t->maximized = false;
  auto* values = static_cast<uint32_t*>(state->data);
  for (size_t i = 0; i < state->size / sizeof(uint32_t); i++) {
    switch (values[i]) {
      case ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_ACTIVATED:
        t->activated = true;
        break;
      case ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MINIMIZED:
        t->minimized = true;
        break;
      case ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MAXIMIZED:
        t->maximized = true;
        break;
    }
  }
}

// O protocolo agrupa as mudanças até o done: só aí o Dart fica sabendo
void handle_done(void* data, zwlr_foreign_toplevel_handle_v1*) {
  send("changed", to_value(static_cast<Toplevel*>(data)));
}

void handle_closed(void* data, zwlr_foreign_toplevel_handle_v1* handle) {
  auto* t = static_cast<Toplevel*>(data);
  send("closed", fl_value_new_int(t->id));
  toplevels.erase(t->id);
  zwlr_foreign_toplevel_handle_v1_destroy(handle);
  delete t;
}

void handle_parent(void*, zwlr_foreign_toplevel_handle_v1*,
                   zwlr_foreign_toplevel_handle_v1*) {}

const zwlr_foreign_toplevel_handle_v1_listener handle_listener = {
    handle_title,  handle_app_id, handle_output_enter, handle_output_leave,
    handle_state,  handle_done,   handle_closed,       handle_parent,
};

void manager_toplevel(void*, zwlr_foreign_toplevel_manager_v1*,
                      zwlr_foreign_toplevel_handle_v1* handle) {
  auto* t = new Toplevel{next_id++, handle};
  toplevels[t->id] = t;
  zwlr_foreign_toplevel_handle_v1_add_listener(handle, &handle_listener, t);
}

void manager_finished(void*, zwlr_foreign_toplevel_manager_v1* m) {
  zwlr_foreign_toplevel_manager_v1_destroy(m);
  manager = nullptr;
}

const zwlr_foreign_toplevel_manager_v1_listener manager_listener = {
    manager_toplevel,
    manager_finished,
};

void registry_global(void*, wl_registry* registry, uint32_t name,
                     const char* interface, uint32_t version) {
  if (strcmp(interface, zwlr_foreign_toplevel_manager_v1_interface.name) ==
      0) {
    manager = static_cast<zwlr_foreign_toplevel_manager_v1*>(wl_registry_bind(
        registry, name, &zwlr_foreign_toplevel_manager_v1_interface,
        version < 3 ? version : 3));
    zwlr_foreign_toplevel_manager_v1_add_listener(manager, &manager_listener,
                                                  nullptr);
  }
}

void registry_global_remove(void*, wl_registry*, uint32_t) {}

const wl_registry_listener registry_listener = {
    registry_global,
    registry_global_remove,
};

Toplevel* lookup(FlValue* id) {
  if (id == nullptr || fl_value_get_type(id) != FL_VALUE_TYPE_INT) {
    return nullptr;
  }
  auto it = toplevels.find(fl_value_get_int(id));
  return it == toplevels.end() ? nullptr : it->second;
}

void method_call_cb(FlMethodChannel*, FlMethodCall* call, gpointer) {
  const gchar* method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);

  if (strcmp(method, "list") == 0) {
    g_autoptr(FlValue) list = fl_value_new_list();
    for (auto& [id, t] : toplevels) fl_value_append_take(list, to_value(t));
    fl_method_call_respond_success(call, list, nullptr);
    return;
  }

  Toplevel* t = nullptr;
  if (strcmp(method, "minimize") == 0) {
    t = args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP
            ? lookup(fl_value_lookup_string(args, "id"))
            : nullptr;
  } else {
    t = lookup(args);
  }

  if (strcmp(method, "activate") == 0 && t != nullptr && seat != nullptr) {
    zwlr_foreign_toplevel_handle_v1_activate(t->handle, seat);
  } else if (strcmp(method, "minimize") == 0 && t != nullptr) {
    FlValue* minimized = fl_value_lookup_string(args, "minimized");
    if (minimized != nullptr && fl_value_get_bool(minimized)) {
      zwlr_foreign_toplevel_handle_v1_set_minimized(t->handle);
    } else {
      zwlr_foreign_toplevel_handle_v1_unset_minimized(t->handle);
    }
  } else if (strcmp(method, "close") == 0 && t != nullptr) {
    zwlr_foreign_toplevel_handle_v1_close(t->handle);
  } else if (t == nullptr && (strcmp(method, "activate") == 0 ||
                              strcmp(method, "minimize") == 0 ||
                              strcmp(method, "close") == 0)) {
    // A janela fechou no meio do caminho: nada a fazer
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  wl_display_flush(display);
  fl_method_call_respond_success(call, nullptr, nullptr);
}

}  // namespace

void toplevels_init(FlBinaryMessenger* messenger) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  channel = fl_method_channel_new(messenger, "psito/toplevels",
                                  FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb, nullptr,
                                            nullptr);

  GdkDisplay* gdk_display = gdk_display_get_default();
  if (!GDK_IS_WAYLAND_DISPLAY(gdk_display)) {
    g_warning("toplevels: sem Wayland, a dock não vai ver as janelas");
    return;
  }
  display = gdk_wayland_display_get_wl_display(gdk_display);
  seat = gdk_wayland_seat_get_wl_seat(gdk_display_get_default_seat(gdk_display));
  wl_registry* registry = wl_display_get_registry(display);
  wl_registry_add_listener(registry, &registry_listener, nullptr);
  // Uma ida e volta para saber se o compositor tem o protocolo; as janelas
  // chegam depois, pelo laço do GDK
  wl_display_roundtrip(display);
  if (manager == nullptr) {
    g_warning("toplevels: o compositor não tem o "
              "zwlr_foreign_toplevel_manager_v1");
  }
}
