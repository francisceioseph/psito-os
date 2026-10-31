// Apoio comum dos testes: app falso e montagem do desktop numa tela 1280×800.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/app.dart';
import 'package:system_shell/screens/desktop_screen.dart';
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

/// Só o desktop, com configurações em memória.
Future<void> pumpDesktop(WidgetTester tester) async {
  _useDesktopView(tester);
  await tester.pumpWidget(const MaterialApp(home: DesktopScreen()));
}

/// O app inteiro (tema e configurações), como no boot.
Future<SettingsStore> pumpOS(WidgetTester tester) async {
  _useDesktopView(tester);
  final store = SettingsStore.memory();
  addTearDown(store.dispose);
  await tester.pumpWidget(PsitoOSApp(settings: store));
  return store;
}
