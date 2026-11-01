// packages/psito_runtime/linux/psito_clipboard.cc
//
// A área de transferência de arquivos, sobre o GtkClipboard. O Clipboard do
// Flutter só tem texto. O canal psito/clipboard leva os formatos prontos,
// que o Dart monta e lê (lib/src/clipboard.dart):
//   Dart -> C: "set" {gnome, uris, text}: passa a oferecer os três
//              "read" <alvo> -> os bytes do alvo, ou null
//              "clear": a oferta vira um texto vazio (quem cola um recortado
//              não é o dono, e o gtk_clipboard_clear só vale para o dono)
//   C -> Dart: "changed": outra oferta pode estar valendo
#include "include/psito_runtime/psito_clipboard.h"

#include <gtk/gtk.h>

#include <cstring>

enum Target { kGnome, kUris, kText };

struct Offer {
  gchar* gnome;
  gchar* uris;
  gchar* text;
};

static FlMethodChannel* channel = nullptr;

static GtkClipboard* clipboard() {
  return gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
}

static void notify_changed() {
  fl_method_channel_invoke_method(channel, "changed", nullptr, nullptr, nullptr,
                                  nullptr);
}

static void offer_get_cb(GtkClipboard*, GtkSelectionData* data, guint info,
                         gpointer user_data) {
  Offer* offer = static_cast<Offer*>(user_data);
  if (info == kText) {
    gtk_selection_data_set_text(data, offer->text, -1);
    return;
  }
  const gchar* value = info == kGnome ? offer->gnome : offer->uris;
  gtk_selection_data_set(data, gtk_selection_data_get_target(data), 8,
                         reinterpret_cast<const guchar*>(value),
                         strlen(value));
}

// Outra oferta tomou o lugar desta, deste processo ou de outro
static void offer_clear_cb(GtkClipboard*, gpointer user_data) {
  Offer* offer = static_cast<Offer*>(user_data);
  g_free(offer->gnome);
  g_free(offer->uris);
  g_free(offer->text);
  g_free(offer);
  notify_changed();
}

static void owner_change_cb(GtkClipboard*, GdkEvent*, gpointer) {
  notify_changed();
}

static const gchar* string_arg(FlValue* args, const gchar* key) {
  FlValue* value = fl_value_lookup_string(args, key);
  return value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_STRING
             ? fl_value_get_string(value)
             : "";
}

static void set_offer(FlValue* args) {
  Offer* offer = g_new0(Offer, 1);
  offer->gnome = g_strdup(string_arg(args, "gnome"));
  offer->uris = g_strdup(string_arg(args, "uris"));
  offer->text = g_strdup(string_arg(args, "text"));
  GtkTargetList* list = gtk_target_list_new(nullptr, 0);
  gtk_target_list_add(list, gdk_atom_intern_static_string(
                                "x-special/gnome-copied-files"),
                      0, kGnome);
  gtk_target_list_add(list, gdk_atom_intern_static_string("text/uri-list"), 0,
                      kUris);
  gtk_target_list_add_text_targets(list, kText);
  int count = 0;
  GtkTargetEntry* targets = gtk_target_table_new_from_list(list, &count);
  if (!gtk_clipboard_set_with_data(clipboard(), targets, count, offer_get_cb,
                                   offer_clear_cb, offer)) {
    g_free(offer->gnome);
    g_free(offer->uris);
    g_free(offer->text);
    g_free(offer);
  }
  gtk_target_table_free(targets, count);
  gtk_target_list_unref(list);
}

static void contents_cb(GtkClipboard*, GtkSelectionData* data,
                        gpointer user_data) {
  FlMethodCall* call = FL_METHOD_CALL(user_data);
  gint length = data != nullptr ? gtk_selection_data_get_length(data) : -1;
  g_autoptr(FlValue) result =
      length >= 0 ? fl_value_new_uint8_list(gtk_selection_data_get_data(data),
                                            length)
                  : fl_value_new_null();
  fl_method_call_respond_success(call, result, nullptr);
  g_object_unref(call);
}

static void method_call_cb(FlMethodChannel*, FlMethodCall* call, gpointer) {
  const gchar* method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);
  if (strcmp(method, "set") == 0 && args != nullptr &&
      fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
    set_offer(args);
    fl_method_call_respond_success(call, nullptr, nullptr);
  } else if (strcmp(method, "read") == 0 && args != nullptr &&
             fl_value_get_type(args) == FL_VALUE_TYPE_STRING) {
    gtk_clipboard_request_contents(clipboard(),
                                   gdk_atom_intern(fl_value_get_string(args),
                                                   FALSE),
                                   contents_cb, g_object_ref(call));
  } else if (strcmp(method, "clear") == 0) {
    gtk_clipboard_set_text(clipboard(), "", 0);
    fl_method_call_respond_success(call, nullptr, nullptr);
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
  }
}

void psito_clipboard_register(FlBinaryMessenger* messenger) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  channel = fl_method_channel_new(messenger, "psito/clipboard",
                                  FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb, nullptr,
                                            nullptr);
  g_signal_connect(clipboard(), "owner-change", G_CALLBACK(owner_change_cb),
                   nullptr);
}
