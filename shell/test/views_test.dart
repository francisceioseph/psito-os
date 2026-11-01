// As superfícies dimensionadas pelo conteúdo não têm MaterialApp: o que elas
// desenham precisa achar o tema e os textos, ou o shell cai a cada toast.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_services/audio_service.dart';
import 'package:psito_services/system_services.dart';
import 'package:psito_shell/shell_state.dart';
import 'package:psito_shell/surfaces.dart';
import 'package:psito_shell/toplevels.dart';
import 'package:psito_shell/views.dart';
import 'package:system_shell/shell/clipboard_history.dart';
import 'package:system_shell/shell/settings_store.dart';
import 'package:system_shell/widgets/notification_toasts.dart';

const _toplevels = MethodChannel('test/toplevels');
const _surfaces = MethodChannel('test/surfaces');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late ShellState state;
  late FakeAudioService audio;
  late List<Map<Object?, Object?>> resizes;

  setUp(() {
    resizes = [];
    messenger.setMockMethodCallHandler(_surfaces, (call) async {
      if (call.method == 'resize') {
        resizes.add(call.arguments as Map<Object?, Object?>);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(_toplevels, (_) async => null);
    audio = FakeAudioService(
      const AudioState(available: true, volume: 0.4, muted: true),
    );
    state = ShellState(
      settings: SettingsStore.memory(),
      services: SystemServices.fake(audio: audio),
      toplevels: ToplevelList(channel: _toplevels),
      surfaces: const Surfaces(_surfaces),
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_surfaces, null);
    messenger.setMockMethodCallHandler(_toplevels, null);
  });

  testWidgets('o toast aparece e dá um tamanho à superfície', (tester) async {
    await tester.pumpWidget(ToastsView(state));
    state.notifications.add(
      app: state.appFor('teste', name: 'Teste'),
      title: 'Oi',
      body: 'corpo',
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(NotificationTile), findsOneWidget);
    expect(find.text('Oi'), findsOneWidget);
    expect(find.byTooltip('Dispensar'), findsNothing);
    expect(resizes.last['surface'], 'toasts');
    state.notifications.dismissToast(state.notifications.toasts.single.id);
    await tester.pumpAndSettle();
  });

  testWidgets('o OSD de volume mostra o mudo', (tester) async {
    await tester.pumpWidget(OsdView(state));
    state.osd.value = true;
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Mudo'), findsOneWidget);
  });

  testWidgets('o OSD da área de transferência mostra o que copiou', (
    tester,
  ) async {
    await tester.pumpWidget(OsdView(state));
    state.osdClip.value = ClipEntry.from({
      'text/plain': Uint8List.fromList(utf8.encode('calopsita')),
    }, DateTime(2026, 11, 1));
    state.osd.value = true;
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('calopsita'), findsOneWidget);
  });
}
