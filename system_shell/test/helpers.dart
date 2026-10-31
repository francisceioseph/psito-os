// Apoio comum dos testes: app falso e montagem do desktop numa tela 1280×800.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/app.dart';
import 'package:system_shell/screens/desktop_screen.dart';
import 'package:psito_services/system_services.dart';
import 'package:system_shell/shell/settings_store.dart';

class FakeApp extends PsitoApp {
  @override
  final String id;
  final String? _name;
  @override
  final bool singleInstance;
  @override
  final bool canChangeSettings;

  const FakeApp(
    this.id, {
    this._name,
    this.singleInstance = false,
    this.canChangeSettings = false,
  });

  @override
  String get name => _name ?? id;
  @override
  IconData get icon => const IconData(0);
  @override
  Color get color => const Color(0xFFFFFFFF);
  @override
  Widget build(PsitoAppContext context) => const SizedBox();
}

void _useDesktopView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Só o desktop, com configurações em memória. Sem [services], o próprio
/// desktop usa os falsos.
Future<void> pumpDesktop(
  WidgetTester tester, {
  SystemServices? services,
}) async {
  _useDesktopView(tester);
  await tester.pumpWidget(MaterialApp(home: DesktopScreen(services: services)));
}

/// Segura [modifiers], aperta [key] e solta tudo.
Future<void> pressCombo(
  WidgetTester tester,
  List<LogicalKeyboardKey> modifiers,
  LogicalKeyboardKey key,
) async {
  for (final m in modifiers) {
    await tester.sendKeyDownEvent(m);
  }
  await tester.sendKeyEvent(key);
  for (final m in modifiers.reversed) {
    await tester.sendKeyUpEvent(m);
  }
  await tester.pump();
}

/// O app inteiro (tema e configurações), como no boot. Sem [services], usa
/// os falsos.
Future<SettingsStore> pumpOS(
  WidgetTester tester, {
  SystemServices? services,
}) async {
  _useDesktopView(tester);
  final store = SettingsStore.memory();
  addTearDown(store.dispose);
  final system = services ?? SystemServices.fake();
  if (services == null) addTearDown(system.dispose);
  await tester.pumpWidget(PsitoOSApp(settings: store, services: system));
  return store;
}
