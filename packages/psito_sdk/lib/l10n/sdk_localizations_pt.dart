// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'sdk_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class SdkLocalizationsPt extends SdkLocalizations {
  SdkLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get wallpaperNoite => 'Noite';

  @override
  String get wallpaperCalopsita => 'Calopsita';

  @override
  String get wallpaperPorDoSol => 'Pôr do sol';

  @override
  String get wallpaperFloresta => 'Floresta';

  @override
  String get wallpaperOceano => 'Oceano';

  @override
  String get dockPositionBottom => 'Embaixo';

  @override
  String get dockPositionLeft => 'À esquerda';

  @override
  String get dockPositionRight => 'À direita';

  @override
  String get shortcutLauncher => 'Abrir e fechar o launcher';

  @override
  String get shortcutLauncherVm => 'Ctrl+Espaço';

  @override
  String get shortcutSwitchWindows => 'Alternar janelas';

  @override
  String get shortcutCloseWindow => 'Fechar a janela';

  @override
  String get shortcutMaximize => 'Maximizar';

  @override
  String get shortcutSnap => 'Snap à esquerda / direita';

  @override
  String get shortcutMinimize => 'Minimizar';

  @override
  String get shortcutVolume => 'Subir / baixar o volume';

  @override
  String get shortcutVolumeKeys => 'Teclas de volume';

  @override
  String get shortcutMedia => 'Tocar ou pausar / próxima / faixa anterior';

  @override
  String get shortcutMediaKeys => 'Teclas de mídia';

  @override
  String get shortcutMute => 'Silenciar';

  @override
  String get shortcutMuteKey => 'Tecla de mudo';

  @override
  String get shortcutClipboard => 'Abrir a área de transferência';

  @override
  String get shortcutClipboardCopy =>
      'Copiar de novo o item 1 a 5 da área de transferência';

  @override
  String get shortcutClipboardCopyNative => 'Super+1 a 5';

  @override
  String get shortcutClipboardCopyVm => 'Alt+Shift+1 a 5';

  @override
  String get shortcutShowDesktop => 'Mostrar a área de trabalho';

  @override
  String get shortcutDismiss => 'Fechar launcher, painel ou seletor';

  @override
  String openNoApp(Object file) {
    return 'Nenhum app abre \"$file\".';
  }

  @override
  String openFailed(Object detail) {
    return 'O shell não abriu ($detail).';
  }

  @override
  String get shortcutLock => 'Bloquear a tela';

  @override
  String get wallpaperPsitoEscuro => 'Psito escuro';

  @override
  String get wallpaperPsitoClaro => 'Psito claro';

  @override
  String get wallpaperGrafite => 'Grafite';

  @override
  String get wallpaperMarinho => 'Marinho';

  @override
  String get wallpaperMusgo => 'Musgo';

  @override
  String get wallpaperVinho => 'Vinho';

  @override
  String get wallpaperAmeixa => 'Ameixa';
}
