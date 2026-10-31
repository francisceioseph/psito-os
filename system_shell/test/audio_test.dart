import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_services/audio_service.dart';
import 'package:psito_services/system_services.dart';
import 'package:system_shell/widgets/network_panel.dart';
import 'package:system_shell/widgets/volume_osd.dart';
import 'package:system_shell/widgets/volume_panel.dart';

import 'helpers.dart';

final _indicator = find.byKey(const ValueKey('volume-indicator'));
final _panel = find.byType(VolumePanel);
final _osd = find.byType(VolumeOsd);

Future<FakeAudioService> _pump(
  WidgetTester tester, [
  AudioState initial = FakeAudioService.sample,
]) async {
  final audio = FakeAudioService(initial);
  final services = SystemServices.fake(audio: audio);
  addTearDown(services.dispose);
  await pumpDesktop(tester, services: services);
  return audio;
}

IconData? _icon(WidgetTester tester) => tester
    .widget<Icon>(find.descendant(of: _indicator, matching: find.byType(Icon)))
    .icon;

const _altShift = [LogicalKeyboardKey.altLeft, LogicalKeyboardKey.shiftLeft];

void main() {
  testWidgets('o ícone segue o volume', (tester) async {
    final audio = await _pump(tester);
    expect(_icon(tester), Icons.volume_down);
    expect(find.byTooltip('Volume: 40%'), findsOneWidget);

    final expectations = {
      const AudioState(available: true, volume: 0.8): Icons.volume_up,
      const AudioState(available: true): Icons.volume_mute,
      const AudioState(available: true, volume: 0.8, muted: true):
          Icons.volume_off,
    };
    for (final MapEntry(key: state, value: icon) in expectations.entries) {
      audio.set(state);
      await tester.pump();
      expect(_icon(tester), icon);
    }

    audio.set(AudioState.unavailable);
    await tester.pump();
    expect(_indicator, findsNothing);
  });

  testWidgets('o painel ajusta o volume e o mudo', (tester) async {
    final audio = await _pump(tester);
    await tester.tap(_indicator);
    await tester.pump();
    expect(_panel, findsOneWidget);
    expect(find.text('40%'), findsOneWidget);

    // Tocar no fim do slider leva perto de 100%
    final slider = tester.getRect(find.byType(Slider));
    await tester.tapAt(slider.centerRight - const Offset(4, 0));
    await tester.pump();
    expect(audio.state.value.volume, greaterThan(0.9));

    await tester.tap(find.byTooltip('Silenciar'));
    await tester.pump();
    expect(audio.state.value.muted, isTrue);
    expect(_icon(tester), Icons.volume_off);
  });

  testWidgets('a roda do mouse sobe e desce 5%', (tester) async {
    final audio = await _pump(tester);
    final center = tester.getCenter(_indicator);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(center));

    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -20)));
    await tester.pump();
    expect(audio.state.value.volume, closeTo(0.45, 1e-9));

    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 20)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 20)));
    await tester.pump();
    expect(audio.state.value.volume, closeTo(0.35, 1e-9));
    expect(_osd, findsNothing);
  });

  testWidgets('Alt+Shift+PageUp e M mostram o aviso de volume', (tester) async {
    final audio = await _pump(tester);
    await pressCombo(tester, _altShift, LogicalKeyboardKey.pageUp);
    expect(audio.state.value.volume, closeTo(0.45, 1e-9));
    expect(_osd, findsOneWidget);
    expect(find.descendant(of: _osd, matching: find.text('45%')), findsOne);

    await pressCombo(tester, _altShift, LogicalKeyboardKey.keyM);
    expect(audio.state.value.muted, isTrue);
    expect(find.descendant(of: _osd, matching: find.text('Mudo')), findsOne);

    await tester.pump(const Duration(milliseconds: 1600));
    expect(_osd, findsNothing);
  });

  testWidgets('teclas de mídia nativas também ajustam', (tester) async {
    final audio = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.audioVolumeDown);
    await tester.pump();
    expect(audio.state.value.volume, closeTo(0.35, 1e-9));
    await tester.sendKeyEvent(LogicalKeyboardKey.audioVolumeMute);
    await tester.pump();
    expect(audio.state.value.muted, isTrue);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('volume e rede abrem um de cada vez', (tester) async {
    await _pump(tester);
    await tester.tap(_indicator);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('network-indicator')));
    await tester.pump();
    expect(find.byType(NetworkPanel), findsOneWidget);
    expect(_panel, findsNothing);

    await tester.tap(_indicator);
    await tester.pump();
    expect(_panel, findsOneWidget);
    expect(find.byType(NetworkPanel), findsNothing);
  });
}
