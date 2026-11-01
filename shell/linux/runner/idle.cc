#include "idle.h"

#include <gdk/gdkwayland.h>
#include <string.h>

#include "ext-idle-notify-v1-client-protocol.h"

namespace {

FlMethodChannel* channel = nullptr;
ext_idle_notifier_v1* notifier = nullptr;
ext_idle_notification_v1* notification = nullptr;

void idled(void*, ext_idle_notification_v1*) {
  fl_method_channel_invoke_method(channel, "idled", nullptr, nullptr, nullptr,
                                  nullptr);
}

void resumed(void*, ext_idle_notification_v1*) {}

const ext_idle_notification_v1_listener notification_listener = {idled,
                                                                 resumed};

void watch(int64_t seconds) {
  if (notification != nullptr) {
    ext_idle_notification_v1_destroy(notification);
    notification = nullptr;
  }
  if (seconds <= 0 || notifier == nullptr) return;
  GdkDisplay* display = gdk_display_get_default();
  notification = ext_idle_notifier_v1_get_idle_notification(
      notifier, seconds * 1000,
      gdk_wayland_seat_get_wl_seat(gdk_display_get_default_seat(display)));
  ext_idle_notification_v1_add_listener(notification, &notification_listener,
                                        nullptr);
}

void method_call(FlMethodChannel*, FlMethodCall* call, gpointer) {
  FlValue* args = fl_method_call_get_args(call);
  if (g_strcmp0(fl_method_call_get_name(call), "watch") != 0 ||
      fl_value_get_type(args) != FL_VALUE_TYPE_INT) {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  watch(fl_value_get_int(args));
  fl_method_call_respond_success(call, nullptr, nullptr);
}

void registry_global(void*, wl_registry* registry, uint32_t name,
                     const char* interface, uint32_t) {
  if (strcmp(interface, ext_idle_notifier_v1_interface.name) == 0) {
    notifier = static_cast<ext_idle_notifier_v1*>(wl_registry_bind(
        registry, name, &ext_idle_notifier_v1_interface, 1));
  }
}

void registry_global_remove(void*, wl_registry*, uint32_t) {}

const wl_registry_listener registry_listener = {registry_global,
                                                registry_global_remove};

}  // namespace

void idle_init(FlBinaryMessenger* messenger) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  channel = fl_method_channel_new(messenger, "psito/idle",
                                  FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call, nullptr,
                                            nullptr);
  GdkDisplay* display = gdk_display_get_default();
  if (!GDK_IS_WAYLAND_DISPLAY(display)) return;
  wl_display* wl = gdk_wayland_display_get_wl_display(display);
  wl_registry* registry = wl_display_get_registry(wl);
  wl_registry_add_listener(registry, &registry_listener, nullptr);
  wl_display_roundtrip(wl);
}
