#ifndef RUNNER_CLIPBOARD_KEEPER_H_
#define RUNNER_CLIPBOARD_KEEPER_H_

#include <flutter_linux/flutter_linux.h>

// O gerenciador da área de transferência, sobre o wlr-data-control: lê cada
// cópia de qualquer app, sem precisar do foco, e oferece de novo o que o Dart
// pedir, no canal psito/clipboard_keeper (lib/clipboard_keeper.dart). No
// Wayland o conteúdo mora no app que copiou, e some com ele.
//   C -> Dart: "copied" {tipo MIME: bytes}: uma cópia nova, lida
//              "skipped": uma cópia que não dá para guardar (grande demais, ou
//              marcada como senha)
//              "lost": ninguém mais oferece nada (o dono fechou)
//   Dart -> C: "offer" {tipo MIME: bytes}: passa a oferecer isso
//              "clear": esvazia a área de transferência
// Sem Wayland ou sem o protocolo no compositor, nada acontece.
void clipboard_keeper_init(FlBinaryMessenger* messenger);

#endif  // RUNNER_CLIPBOARD_KEEPER_H_
