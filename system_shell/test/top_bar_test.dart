import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/widgets/top_bar.dart';

import 'helpers.dart';

import 'package:psito_sdk/psito_sdk.dart';

Future<void> _pumpBar(WidgetTester tester, TopBar bar) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: testL10nDelegates,
    supportedLocales: psitoLocales,
    home: Scaffold(body: bar),
  ),
);

final _bell = find.byKey(const ValueKey('notifications-bell'));

void main() {
  testWidgets('Menu e sino chamam os callbacks', (tester) async {
    var menu = 0, bell = 0;
    await _pumpBar(
      tester,
      TopBar(onMenuTap: () => menu++, onNotificationsTap: () => bell++),
    );

    await tester.tap(find.text('Menu'));
    await tester.tap(_bell);
    expect((menu, bell), (1, 1));
  });

  testWidgets('o badge só aparece com notificações não lidas', (tester) async {
    await _pumpBar(tester, const TopBar());
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    expect(find.byIcon(Icons.notifications_none), findsOneWidget);

    await _pumpBar(tester, const TopBar(unreadCount: 3));
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
    expect(
      find.descendant(of: _bell, matching: find.text('3')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.notifications_active), findsOneWidget);
  });

  testWidgets('Não perturbe troca o ícone do sino', (tester) async {
    await _pumpBar(tester, const TopBar(unreadCount: 2, doNotDisturb: true));
    expect(find.byIcon(Icons.notifications_off), findsOneWidget);
  });
}
