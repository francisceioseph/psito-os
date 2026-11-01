// system_shell/lib/shell/shortcuts.dart
//
// Atalhos globais do shell, sem UI. Cada ação tem a combinação nativa e uma
// que passa pelo host na VM (o Cinnamon fica com Super e Alt+Tab). A tabela
// das Configurações (psitoShortcuts, no SDK) mostra estas mesmas teclas.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum ShellAction {
  launcher,
  switchNext,
  switchPrev,
  closeWindow,
  maximize,
  snapLeft,
  snapRight,
  minimize,
  volumeUp,
  volumeDown,
  volumeMute,
  clipboard,
  clipboard1,
  clipboard2,
  clipboard3,
  clipboard4,
  clipboard5,
  showDesktop,
  lock,
}

/// As ações de copiar de novo, na ordem do histórico.
const clipboardSlots = [
  ShellAction.clipboard1,
  ShellAction.clipboard2,
  ShellAction.clipboard3,
  ShellAction.clipboard4,
  ShellAction.clipboard5,
];

const _arrowUp = LogicalKeyboardKey.arrowUp;
const _arrowDown = LogicalKeyboardKey.arrowDown;
const _arrowLeft = LogicalKeyboardKey.arrowLeft;
const _arrowRight = LogicalKeyboardKey.arrowRight;
const _tab = LogicalKeyboardKey.tab;

/// SingleActivator exige os modificadores exatos: Ctrl+Alt+Shift+← não
/// dispara Alt+Shift+←.
const shellBindings = <SingleActivator, ShellAction>{
  // Nativas
  SingleActivator(_tab, alt: true, includeRepeats: true):
      ShellAction.switchNext,
  SingleActivator(_tab, alt: true, shift: true, includeRepeats: true):
      ShellAction.switchPrev,
  SingleActivator(LogicalKeyboardKey.f4, alt: true): ShellAction.closeWindow,
  SingleActivator(LogicalKeyboardKey.keyQ, meta: true): ShellAction.closeWindow,
  SingleActivator(_arrowUp, meta: true): ShellAction.maximize,
  SingleActivator(_arrowLeft, meta: true): ShellAction.snapLeft,
  SingleActivator(_arrowRight, meta: true): ShellAction.snapRight,
  SingleActivator(_arrowDown, meta: true): ShellAction.minimize,
  SingleActivator(LogicalKeyboardKey.audioVolumeUp, includeRepeats: true):
      ShellAction.volumeUp,
  SingleActivator(LogicalKeyboardKey.audioVolumeDown, includeRepeats: true):
      ShellAction.volumeDown,
  SingleActivator(LogicalKeyboardKey.audioVolumeMute): ShellAction.volumeMute,
  SingleActivator(LogicalKeyboardKey.keyV, meta: true): ShellAction.clipboard,
  SingleActivator(LogicalKeyboardKey.digit1, meta: true):
      ShellAction.clipboard1,
  SingleActivator(LogicalKeyboardKey.digit2, meta: true):
      ShellAction.clipboard2,
  SingleActivator(LogicalKeyboardKey.digit3, meta: true):
      ShellAction.clipboard3,
  SingleActivator(LogicalKeyboardKey.digit4, meta: true):
      ShellAction.clipboard4,
  SingleActivator(LogicalKeyboardKey.digit5, meta: true):
      ShellAction.clipboard5,
  SingleActivator(LogicalKeyboardKey.keyD, meta: true): ShellAction.showDesktop,
  SingleActivator(LogicalKeyboardKey.keyL, meta: true): ShellAction.lock,

  // VM
  SingleActivator(LogicalKeyboardKey.space, control: true):
      ShellAction.launcher,
  SingleActivator(_tab, control: true, includeRepeats: true):
      ShellAction.switchNext,
  SingleActivator(_tab, control: true, shift: true, includeRepeats: true):
      ShellAction.switchPrev,
  SingleActivator(LogicalKeyboardKey.keyW, control: true, alt: true):
      ShellAction.closeWindow,
  SingleActivator(_arrowUp, alt: true, shift: true): ShellAction.maximize,
  SingleActivator(_arrowLeft, alt: true, shift: true): ShellAction.snapLeft,
  SingleActivator(_arrowRight, alt: true, shift: true): ShellAction.snapRight,
  SingleActivator(_arrowDown, alt: true, shift: true): ShellAction.minimize,
  SingleActivator(
    LogicalKeyboardKey.pageUp,
    alt: true,
    shift: true,
    includeRepeats: true,
  ): ShellAction.volumeUp,
  SingleActivator(
    LogicalKeyboardKey.pageDown,
    alt: true,
    shift: true,
    includeRepeats: true,
  ): ShellAction.volumeDown,
  SingleActivator(LogicalKeyboardKey.keyM, alt: true, shift: true):
      ShellAction.volumeMute,
  SingleActivator(LogicalKeyboardKey.keyV, alt: true, shift: true):
      ShellAction.clipboard,
  SingleActivator(LogicalKeyboardKey.digit1, alt: true, shift: true):
      ShellAction.clipboard1,
  SingleActivator(LogicalKeyboardKey.digit2, alt: true, shift: true):
      ShellAction.clipboard2,
  SingleActivator(LogicalKeyboardKey.digit3, alt: true, shift: true):
      ShellAction.clipboard3,
  SingleActivator(LogicalKeyboardKey.digit4, alt: true, shift: true):
      ShellAction.clipboard4,
  SingleActivator(LogicalKeyboardKey.digit5, alt: true, shift: true):
      ShellAction.clipboard5,
  SingleActivator(LogicalKeyboardKey.keyD, alt: true, shift: true):
      ShellAction.showDesktop,
  SingleActivator(LogicalKeyboardKey.keyL, alt: true, shift: true):
      ShellAction.lock,
};

ShellAction? resolveShortcut(KeyEvent event, HardwareKeyboard keyboard) {
  for (final MapEntry(key: activator, value: action) in shellBindings.entries) {
    if (activator.accepts(event, keyboard)) return action;
  }
  return null;
}

bool isSuperKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.metaLeft || key == LogicalKeyboardKey.metaRight;

/// Super sozinho abre o launcher: dispara ao soltar, se nenhuma outra tecla
/// veio no meio (Super+↑ não abre).
class SuperTapDetector {
  bool _alone = false;

  /// True quando [event] completa um toque em Super.
  bool handle(KeyEvent event) {
    final isSuper = isSuperKey(event.logicalKey);
    if (event is KeyDownEvent) {
      _alone = isSuper;
    } else if (event is KeyUpEvent && isSuper) {
      final tapped = _alone;
      _alone = false;
      return tapped;
    }
    return false;
  }
}
