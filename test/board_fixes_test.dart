import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scinode/screens/boards_screen.dart';
import 'package:scinode/services/board_service.dart';
import 'package:scinode/strings.dart';
import 'package:scinode/widgets/board_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

FirebaseException denied() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');

void main() {
  group('retryDenied', () {
    const fast = [Duration(milliseconds: 1), Duration(milliseconds: 1)];

    test('после отказа переподписывается и получает данные', () async {
      var opened = 0;
      final s = retryDenied<int>(() {
        opened++;
        return opened == 1 ? Stream.error(denied()) : Stream.value(42);
      }, delays: fast);
      expect(await s.first, 42);
      expect(opened, 2);
    });

    test('после всех попыток передаёт ошибку', () async {
      var opened = 0;
      final s = retryDenied<int>(() {
        opened++;
        return Stream.error(denied());
      }, delays: fast);
      await expectLater(s, emitsError(isA<FirebaseException>()));
      expect(opened, 3);
    });

    test('другие ошибки не повторяет', () async {
      var opened = 0;
      final s = retryDenied<int>(() {
        opened++;
        return Stream.error(StateError('x'));
      }, delays: fast);
      await expectLater(s, emitsError(isA<StateError>()));
      expect(opened, 1);
    });
  });

  testWidgets('доску можно удалить из списка через меню «⋮»', (tester) async {
    Strings.instance.lang = 'ru';
    SharedPreferences.setMockInitialValues({});
    MemberNames.lookup = (uid) async => null;
    final db = FakeFirebaseFirestore();
    final svc = BoardService(db: db, uid: () => 'alice', rnd: Random(1));
    await svc.createBoard(
      name: 'Удаляемая',
      template: 'paper',
      color: 1,
      icon: 'article',
      columns: ['Идеи', 'Готово'],
      cards: [('Задача', 0)],
    ).done;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: BoardsScreen(service: svc)));
    await tester.pumpAndSettle();
    expect(find.text('Удаляемая'), findsOneWidget);

    await tester.tap(find.byTooltip('Действия'));
    await tester.pumpAndSettle();
    expect(find.text('В архив'), findsOneWidget);
    await tester.tap(find.text('Удалить доску'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();

    expect((await db.collection('boards').get()).docs, isEmpty);
    expect(find.text('Удаляемая'), findsNothing);
  });
}
