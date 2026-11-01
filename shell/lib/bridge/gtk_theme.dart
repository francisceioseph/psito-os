// shell/lib/bridge/gtk_theme.dart
//
// O tema GTK do Psito: os apps GTK, o Firefox e os apps Flutter desenham a
// própria moldura, e só seguem as cores do Psito pelo tema do GTK. As cores
// nomeadas do Adwaita são trocadas por CSS em ~/.config/gtk-3.0 e gtk-4.0,
// como o Budgie faz. Vale para os apps abertos depois: o GTK lê ao iniciar.
// O escuro também vai para o gsettings (color-scheme), que o portal de
// configurações (xdg-desktop-portal-gtk) publica ao Firefox e à libadwaita,
// e os botões da barra de título (button-layout), que o GTK lê de lá.
import 'dart:io';
import 'dart:ui';

import 'colors.dart';

// A marca de que o arquivo é nosso, nos que já estão gravados: não muda.
const gtkThemeHeader = '/* Gerado pela ponte do Psito. Não edite. */';
const _iniHeader = '# Gerado pela ponte do Psito. Não edite.';

String gtkCss(Color accent) {
  final a = hexColor(accent);
  final onA = hexColor(onColor(accent));
  final bg = psitoBackgroundHex;
  final surface = hexColor(psitoSurface);
  final text = psitoTextHex;
  return '''$gtkThemeHeader
/* GTK 4 e libadwaita */
@define-color accent_color $a;
@define-color accent_bg_color $a;
@define-color accent_fg_color $onA;
@define-color window_bg_color $bg;
@define-color window_fg_color $text;
@define-color view_bg_color $surface;
@define-color view_fg_color $text;
@define-color headerbar_bg_color $bg;
@define-color headerbar_fg_color $text;
@define-color headerbar_backdrop_color $bg;
@define-color popover_bg_color $surface;
@define-color popover_fg_color $text;
@define-color card_bg_color $surface;
@define-color card_fg_color $text;
@define-color dialog_bg_color $surface;
@define-color dialog_fg_color $text;
@define-color sidebar_bg_color $bg;
@define-color sidebar_fg_color $text;

/* GTK 3 e o Default do GTK 4 */
@define-color theme_bg_color $bg;
@define-color theme_fg_color $text;
@define-color theme_base_color $surface;
@define-color theme_text_color $text;
@define-color theme_selected_bg_color $a;
@define-color theme_selected_fg_color $onA;
@define-color theme_unfocused_bg_color $bg;
@define-color theme_unfocused_fg_color $text;
''';
}

const gtkSettingsIni = '''$_iniHeader
[Settings]
gtk-application-prefer-dark-theme=1
''';

/// Grava só se o arquivo não existe ou se é da ponte: um `gtk.css` do
/// usuário fica como está. Devolve se gravou.
Future<bool> _writeOwned(File file, String header, String content) async {
  if (await file.exists()) {
    final current = await file.readAsString();
    if (!current.startsWith(header)) return false;
    if (current == content) return true;
  }
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
  return true;
}

/// Os arquivos que a ponte não gravou porque são do usuário.
Future<List<String>> applyGtkTheme(Directory configHome, Color accent) async {
  final skipped = <String>[];
  final css = gtkCss(accent);
  for (final version in ['gtk-3.0', 'gtk-4.0']) {
    final dir = '${configHome.path}/$version';
    final files = {
      File('$dir/gtk.css'): (gtkThemeHeader, css),
      File('$dir/settings.ini'): (_iniHeader, gtkSettingsIni),
    };
    for (final MapEntry(key: file, value: (header, content)) in files.entries) {
      if (!await _writeOwned(file, header, content)) skipped.add(file.path);
    }
  }
  return skipped;
}

/// O que vai para o gsettings: o escuro (`color-scheme`, que o portal publica
/// ao Firefox e à libadwaita) e os botões da barra de título que o GTK
/// desenha (`button-layout`; o padrão do GNOME é só o fechar).
const gnomeSettings = [
  ('org.gnome.desktop.interface', 'color-scheme', 'prefer-dark'),
  (
    'org.gnome.desktop.wm.preferences',
    'button-layout',
    'appmenu:minimize,maximize,close',
  ),
];

/// Grava os [gnomeSettings], cada um só se mudou, para não acordar quem
/// acompanha. Devolve as chaves gravadas; sem o gsettings, nenhuma.
Future<List<String>> applyGnomeSettings({
  Future<ProcessResult> Function(String, List<String>) run = Process.run,
}) async {
  final changed = <String>[];
  try {
    for (final (schema, key, value) in gnomeSettings) {
      final current = await run('gsettings', ['get', schema, key]);
      if (current.exitCode == 0 &&
          (current.stdout as String).trim() == "'$value'") {
        continue;
      }
      final set = await run('gsettings', ['set', schema, key, value]);
      if (set.exitCode == 0) changed.add(key);
    }
  } on ProcessException {
    // Sem o gsettings, fica o que o GTK tiver
  }
  return changed;
}
