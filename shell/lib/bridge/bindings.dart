// shell/lib/bridge/bindings.dart
//
// Os atalhos do Psito na língua de cada compositor. A fonte é a shellBindings
// do system_shell: mudar um atalho lá muda no labwc e no Wayfire.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:system_shell/shell/shortcuts.dart';

/// Um atalho para o compositor: uma combinação, ou o Super sozinho
/// ([activator] nulo), que dispara ao soltar.
class CompositorBinding {
  final ShellAction action;
  final SingleActivator? activator;

  const CompositorBinding(this.action, this.activator);

  const CompositorBinding.superTap(this.action) : activator = null;

  bool get superTap => activator == null;

  /// Repete com a tecla segurada: o Tab do seletor e o volume. (O
  /// includeRepeats do SingleActivator não serve: o padrão dele é true.)
  bool get repeats => switch (action) {
    ShellAction.switchNext ||
    ShellAction.switchPrev ||
    ShellAction.volumeUp ||
    ShellAction.volumeDown => !superTap,
    _ => false,
  };
}

/// Os nativos e os de VM, mais o Super sozinho para o launcher.
List<CompositorBinding> compositorBindings() => [
  for (final MapEntry(key: activator, value: action) in shellBindings.entries)
    CompositorBinding(action, activator),
  const CompositorBinding.superTap(ShellAction.launcher),
];

/// As ações que são do shell; as outras o compositor faz sozinho.
bool shellHandles(ShellAction action) => switch (action) {
  ShellAction.launcher ||
  ShellAction.switchNext ||
  ShellAction.switchPrev ||
  ShellAction.volumeUp ||
  ShellAction.volumeDown ||
  ShellAction.volumeMute ||
  ShellAction.mediaPlayPause ||
  ShellAction.mediaNext ||
  ShellAction.mediaPrevious ||
  ShellAction.clipboard ||
  ShellAction.clipboard1 ||
  ShellAction.clipboard2 ||
  ShellAction.clipboard3 ||
  ShellAction.clipboard4 ||
  ShellAction.clipboard5 ||
  ShellAction.showDesktop ||
  ShellAction.lock => true,
  ShellAction.closeWindow ||
  ShellAction.maximize ||
  ShellAction.snapLeft ||
  ShellAction.snapRight ||
  ShellAction.minimize => false,
};

/// O comando que o compositor roda para uma ação do shell (shell_bus.dart).
String shellCommand(ShellAction action) =>
    'gdbus call --session --dest org.psito.Shell '
    '--object-path /org/psito/Shell --method org.psito.Shell.Run '
    '"\'${action.name}\'"';

/// Nome da tecla no xkb (labwc) e no evdev (Wayfire).
final _keys = <LogicalKeyboardKey, (String, String)>{
  LogicalKeyboardKey.tab: ('Tab', 'KEY_TAB'),
  LogicalKeyboardKey.space: ('space', 'KEY_SPACE'),
  LogicalKeyboardKey.f4: ('F4', 'KEY_F4'),
  LogicalKeyboardKey.arrowUp: ('Up', 'KEY_UP'),
  LogicalKeyboardKey.arrowDown: ('Down', 'KEY_DOWN'),
  LogicalKeyboardKey.arrowLeft: ('Left', 'KEY_LEFT'),
  LogicalKeyboardKey.arrowRight: ('Right', 'KEY_RIGHT'),
  LogicalKeyboardKey.pageUp: ('Prior', 'KEY_PAGEUP'),
  LogicalKeyboardKey.pageDown: ('Next', 'KEY_PAGEDOWN'),
  LogicalKeyboardKey.audioVolumeUp: ('XF86AudioRaiseVolume', 'KEY_VOLUMEUP'),
  LogicalKeyboardKey.audioVolumeDown: (
    'XF86AudioLowerVolume',
    'KEY_VOLUMEDOWN',
  ),
  LogicalKeyboardKey.audioVolumeMute: ('XF86AudioMute', 'KEY_MUTE'),
  LogicalKeyboardKey.mediaPlayPause: ('XF86AudioPlay', 'KEY_PLAYPAUSE'),
  LogicalKeyboardKey.mediaTrackNext: ('XF86AudioNext', 'KEY_NEXTSONG'),
  LogicalKeyboardKey.mediaTrackPrevious: ('XF86AudioPrev', 'KEY_PREVIOUSSONG'),
};

(String, String) _key(LogicalKeyboardKey key) {
  if (_keys[key] case final names?) return names;
  final label = key.keyLabel;
  if (RegExp(r'^[A-Z0-9]$').hasMatch(label)) {
    return (label.toLowerCase(), 'KEY_$label');
  }
  throw ArgumentError('tecla sem nome no compositor: ${key.debugName}');
}

/// `C-A-w`, `W-Left`, `Super_L`.
String labwcKey(CompositorBinding binding) {
  final a = binding.activator;
  if (a == null) return 'Super_L';
  return [
    if (a.control) 'C',
    if (a.alt) 'A',
    if (a.shift) 'S',
    if (a.meta) 'W',
    _key(a.trigger).$1,
  ].join('-');
}

/// `<ctrl> <alt> KEY_W`, `<super>`.
String wayfireKey(CompositorBinding binding) {
  final a = binding.activator;
  if (a == null) return '<super>';
  return [
    if (a.control) '<ctrl>',
    if (a.alt) '<alt>',
    if (a.shift) '<shift>',
    if (a.meta) '<super>',
    _key(a.trigger).$2,
  ].join(' ');
}
