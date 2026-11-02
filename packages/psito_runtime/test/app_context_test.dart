import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_runtime/psito_runtime.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/network_service.dart';
import 'package:psito_services/system_info_service.dart';
import 'package:psito_services/time_service.dart';

const _window = MethodChannel('test/window');

class _App extends PsitoApp {
  @override
  final String id;
  @override
  final bool canChangeSettings;

  const _App(this.id, {this.canChangeSettings = false});

  @override
  String get name => id;
  @override
  IconData get icon => const IconData(0xe000);
  @override
  Color get color => const Color(0xFFFFC107);
  @override
  Widget build(PsitoAppContext context) => const SizedBox();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> windowCalls;
  late List<PsitoNotification> sent;
  late List<PsitoSettings> updates;

  setUp(() {
    windowCalls = [];
    sent = [];
    updates = [];
    messenger.setMockMethodCallHandler(_window, (call) async {
      windowCalls.add(call);
      return null;
    });
  });

  ProcessAppContext contextFor(PsitoApp app) => ProcessAppContext(
    app: app,
    settings: ValueNotifier(PsitoSettings.defaults),
    services: AppServices(
      systemInfo: FakeSystemInfoService(),
      network: FakeNetworkService(),
      time: FakeTimeService(),
    ),
    onUpdateSettings: updates.add,
    onNotify: sent.add,
    window: const AppWindow(_window),
    windowId: '${app.id}#1',
  );

  test('o contexto: título, fechar, notificar e configurações', () async {
    final ctx = contextFor(const _App('notepad'));
    ctx.setTitle('nota.txt');
    ctx.notify(const PsitoNotification(title: 'salvo'));
    ctx.updateSettings(PsitoSettings.defaults.copyWith(use24h: false));
    ctx.close();
    await Future<void>.delayed(Duration.zero);

    expect(windowCalls.map((c) => c.method), ['setTitle', 'close']);
    expect(windowCalls.first.arguments, 'nota.txt');
    expect(sent.single.title, 'salvo');
    // O bloco de notas não pode mudar as configurações
    expect(updates, isEmpty);

    contextFor(const _App('settings', canChangeSettings: true))
        .updateSettings(PsitoSettings.defaults.copyWith(use24h: false));
    expect(updates.single.use24h, isFalse);
  });

  test('o tamanho da janela nunca fica abaixo do mínimo', () async {
    await const AppWindow(_window).setSize(const Size(100, 500));
    expect(windowCalls.single.arguments, [240, 500]);
  });

  test('os argumentos com marca chegam ao app, e as opções não', () {
    final marked = [
      '${psitoQuickLookPrefix}a',
      '${psitoSettingsSectionPrefix}network',
      '${psitoFormatDiskPrefix}sdb1',
    ];
    expect(openedPaths(['-x', 'solto', '/tmp/a', ...marked]), [
      '/tmp/a',
      ...marked,
    ]);
    expect(openedPaths(['file:///tmp/b%20c']), ['/tmp/b c']);
  });
}
