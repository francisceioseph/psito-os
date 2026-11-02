import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/displays_client.dart';
import 'package:psito_settings/displays_section.dart';
import 'package:psito_settings/l10n/settings_localizations.dart';

import 'helpers.dart';

void main() {
  final l = lookupSettingsLocalizations(const Locale('pt'));

  group('snapDisplay', () {
    const other = Rect.fromLTWH(0, 0, 1920, 1080);
    const size = Size(1280, 720);

    test('encosta no lado mais perto', () {
      expect(
        snapDisplay(const Offset(2100, 10) & size, [other]),
        const Offset(1920, 0),
      );
      expect(
        snapDisplay(const Offset(-1500, 500) & size, [other]),
        const Offset(-1280, 500),
      );
      expect(
        snapDisplay(const Offset(100, 1200) & size, [other]),
        const Offset(100, 1080),
      );
    });

    test('solto em cima do outro, sai para fora dele', () {
      final at = snapDisplay(const Offset(1000, 100) & size, [other]);
      expect((at & size).deflate(0.5).overlaps(other), isFalse);
    });

    test('gruda na borda de baixo do vizinho', () {
      expect(
        snapDisplay(const Offset(2000, 340) & size, [other]),
        const Offset(1920, 360),
      );
    });

    test('não cobre um terceiro', () {
      const third = Rect.fromLTWH(1920, 0, 1920, 1080);
      final at = snapDisplay(const Offset(2100, 10) & size, [other, third]);
      final rect = (at & size).deflate(0.5);
      expect(rect.overlaps(other) || rect.overlaps(third), isFalse);
    });

    test('sempre toca alguém, mesmo solto longe', () {
      final at = snapDisplay(const Offset(9000, 9000) & size, [other]);
      expect((at & size).inflate(1).overlaps(other), isTrue);
    });
  });

  test('os tamanhos em comum vêm do maior para o menor', () {
    final [laptop, monitor] = FakeDisplays().list.value;
    final common = commonSizes([laptop, monitor]);
    expect(common.map((m) => m.width), [1920, 1280]);
    expect(
      bestRefresh(monitor.modes, const PsitoDisplayMode(2560, 1440)).refresh,
      144000,
    );
  });

  group('a seção', () {
    late FakeDisplays displays;

    Future<void> pump(WidgetTester tester, {double width = 700}) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pt'),
          theme: psitoTheme(PsitoSettings.defaults.accent),
          localizationsDelegates: SettingsLocalizations.localizationsDelegates,
          supportedLocales: SettingsLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [DisplaysSection(displays: displays)],
            ),
          ),
        ),
      );
    }

    Finder key(String name) => find.byKey(ValueKey(name));
    bool enabled(WidgetTester tester, String name) =>
        tester.widget<ButtonStyleButton>(key(name)).onPressed != null;

    Future<void> choose(
      WidgetTester tester,
      String dropdown,
      String text,
    ) async {
      await tester.tap(key(dropdown));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text).last);
      await tester.pumpAndSettle();
    }

    setUp(() => displays = FakeDisplays());

    testWidgets('sem monitores, avisa', (tester) async {
      displays = FakeDisplays(displays: const []);
      await pump(tester);
      expect(find.text(l.displaysUnavailable), findsOneWidget);
    });

    testWidgets('um monitor só não tem arrumação nem espelhar', (tester) async {
      displays = FakeDisplays(displays: [FakeDisplays().list.value.first]);
      await pump(tester);
      expect(find.text(l.displaysLayout), findsNothing);
      expect(key('displays-mirror'), findsNothing);
      // O único ligado não desliga
      expect(tester.widget<Switch>(key('display-enabled')).onChanged, isNull);
    });

    testWidgets('mudar só muda o rascunho, até aplicar', (tester) async {
      await pump(tester);
      expect(enabled(tester, 'displays-apply'), isFalse);

      await choose(
        tester,
        'display-resolution',
        l.displaysResolutionValue(1280, 720),
      );
      expect(displays.applied, isEmpty);
      expect(enabled(tester, 'displays-apply'), isTrue);

      await tester.tap(key('displays-discard'));
      await tester.pump();
      expect(enabled(tester, 'displays-apply'), isFalse);

      await choose(
        tester,
        'display-resolution',
        l.displaysResolutionValue(1280, 720),
      );
      await tester.tap(key('displays-apply'));
      await tester.pump();
      final sent = displays.applied.single;
      expect(sent.first.mode!.width, 1280);
      // Menor, continua encostado no outro
      expect(sent.first.rect.right, sent.last.rect.left);
      expect(enabled(tester, 'displays-apply'), isFalse);
    });

    testWidgets('arrastar encosta do outro lado', (tester) async {
      await pump(tester);
      await tester.drag(key('display-HDMI-A-1'), const Offset(-500, 0));
      await tester.pump();
      await tester.tap(key('displays-apply'));
      await tester.pump();
      final [laptop, monitor] = displays.applied.single;
      expect(monitor.rect.right, laptop.rect.left);
    });

    testWidgets('as setas movem o selecionado', (tester) async {
      await pump(tester);
      await tester.tap(key('display-HDMI-A-1'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.tap(key('displays-apply'));
      await tester.pump();
      final [laptop, monitor] = displays.applied.single;
      expect(monitor.rect.bottom, laptop.rect.top);
    });

    testWidgets('a rotação troca os lados', (tester) async {
      await pump(tester);
      await choose(tester, 'display-rotation', l.displaysRotationLeft);
      await tester.tap(key('displays-apply'));
      await tester.pump();
      final laptop = displays.applied.single.first;
      expect(laptop.transform, 1);
      expect(laptop.rect.size, const Size(1080, 1920));
    });

    testWidgets('desligar e religar', (tester) async {
      await pump(tester);
      await tester.tap(key('display-chip-HDMI-A-1'));
      await tester.pump();
      await tester.tap(key('display-enabled'));
      await tester.pump();
      expect(key('display-HDMI-A-1'), findsNothing);
      // Sobrou um: ele não desliga
      await tester.tap(key('display-chip-eDP-1'));
      await tester.pump();
      expect(tester.widget<Switch>(key('display-enabled')).onChanged, isNull);

      await tester.tap(key('displays-apply'));
      await tester.pump();
      expect(displays.applied.single.last.enabled, isFalse);
    });

    testWidgets('espelhar usa o maior tamanho em comum', (tester) async {
      await pump(tester);
      await tester.tap(key('displays-mirror'));
      await tester.pump();
      expect(find.text(l.displaysMirrorNote), findsOneWidget);
      expect(find.text(l.displaysLayout), findsNothing);
      await tester.tap(key('displays-apply'));
      await tester.pump();
      final [laptop, monitor] = displays.applied.single;
      expect(laptop.rect, monitor.rect);
      expect(monitor.mode!.width, 1920);

      // E desfazer põe lado a lado de novo
      await tester.tap(key('displays-mirror'));
      await tester.pump();
      await tester.tap(key('displays-apply'));
      await tester.pump();
      final [after, other] = displays.applied.last;
      expect(after.rect.right, other.rect.left);
      expect(other.mode!.width, 2560);
    });

    testWidgets('sem tamanho em comum, não espelha', (tester) async {
      displays = FakeDisplays(
        displays: const [
          PsitoDisplay(
            name: 'a',
            mode: PsitoDisplayMode(1920, 1080),
            modes: [PsitoDisplayMode(1920, 1080)],
          ),
          PsitoDisplay(
            name: 'b',
            x: 1920,
            mode: PsitoDisplayMode(1280, 720),
            modes: [PsitoDisplayMode(1280, 720)],
          ),
        ],
      );
      await pump(tester);
      expect(tester.widget<Switch>(key('displays-mirror')).onChanged, isNull);
      expect(find.text(l.displaysMirrorNone), findsOneWidget);
    });

    testWidgets('o principal vale na hora', (tester) async {
      await pump(tester);
      await tester.tap(key('display-chip-HDMI-A-1'));
      await tester.pump();
      await tester.tap(key('display-make-primary'));
      await tester.pump();
      expect(displays.list.value.last.primary, isTrue);
      expect(find.text(l.displaysIsPrimary), findsOneWidget);
      expect(displays.applied, isEmpty);
    });

    testWidgets('um rascunho sobrevive a uma troca de principal', (
      tester,
    ) async {
      await pump(tester);
      await choose(tester, 'display-rotation', l.displaysRotationInverted);
      await displays.setPrimary('HDMI-A-1');
      await tester.pump();
      expect(enabled(tester, 'displays-apply'), isTrue);
    });

    testWidgets('um monitor novo troca o rascunho pela lista', (tester) async {
      await pump(tester);
      await choose(tester, 'display-rotation', l.displaysRotationInverted);
      displays.list.value = [displays.list.value.first];
      await tester.pump();
      expect(enabled(tester, 'displays-apply'), isFalse);
    });

    testWidgets('diz quando não deu', (tester) async {
      await pump(tester);
      displays.result = PsitoDisplaysResult.failed;
      await choose(tester, 'display-rotation', l.displaysRotationInverted);
      await tester.tap(key('displays-apply'));
      await tester.pump();
      expect(find.text(l.displaysFailed), findsOneWidget);
      // O rascunho continua, para tentar de outro jeito
      expect(enabled(tester, 'displays-apply'), isTrue);

      displays.result = PsitoDisplaysResult.busy;
      await tester.tap(key('displays-apply'));
      await tester.pump();
      expect(find.text(l.displaysBusy), findsOneWidget);
    });

    testWidgets('cabe estreito e tudo tem nome', (tester) async {
      await pump(tester, width: 300);
      expect(tester.takeException(), isNull);
      await expectAllLabeled(tester);
    });
  });
}
