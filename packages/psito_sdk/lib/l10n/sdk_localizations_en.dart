// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'sdk_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SdkLocalizationsEn extends SdkLocalizations {
  SdkLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get wallpaperNoite => 'Night';

  @override
  String get wallpaperCalopsita => 'Cockatiel';

  @override
  String get wallpaperPorDoSol => 'Sunset';

  @override
  String get wallpaperFloresta => 'Forest';

  @override
  String get wallpaperOceano => 'Ocean';

  @override
  String get dockPositionBottom => 'Bottom';

  @override
  String get dockPositionLeft => 'Left';

  @override
  String get dockPositionRight => 'Right';

  @override
  String get shortcutLauncher => 'Open and close the launcher';

  @override
  String get shortcutLauncherVm => 'Ctrl+Space';

  @override
  String get shortcutSwitchWindows => 'Switch windows';

  @override
  String get shortcutCloseWindow => 'Close the window';

  @override
  String get shortcutMaximize => 'Maximize';

  @override
  String get shortcutSnap => 'Snap left / right';

  @override
  String get shortcutMinimize => 'Minimize';

  @override
  String get shortcutVolume => 'Raise / lower the volume';

  @override
  String get shortcutVolumeKeys => 'Volume keys';

  @override
  String get shortcutMute => 'Mute';

  @override
  String get shortcutMuteKey => 'Mute key';

  @override
  String get shortcutClipboard => 'Open the clipboard';

  @override
  String get shortcutClipboardCopy => 'Copy clipboard item 1 to 5 again';

  @override
  String get shortcutClipboardCopyNative => 'Super+1 to 5';

  @override
  String get shortcutClipboardCopyVm => 'Alt+Shift+1 to 5';

  @override
  String get shortcutShowDesktop => 'Show the desktop';

  @override
  String get shortcutDismiss => 'Close launcher, panel or switcher';

  @override
  String openNoApp(Object file) {
    return 'No app opens \"$file\".';
  }

  @override
  String openFailed(Object detail) {
    return 'The shell couldn\'t open it ($detail).';
  }

  @override
  String get shortcutLock => 'Lock the screen';

  @override
  String get wallpaperPsitoEscuro => 'Psito dark';

  @override
  String get wallpaperPsitoClaro => 'Psito light';

  @override
  String get wallpaperGrafite => 'Graphite';

  @override
  String get wallpaperMarinho => 'Navy';

  @override
  String get wallpaperMusgo => 'Moss';

  @override
  String get wallpaperVinho => 'Wine';

  @override
  String get wallpaperAmeixa => 'Plum';
}
