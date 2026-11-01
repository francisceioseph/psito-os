#include "clipboard_keeper.h"

#include <errno.h>
#include <fcntl.h>
#include <gdk/gdkwayland.h>
#include <glib-unix.h>
#include <pthread.h>
#include <signal.h>
#include <time.h>
#include <unistd.h>

#include <algorithm>
#include <cstring>
#include <map>
#include <string>
#include <vector>

#include "wlr-data-control-unstable-v1-client-protocol.h"

namespace {

// Uma cópia maior que isso fica de fora: são cinco no histórico, na memória
// do shell
const size_t kMaxBytes = 16 * 1024 * 1024;
// Um app travado não pode segurar a leitura
const guint kReadTimeoutMs = 2000;
// Quem copia de novo pode destruir a oferta antiga antes de criar a nova: um
// "lost" na hora faria a cópia anterior voltar por cima da nova
const guint kLostDelayMs = 200;

struct Read {
  std::string mime;
  int fd;
  guint watch;
  std::string data;
};

// Uma oferta chegando: os tipos vêm antes do "selection"
struct Offer {
  zwlr_data_control_offer_v1* offer;
  std::vector<std::string> mimes;
};

struct Source {
  zwlr_data_control_source_v1* source;
  std::map<std::string, GBytes*> formats;
};

struct Write {
  int fd;
  GBytes* bytes;
  size_t offset;
};

FlMethodChannel* channel = nullptr;
wl_display* display = nullptr;
wl_seat* seat = nullptr;
zwlr_data_control_manager_v1* manager = nullptr;
zwlr_data_control_device_v1* device = nullptr;

std::vector<Read*> reads;
std::vector<Read*> finished_reads;
size_t read_total = 0;
guint read_timeout = 0;
guint lost_timeout = 0;
// O dono fechou com a leitura em andamento: avisa depois dela
bool lost_after_reads = false;
// O próximo "selection" é a nossa própria oferta
bool own_pending = false;

void send(const char* method, FlValue* args) {
  fl_method_channel_invoke_method(channel, method, args, nullptr, nullptr,
                                  nullptr);
  if (args != nullptr) fl_value_unref(args);
}

void stop_read(Read* read) {
  g_source_remove(read->watch);
  close(read->fd);
}

void forget_reads() {
  for (Read* read : reads) {
    stop_read(read);
    delete read;
  }
  reads.clear();
  for (Read* read : finished_reads) delete read;
  finished_reads.clear();
  read_total = 0;
  if (read_timeout != 0) g_source_remove(read_timeout);
  read_timeout = 0;
}

void finish_reads() {
  if (finished_reads.empty()) {
    send("skipped", nullptr);
  } else {
    FlValue* formats = fl_value_new_map();
    for (Read* read : finished_reads) {
      fl_value_set_string_take(
          formats, read->mime.c_str(),
          fl_value_new_uint8_list(
              reinterpret_cast<const uint8_t*>(read->data.data()),
              read->data.size()));
    }
    send("copied", formats);
  }
  forget_reads();
  if (lost_after_reads) send("lost", nullptr);
  lost_after_reads = false;
}

gboolean read_timeout_cb(gpointer) {
  read_timeout = 0;
  // Fica o que já chegou inteiro
  finish_reads();
  return G_SOURCE_REMOVE;
}

gboolean read_cb(gint fd, GIOCondition, gpointer user_data) {
  Read* read = static_cast<Read*>(user_data);
  char buffer[65536];
  ssize_t count = ::read(fd, buffer, sizeof(buffer));
  if (count < 0 && (errno == EAGAIN || errno == EINTR)) {
    return G_SOURCE_CONTINUE;
  }
  if (count > 0) {
    read->data.append(buffer, count);
    read_total += count;
    if (read_total <= kMaxBytes) return G_SOURCE_CONTINUE;
    // Grande demais: nem um pedaço fica
    forget_reads();
    send("skipped", nullptr);
    if (lost_after_reads) send("lost", nullptr);
    lost_after_reads = false;
    return G_SOURCE_REMOVE;
  }
  close(fd);
  reads.erase(std::find(reads.begin(), reads.end(), read));
  if (count == 0) {
    finished_reads.push_back(read);
  } else {
    delete read;
  }
  if (reads.empty()) finish_reads();
  return G_SOURCE_REMOVE;
}

// O que não precisa ser guardado: os nomes internos do X11 e, com um PNG na
// oferta, os outros formatos da mesma imagem, que o app teria de codificar
bool wanted(const std::string& mime, const std::vector<std::string>& all) {
  if (mime == "TARGETS" || mime == "MULTIPLE" || mime == "TIMESTAMP" ||
      mime == "SAVE_TARGETS") {
    return false;
  }
  if (mime.rfind("image/", 0) == 0 && mime != "image/png") {
    return std::find(all.begin(), all.end(), "image/png") == all.end();
  }
  return true;
}

void start_reads(Offer* offer) {
  for (const std::string& mime : offer->mimes) {
    if (!wanted(mime, offer->mimes)) continue;
    int fds[2];
    if (pipe2(fds, O_CLOEXEC | O_NONBLOCK) != 0) continue;
    zwlr_data_control_offer_v1_receive(offer->offer, mime.c_str(), fds[1]);
    close(fds[1]);
    Read* read = new Read{mime, fds[0], 0, {}};
    read->watch = g_unix_fd_add(fds[0], (GIOCondition)(G_IO_IN | G_IO_HUP), read_cb, read);
    reads.push_back(read);
  }
  if (reads.empty()) {
    send("skipped", nullptr);
    return;
  }
  read_timeout = g_timeout_add(kReadTimeoutMs, read_timeout_cb, nullptr);
  wl_display_flush(display);
}

void offer_offer(void* data, zwlr_data_control_offer_v1*, const char* mime) {
  static_cast<Offer*>(data)->mimes.push_back(mime);
}

const zwlr_data_control_offer_v1_listener offer_listener = {
    offer_offer,
};

void device_data_offer(void*, zwlr_data_control_device_v1*,
                       zwlr_data_control_offer_v1* id) {
  zwlr_data_control_offer_v1_add_listener(id, &offer_listener,
                                          new Offer{id, {}});
}

gboolean lost_timeout_cb(gpointer) {
  lost_timeout = 0;
  if (reads.empty()) {
    send("lost", nullptr);
  } else {
    lost_after_reads = true;
  }
  return G_SOURCE_REMOVE;
}

void device_selection(void*, zwlr_data_control_device_v1*,
                      zwlr_data_control_offer_v1* id) {
  if (lost_timeout != 0) g_source_remove(lost_timeout);
  lost_timeout = 0;
  if (id == nullptr) {
    lost_timeout = g_timeout_add(kLostDelayMs, lost_timeout_cb, nullptr);
    return;
  }
  Offer* offer =
      static_cast<Offer*>(zwlr_data_control_offer_v1_get_user_data(id));
  if (own_pending) {
    own_pending = false;
  } else {
    forget_reads();
    lost_after_reads = false;
    // Um gerenciador de senhas marca o que não deve ficar guardado
    const auto& mimes = offer->mimes;
    if (std::find(mimes.begin(), mimes.end(), "x-kde-passwordManagerHint") !=
        mimes.end()) {
      send("skipped", nullptr);
    } else {
      start_reads(offer);
    }
  }
  // O pipe já está com o dono: a oferta não é mais necessária
  zwlr_data_control_offer_v1_destroy(id);
  delete offer;
}

void device_finished(void*, zwlr_data_control_device_v1* d) {
  zwlr_data_control_device_v1_destroy(d);
  device = nullptr;
}

void device_primary_selection(void*, zwlr_data_control_device_v1*,
                              zwlr_data_control_offer_v1*) {}

const zwlr_data_control_device_v1_listener device_listener = {
    device_data_offer,
    device_selection,
    device_finished,
    device_primary_selection,
};

// Quem lê o pipe pode fechar antes do fim. O SIGPIPE fica bloqueado só nesta
// escrita, sem mudar o que os apps abertos pelo shell herdam
ssize_t write_quietly(int fd, const void* data, size_t size) {
  sigset_t pipe_set, old_set;
  sigemptyset(&pipe_set);
  sigaddset(&pipe_set, SIGPIPE);
  pthread_sigmask(SIG_BLOCK, &pipe_set, &old_set);
  ssize_t count = write(fd, data, size);
  if (count < 0 && errno == EPIPE) {
    const timespec zero = {0, 0};
    sigtimedwait(&pipe_set, nullptr, &zero);
    errno = EPIPE;
  }
  int saved = errno;
  pthread_sigmask(SIG_SETMASK, &old_set, nullptr);
  errno = saved;
  return count;
}

gboolean write_cb(gint fd, GIOCondition, gpointer user_data) {
  Write* out = static_cast<Write*>(user_data);
  gsize size = 0;
  const char* bytes =
      static_cast<const char*>(g_bytes_get_data(out->bytes, &size));
  ssize_t count = write_quietly(fd, bytes + out->offset, size - out->offset);
  if (count < 0 && (errno == EAGAIN || errno == EINTR)) {
    return G_SOURCE_CONTINUE;
  }
  if (count > 0) {
    out->offset += count;
    if (out->offset < size) return G_SOURCE_CONTINUE;
  }
  close(fd);
  g_bytes_unref(out->bytes);
  delete out;
  return G_SOURCE_REMOVE;
}

void source_send(void* data, zwlr_data_control_source_v1*, const char* mime,
                 int32_t fd) {
  auto& formats = static_cast<Source*>(data)->formats;
  auto it = formats.find(mime);
  if (it == formats.end()) {
    close(fd);
    return;
  }
  fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK);
  Write* out = new Write{fd, g_bytes_ref(it->second), 0};
  g_unix_fd_add(fd, (GIOCondition)(G_IO_OUT | G_IO_ERR), write_cb, out);
}

