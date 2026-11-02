#include "outputs.h"

#include <gdk/gdkwayland.h>

#include <algorithm>
#include <cstring>
#include <string>
#include <vector>

#include "wlr-output-management-unstable-v1-client-protocol.h"

namespace {

struct Mode {
  zwlr_output_mode_v1* handle;
  int width = 0;
  int height = 0;
  int refresh = 0;
  bool preferred = false;
};

struct Head {
  zwlr_output_head_v1* handle;
  std::string name;
  std::string description;
  std::string make;
  std::string model;
  std::string serial;
  bool enabled = false;
  int x = 0;
  int y = 0;
  int transform = 0;
  double scale = 1;
  zwlr_output_mode_v1* current = nullptr;
  std::vector<Mode*> modes;
};

FlMethodChannel* channel = nullptr;
wl_display* display = nullptr;
zwlr_output_manager_v1* manager = nullptr;
std::vector<Head*> heads;
uint32_t serial = 0;

FlValue* head_value(const Head* head) {
  FlValue* map = fl_value_new_map();
  fl_value_set_string_take(map, "name", fl_value_new_string(head->name.c_str()));
  fl_value_set_string_take(map, "description",
                           fl_value_new_string(head->description.c_str()));
  fl_value_set_string_take(map, "make", fl_value_new_string(head->make.c_str()));
  fl_value_set_string_take(map, "model",
                           fl_value_new_string(head->model.c_str()));
  fl_value_set_string_take(map, "serial",
                           fl_value_new_string(head->serial.c_str()));
  fl_value_set_string_take(map, "enabled", fl_value_new_bool(head->enabled));
  fl_value_set_string_take(map, "x", fl_value_new_int(head->x));
  fl_value_set_string_take(map, "y", fl_value_new_int(head->y));
  fl_value_set_string_take(map, "transform", fl_value_new_int(head->transform));
  fl_value_set_string_take(map, "scale", fl_value_new_float(head->scale));
  FlValue* modes = fl_value_new_list();
  int current = -1;
  for (size_t i = 0; i < head->modes.size(); i++) {
    const Mode* mode = head->modes[i];
    if (mode->handle == head->current) current = i;
    FlValue* item = fl_value_new_map();
    fl_value_set_string_take(item, "width", fl_value_new_int(mode->width));
    fl_value_set_string_take(item, "height", fl_value_new_int(mode->height));
    fl_value_set_string_take(item, "refresh", fl_value_new_int(mode->refresh));
    fl_value_set_string_take(item, "preferred",
                             fl_value_new_bool(mode->preferred));
    fl_value_append_take(modes, item);
  }
  fl_value_set_string_take(map, "modes", modes);
  fl_value_set_string_take(map, "current", fl_value_new_int(current));
  return map;
}

FlValue* heads_value() {
  FlValue* list = fl_value_new_list();
  for (const Head* head : heads) fl_value_append_take(list, head_value(head));
  return list;
}

void mode_size(void* data, zwlr_output_mode_v1*, int32_t width,
               int32_t height) {
  auto* mode = static_cast<Mode*>(data);
  mode->width = width;
  mode->height = height;
}

void mode_refresh(void* data, zwlr_output_mode_v1*, int32_t refresh) {
  static_cast<Mode*>(data)->refresh = refresh;
}

void mode_preferred(void* data, zwlr_output_mode_v1*) {
  static_cast<Mode*>(data)->preferred = true;
}

void destroy_mode(Mode* mode) {
  if (zwlr_output_mode_v1_get_version(mode->handle) >=
      ZWLR_OUTPUT_MODE_V1_RELEASE_SINCE_VERSION) {
    zwlr_output_mode_v1_release(mode->handle);
  } else {
    zwlr_output_mode_v1_destroy(mode->handle);
  }
  delete mode;
}

void mode_finished(void* data, zwlr_output_mode_v1*) {
  auto* mode = static_cast<Mode*>(data);
  for (Head* head : heads) {
    auto& modes = head->modes;
    modes.erase(std::remove(modes.begin(), modes.end(), mode), modes.end());
    if (head->current == mode->handle) head->current = nullptr;
  }
  destroy_mode(mode);
}

const zwlr_output_mode_v1_listener mode_listener = {
    mode_size,
    mode_refresh,
    mode_preferred,
    mode_finished,
};

void head_name(void* data, zwlr_output_head_v1*, const char* name) {
  static_cast<Head*>(data)->name = name;
}

void head_description(void* data, zwlr_output_head_v1*,
                      const char* description) {
  static_cast<Head*>(data)->description = description;
}

void head_physical_size(void*, zwlr_output_head_v1*, int32_t, int32_t) {}

void head_mode(void* data, zwlr_output_head_v1*, zwlr_output_mode_v1* handle) {
  auto* mode = new Mode{handle};
  static_cast<Head*>(data)->modes.push_back(mode);
  zwlr_output_mode_v1_add_listener(handle, &mode_listener, mode);
}

void head_enabled(void* data, zwlr_output_head_v1*, int32_t enabled) {
  static_cast<Head*>(data)->enabled = enabled != 0;
}

void head_current_mode(void* data, zwlr_output_head_v1*,
                       zwlr_output_mode_v1* mode) {
  static_cast<Head*>(data)->current = mode;
}

void head_position(void* data, zwlr_output_head_v1*, int32_t x, int32_t y) {
  auto* head = static_cast<Head*>(data);
  head->x = x;
  head->y = y;
}

void head_transform(void* data, zwlr_output_head_v1*, int32_t transform) {
  static_cast<Head*>(data)->transform = transform;
}

void head_scale(void* data, zwlr_output_head_v1*, wl_fixed_t scale) {
  static_cast<Head*>(data)->scale = wl_fixed_to_double(scale);
}

void head_finished(void* data, zwlr_output_head_v1*) {
  auto* head = static_cast<Head*>(data);
  heads.erase(std::remove(heads.begin(), heads.end(), head), heads.end());
  // Os modos que sobraram não têm mais quem os anuncie
  for (Mode* mode : head->modes) destroy_mode(mode);
  if (zwlr_output_head_v1_get_version(head->handle) >=
      ZWLR_OUTPUT_HEAD_V1_RELEASE_SINCE_VERSION) {
    zwlr_output_head_v1_release(head->handle);
  } else {
    zwlr_output_head_v1_destroy(head->handle);
  }
  delete head;
}

void head_make(void* data, zwlr_output_head_v1*, const char* make) {
  static_cast<Head*>(data)->make = make;
}

void head_model(void* data, zwlr_output_head_v1*, const char* model) {
  static_cast<Head*>(data)->model = model;
}

void head_serial(void* data, zwlr_output_head_v1*, const char* value) {
  static_cast<Head*>(data)->serial = value;
}

void head_adaptive_sync(void*, zwlr_output_head_v1*, uint32_t) {}

const zwlr_output_head_v1_listener head_listener = {
    head_name,     head_description, head_physical_size, head_mode,
    head_enabled,  head_current_mode, head_position,      head_transform,
    head_scale,    head_finished,    head_make,           head_model,
    head_serial,   head_adaptive_sync,
};

void manager_head(void*, zwlr_output_manager_v1*, zwlr_output_head_v1* handle) {
  auto* head = new Head{handle};
  heads.push_back(head);
  zwlr_output_head_v1_add_listener(handle, &head_listener, head);
}

// O protocolo agrupa as mudanças até o done
void manager_done(void*, zwlr_output_manager_v1*, uint32_t value) {
  serial = value;
  if (channel == nullptr) return;
  g_autoptr(FlValue) list = heads_value();
  fl_method_channel_invoke_method(channel, "changed", list, nullptr, nullptr,
                                  nullptr);
}

void manager_finished(void*, zwlr_output_manager_v1* m) {
  zwlr_output_manager_v1_destroy(m);
  manager = nullptr;
}

const zwlr_output_manager_v1_listener manager_listener = {
    manager_head,
    manager_done,
    manager_finished,
};

// Quem pediu espera a resposta do compositor
void configuration_respond(void* data, zwlr_output_configuration_v1* config,
                           const char* result) {
  auto* call = static_cast<FlMethodCall*>(data);
  g_autoptr(FlValue) value = fl_value_new_string(result);
  fl_method_call_respond_success(call, value, nullptr);
  g_object_unref(call);
  zwlr_output_configuration_v1_destroy(config);
}

void configuration_succeeded(void* data, zwlr_output_configuration_v1* config) {
  configuration_respond(data, config, "ok");
}

void configuration_failed(void* data, zwlr_output_configuration_v1* config) {
  configuration_respond(data, config, "failed");
}

void configuration_cancelled(void* data, zwlr_output_configuration_v1* config) {
  configuration_respond(data, config, "cancelled");
}

const zwlr_output_configuration_v1_listener configuration_listener = {
    configuration_succeeded,
    configuration_failed,
    configuration_cancelled,
};

Head* head_named(const char* name) {
  for (Head* head : heads) {
    if (head->name == name) return head;
  }
  return nullptr;
}

Mode* mode_matching(const Head* head, int width, int height, int refresh) {
  for (Mode* mode : head->modes) {
    if (mode->width == width && mode->height == height &&
        mode->refresh == refresh) {
      return mode;
    }
  }
  return nullptr;
}

int int_field(FlValue* map, const char* name) {
  FlValue* value = fl_value_lookup_string(map, name);
  return value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_INT
             ? fl_value_get_int(value)
             : 0;
}

bool bool_field(FlValue* map, const char* name) {
  FlValue* value = fl_value_lookup_string(map, name);
  return value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_BOOL &&
         fl_value_get_bool(value);
}

// Monta a configuração e pede ao compositor. Um monitor que saiu ou um modo que
// não existe mais responde "cancelled", sem pedir nada
void apply(FlMethodCall* call, FlValue* args) {
  FlValue* list = fl_value_lookup_string(args, "heads");
  if (manager == nullptr || list == nullptr ||
      fl_value_get_type(list) != FL_VALUE_TYPE_LIST) {
    g_autoptr(FlValue) value = fl_value_new_string("failed");
    fl_method_call_respond_success(call, value, nullptr);
    return;
  }
  zwlr_output_configuration_v1* config =
      zwlr_output_manager_v1_create_configuration(manager, serial);
  for (size_t i = 0; i < fl_value_get_length(list); i++) {
    FlValue* item = fl_value_get_list_value(list, i);
    FlValue* name = fl_value_lookup_string(item, "name");
    Head* head = name != nullptr &&
                         fl_value_get_type(name) == FL_VALUE_TYPE_STRING
                     ? head_named(fl_value_get_string(name))
                     : nullptr;
    Mode* mode = nullptr;
    bool enabled = bool_field(item, "enabled");
    if (head != nullptr && enabled) {
      mode = mode_matching(head, int_field(item, "width"),
                           int_field(item, "height"),
                           int_field(item, "refresh"));
    }
    if (head == nullptr || (enabled && mode == nullptr)) {
      zwlr_output_configuration_v1_destroy(config);
      g_autoptr(FlValue) value = fl_value_new_string("cancelled");
      fl_method_call_respond_success(call, value, nullptr);
      return;
    }
    if (!enabled) {
      zwlr_output_configuration_v1_disable_head(config, head->handle);
      continue;
    }
    zwlr_output_configuration_head_v1* config_head =
        zwlr_output_configuration_v1_enable_head(config, head->handle);
    zwlr_output_configuration_head_v1_set_mode(config_head, mode->handle);
    zwlr_output_configuration_head_v1_set_position(
        config_head, int_field(item, "x"), int_field(item, "y"));
    zwlr_output_configuration_head_v1_set_transform(
        config_head, int_field(item, "transform"));
    FlValue* scale = fl_value_lookup_string(item, "scale");
    if (scale != nullptr && fl_value_get_type(scale) == FL_VALUE_TYPE_FLOAT) {
      zwlr_output_configuration_head_v1_set_scale(
          config_head, wl_fixed_from_double(fl_value_get_float(scale)));
    }
  }
  zwlr_output_configuration_v1_add_listener(config, &configuration_listener,
                                            g_object_ref(call));
  if (bool_field(args, "test")) {
    zwlr_output_configuration_v1_test(config);
  } else {
    zwlr_output_configuration_v1_apply(config);
  }
  wl_display_flush(display);
}

void method_call(FlMethodChannel*, FlMethodCall* call, gpointer) {
  const gchar* method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);
  if (strcmp(method, "list") == 0) {
    g_autoptr(FlValue) list = heads_value();
    fl_method_call_respond_success(call, list, nullptr);
  } else if (strcmp(method, "apply") == 0 && args != nullptr &&
             fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
    apply(call, args);
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
  }
}

