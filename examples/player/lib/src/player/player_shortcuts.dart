// examples/player/lib/src/player/player_shortcuts.dart
//
// Os atalhos do player. Valem na janela toda, a não ser quando o controle em foco
// usa a mesma tecla: o Espaço aciona o botão em foco, e nada vale durante a
// digitação. O Slider em foco fica com as setas antes de chegarem aqui.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'playback_controller.dart';

bool _typing(BuildContext? context) =>
    context != null &&
    (context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null);

KeyEventResult handlePlayerKey(
  KeyEvent event,
  PlaybackController playback, {
  VoidCallback? onSearch,
}) {
  if (event is KeyUpEvent) return KeyEventResult.ignored;
  final key = event.logicalKey;
  // O único que vale digitando: é o caminho de volta para a busca
  if (key == LogicalKeyboardKey.keyK &&
      event is KeyDownEvent &&
      HardwareKeyboard.instance.isControlPressed &&
      onSearch != null) {
    onSearch();
    return KeyEventResult.handled;
  }
  final focused = FocusManager.instance.primaryFocus?.context;
  if (_typing(focused)) return KeyEventResult.ignored;
  if (key == LogicalKeyboardKey.space && event is KeyDownEvent) {
    if (focused != null && Actions.maybeFind<ActivateIntent>(focused) != null) {
      return KeyEventResult.ignored;
    }
    if (playback.state.queue.isEmpty) return KeyEventResult.ignored;
    unawaited(playback.togglePlay());
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.arrowLeft) {
    unawaited(playback.seekBy(-seekStep));
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.arrowRight) {
    unawaited(playback.seekBy(seekStep));
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}