void source_cancelled(void* data, zwlr_data_control_source_v1* id) {
  Source* source = static_cast<Source*>(data);
  for (auto& format : source->formats) g_bytes_unref(format.second);
  zwlr_data_control_source_v1_destroy(id);
  delete source;
}

const zwlr_data_control_source_v1_listener source_listener = {
    source_send,
    source_cancelled,
};

void set_offer(FlValue* formats) {
  Source* source = new Source{
      zwlr_data_control_manager_v1_create_data_source(manager), {}};
  zwlr_data_control_source_v1_add_listener(source->source, &source_listener,
                                           source);
  for (size_t i = 0; i < fl_value_get_length(formats); i++) {
    FlValue* key = fl_value_get_map_key(formats, i);
    FlValue* value = fl_value_get_map_value(formats, i);
    if (fl_value_get_type(key) != FL_VALUE_TYPE_STRING ||
        fl_value_get_type(value) != FL_VALUE_TYPE_UINT8_LIST) {
      continue;
    }
    source->formats[fl_value_get_string(key)] = g_bytes_new(
        fl_value_get_uint8_list(value), fl_value_get_length(value));
    zwlr_data_control_source_v1_offer(source->source, fl_value_get_string(key));
  }
  forget_reads();
  lost_after_reads = false;
  own_pending = true;
  zwlr_data_control_device_v1_set_selection(device, source->source);
  wl_display_flush(display);
}