void registry_global(void*, wl_registry* registry, uint32_t name,
                     const char* interface, uint32_t version) {
  if (strcmp(interface, zwlr_output_manager_v1_interface.name) == 0) {
    manager = static_cast<zwlr_output_manager_v1*>(wl_registry_bind(
        registry, name, &zwlr_output_manager_v1_interface,
        version < 4 ? version : 4));
    zwlr_output_manager_v1_add_listener(manager, &manager_listener, nullptr);
  }
}

void registry_global_remove(void*, wl_registry*, uint32_t) {}

const wl_registry_listener registry_listener = {
    registry_global,
    registry_global_remove,
};

}  // namespace

void outputs_init(FlBinaryMessenger* messenger) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  channel = fl_method_channel_new(messenger, "psito/outputs",
                                  FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call, nullptr,
                                            nullptr);
  GdkDisplay* gdk_display = gdk_display_get_default();
  if (!GDK_IS_WAYLAND_DISPLAY(gdk_display)) return;
  display = gdk_wayland_display_get_wl_display(gdk_display);
  wl_registry* registry = wl_display_get_registry(display);
  wl_registry_add_listener(registry, &registry_listener, nullptr);
  // Duas idas e voltas: o global, e depois os monitores com os modos, para o
  // Dart já achar a lista no primeiro pedido
  wl_display_roundtrip(display);
  wl_display_roundtrip(display);
  if (manager == nullptr) {
    g_warning("outputs: o compositor não tem o zwlr_output_manager_v1");
  }
}
