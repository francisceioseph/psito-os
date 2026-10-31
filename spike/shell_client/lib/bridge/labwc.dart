// spike/shell_client/lib/bridge/labwc.dart
//
// A ponte para o labwc, no modelo da do Budgie 10.10: a seção <keyboard> do
// rc.xml e o themerc-override saem das configurações do Psito, e o labwc
// recarrega com --reconfigure. O resto do rc.xml não é da ponte.
import 'dart:io';
import 'dart:ui';

import 'package:system_shell/shell/shortcuts.dart';

import 'bindings.dart';
import 'colors.dart';

String _labwcAction(ShellAction action) => switch (action) {
  _ when shellHandles(action) =>
    '<action name="Execute" command="${_attr(shellCommand(action))}" />',
  ShellAction.closeWindow => '<action name="Close" />',
  ShellAction.maximize => '<action name="ToggleMaximize" />',
  ShellAction.snapLeft => '<action name="SnapToEdge" direction="left" />',
  ShellAction.snapRight => '<action name="SnapToEdge" direction="right" />',
  ShellAction.minimize => '<action name="Iconify" />',
  _ => throw StateError('ação sem tradução no labwc: $action'),
};

String _attr(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;');

String labwcKeyboard(List<CompositorBinding> bindings) {
  final lines = [
    '  <keyboard>',
    '    <!-- Gerado pela ponte do Psito (spike/shell_client/lib/bridge). Não edite. -->',
    '    <default />',
    for (final b in bindings)
      '    <keybind key="${labwcKey(b)}"${b.superTap ? ' onRelease="yes"' : ''}>'
          '${_labwcAction(b.action)}</keybind>',
    '  </keyboard>',
  ];
  return lines.join('\n');
}

/// Troca a seção `<keyboard>` de [rcXml]; sem uma, põe antes do fim. Só
/// vale a tag no começo da linha: um comentário que cita `<keyboard>` não
/// conta.
String replaceKeyboard(String rcXml, String keyboard) {
  final section = RegExp(
    r'^[ \t]*<keyboard\s*/>[ \t]*$|^[ \t]*<keyboard>.*?</keyboard>[ \t]*$',
    multiLine: true,
    dotAll: true,
  );
  if (section.hasMatch(rcXml)) {
    return rcXml.replaceFirst(section, keyboard);
  }
  final end = rcXml.lastIndexOf('</labwc_config>');
  if (end < 0) throw FormatException('rc.xml sem <labwc_config>');
  return '${rcXml.substring(0, end)}$keyboard\n${rcXml.substring(end)}';
}

String labwcThemerc(Color accent) {
  final a = hexColor(accent);
  final onA = hexColor(onColor(accent));
  return '''# Gerado pela ponte do Psito (spike/shell_client/lib/bridge). Não edite.
border.width: 1
window.titlebar.padding.height: 4
window.active.title.bg.color: $a
window.active.label.text.color: $onA
window.active.button.unpressed.image.color: $onA
window.active.border.color: $a
window.inactive.title.bg.color: $psitoBackgroundHex
window.inactive.label.text.color: $psitoTextHex
window.inactive.button.unpressed.image.color: $psitoTextHex
window.inactive.border.color: $psitoBackgroundHex
osd.bg.color: $psitoBackgroundHex
osd.border.color: $a
osd.label.text.color: $psitoTextHex
osd.window-switcher.item.active.border.color: $a
''';
}

/// Grava a configuração em [configHome]/labwc e manda o labwc recarregar.
Future<void> applyLabwc(
  Directory configHome,
  Color accent, {
  required Map<String, String> environment,
}) async {
  final dir = Directory('${configHome.path}/labwc');
  await dir.create(recursive: true);
  final rc = File('${dir.path}/rc.xml');
  final current = await rc.exists()
      ? await rc.readAsString()
      : '<?xml version="1.0"?>\n<labwc_config>\n</labwc_config>\n';
  await rc.writeAsString(
    replaceKeyboard(current, labwcKeyboard(compositorBindings())),
  );
  await File('${dir.path}/themerc-override')
      .writeAsString(labwcThemerc(accent));

  // O --reconfigure acha o labwc pelo LABWC_PID, que o shell herda dele
  final result = await Process.run('labwc', [
    '--reconfigure',
  ], environment: environment);
  if (result.exitCode != 0) {
    throw ProcessException('labwc', ['--reconfigure'], '${result.stderr}');
  }
}