void method_call_cb(FlMethodChannel*, FlMethodCall* call, gpointer) {
  const gchar* method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);
  if (strcmp(method, "offer") == 0 && args != nullptr &&
      fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
    if (device != nullptr) set_offer(args);
    fl_method_call_respond_success(call, nullptr, nullptr);
  } else if (strcmp(method, "clear") == 0) {
    if (device != nullptr) {
      forget_reads();
      lost_after_reads = false;
      zwlr_data_control_device_v1_set_selection(device, nullptr);
      wl_display_flush(display);
    }
    fl_method_call_respond_success(call, nullptr, nullptr);
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
  }
}

void registry_global(void*, wl_registry* registry, uint32_t name,
                     const char* interface, uint32_t) {
  // A versão 1 basta: sem a seleção primária, que é a do botão do meio
  if (strcmp(interface, zwlr_data_control_manager_v1_interface.name) == 0) {
    manager = static_cast<zwlr_data_control_manager_v1*>(wl_registry_bind(
        registry, name, &zwlr_data_control_manager_v1_interface, 1));
  }
}

void registry_global_remove(void*, wl_registry*, uint32_t) {}

const wl_registry_listener registry_listener = {
    registry_global,
    registry_global_remove,
};

}  // namespace

void clipboard_keeper_init(FlBinaryMessenger* messenger) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  channel = fl_method_channel_new(messenger, "psito/clipboard_keeper",
                                  FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb, nullptr,
                                            nullptr);

  GdkDisplay* gdk_display = gdk_display_get_default();
  if (gdk_display == nullptr || !GDK_IS_WAYLAND_DISPLAY(gdk_display)) return;
  display = gdk_wayland_display_get_wl_display(gdk_display);
  seat = gdk_wayland_seat_get_wl_seat(gdk_display_get_default_seat(gdk_display));
  wl_registry* registry = wl_display_get_registry(display);
  wl_registry_add_listener(registry, &registry_listener, nullptr);
  wl_display_roundtrip(display);
  wl_registry_destroy(registry);
  if (manager == nullptr || seat == nullptr) return;
  device = zwlr_data_control_manager_v1_get_data_device(manager, seat);
  zwlr_data_control_device_v1_add_listener(device, &device_listener, nullptr);
  wl_display_flush(display);
}
