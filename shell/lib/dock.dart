// shell/lib/dock.dart
//
// A dock do psito_dock com os tipos do shell: os `.desktop` e as janelas do
// foreign-toplevel.
import 'package:psito_dock/psito_dock.dart';

import 'desktop_entries.dart';
import 'toplevels.dart';

typedef DockSlot = DockAppSlot<DesktopEntry, Toplevel>;

extension DockSlotName on DockSlot {
  /// Sem `.desktop`, o título da janela.
  String get name => app?.name ?? (windows.isEmpty ? id : windows.last.title);
}
