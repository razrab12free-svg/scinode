import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scinode/models/profile.dart';
import 'package:scinode/models/taxonomy.dart';
import 'package:scinode/screens/home_shell.dart';
import 'package:scinode/strings.dart';
import 'package:scinode/widgets/scientist_card.dart';

/// Узкий телефон (320 dp) с крупным шрифтом (120%): вёрстка не должна ломаться.
Future<void> _pumpNarrow(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(640, 1280);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    builder: (c, w) => MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.2)),
      child: w!,
    ),
    home: home,
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['ru', 'uz', 'en']) {
    testWidgets('плитки главной помещаются ($lang)', (tester) async {
      Strings.instance.lang = lang;
      await _pumpNarrow(tester, Scaffold(body: HomeTab(onGo: (_) {})));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('длинные направления в карточке участника не вылезают',
      (tester) async {
    Strings.instance.lang = 'uz';
    final p = UserProfile(
      uid: 'x',
      name: 'Abdurakhmonov Muhammadjon Abdullayevich',
      org: 'National University of Uzbekistan named after Mirzo Ulugbek',
      country: 'UZ',
      tags: const [
        TagRef(tag: 's3104', name: 'Condensed Matter Physics and Materials'),
      ],
    );
    await _pumpNarrow(
      tester,
      Scaffold(
        body: ListView(
          children: [MemberCard(p: p, isMe: true, onTap: () {})],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
