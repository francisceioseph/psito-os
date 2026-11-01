// Apoio comum dos testes: app falso e montagem do desktop numa tela 1280×800.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/l10n/system_localizations.dart';
import 'package:system_shell/shell/app_registry.dart';
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
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: testL10nDelegates,
      supportedLocales: psitoLocales,
      home: DesktopScreen(services: services),
    ),
  );
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

/// O que o `PsitoOSApp` registra, para os widgets testados fora dele.
final testL10nDelegates = psitoLocalizationsDelegates([
  SystemLocalizations.delegate,
  for (final app in registeredApps) ...app.localizationsDelegates,
]);

final testL10n = lookupSystemLocalizations(const Locale('pt'));

/// Falha, dizendo onde, se algum clique da tela não tem nome para o leitor de
/// tela. O `labeledTapTargetGuideline` do Flutter faz a mesma conta, mas só
/// mostra o retângulo.
Future<void> expectAllLabeled(WidgetTester tester) async {
  final semantics = tester.ensureSemantics();
  await tester.pump();
  final missing = <String>[];
  var nodes = 0;
  void visit(SemanticsNode node, Matrix4 parent) {
    nodes++;
    final transform = parent.clone();
    if (node.transform case final own?) transform.multiply(own);
    node.visitChildren((child) {
      visit(child, transform);
      return true;
    });
    if (node.isMergedIntoParent || node.isInvisible) return;
    final data = node.getSemanticsData();
    final clickable =
        data.hasAction(SemanticsAction.tap) ||
        data.hasAction(SemanticsAction.longPress);
    if (!clickable) return;
    if (data.label.isNotEmpty ||
        data.tooltip.isNotEmpty ||
        data.value.isNotEmpty) {
      return;
    }
    final rect = MatrixUtils.transformRect(transform, node.rect);
    missing.add('$rect: ${_widgetsAt(tester, rect.center)}');
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root, Matrix4.identity());
  }
  semantics.dispose();
  // Sem isto, uma árvore vazia passaria
  expect(nodes, greaterThan(1));
  expect(missing, isEmpty, reason: 'Cliques sem nome:\n${missing.join('\n')}');
}

/// Os widgets do projeto no ponto: a pista de onde está o clique sem nome.
String _widgetsAt(WidgetTester tester, Offset point) {
  final hit = HitTestResult();
  tester.binding.hitTestInView(hit, point, tester.view.viewId);
  for (final entry in hit.path) {
    final target = entry.target;
    if (target is! RenderObject) continue;
    final creator = target.debugCreator;
    if (creator is! DebugCreator) continue;
    return creator.element
        .debugGetDiagnosticChain()
        .map((e) => e.widget.runtimeType.toString())
        .where((name) => !name.startsWith('_') && !_framework.hasMatch(name))
        .take(6)
        .join(' < ');
  }
  return '?';
}

final _framework = RegExp(
  r'^(Semantics|Listener|MouseRegion|Focus|Actions|Builder|InkWell|InkResponse|'
  r'Material|GestureDetector|RawGestureDetector|DefaultTextStyle|PhysicalModel|'
  r'PhysicalShape|NotificationListener|CustomPaint|ConstrainedBox|Padding|Align|'
  r'Center|SizedBox|Container|DecoratedBox|Row|Column|Flex|Stack|Expanded|'
  r'Flexible|Positioned|ClipRRect|ClipRect|IconTheme|Icon|Text|RichText|'
  r'Opacity|Transform|ColoredBox|AnimatedBuilder|ListenableBuilder|'
  r'ValueListenableBuilder|KeyedSubtree|RepaintBoundary|LayoutBuilder|MetaData)'
  r'(<.*)?$',
);

/// Rola a lista das seções das Configurações até [item], longe do pé da janela,
/// que a dock cobre.
Future<void> scrollToSection(WidgetTester tester, Finder item) async {
  await tester.scrollUntilVisible(
    item,
    60,
    scrollable: find
        .ancestor(
          of: find.byType(ListTile).first,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await Scrollable.ensureVisible(tester.element(item.first), alignment: 0.3);
  await tester.pump();
}
