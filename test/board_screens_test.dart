import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scinode/models/board.dart';
import 'package:scinode/models/grant.dart';
import 'package:scinode/screens/board_screen.dart';
import 'package:scinode/screens/boards_screen.dart';
import 'package:scinode/screens/card_sheet.dart';
import 'package:scinode/screens/grant_to_board.dart';
import 'package:scinode/screens/my_tasks_screen.dart';
import 'package:scinode/services/board_service.dart';
import 'package:scinode/strings.dart';
import 'package:scinode/widgets/board_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const alice = 'alice', bob = 'bob';

void main() {
  late FakeFirebaseFirestore db;
  BoardService svc(String uid) =>
      BoardService(db: db, uid: () => uid, rnd: Random(7));

  setUp(() {
    Strings.instance.lang = 'ru';
    db = FakeFirebaseFirestore();
    SharedPreferences.setMockInitialValues({});
    MemberNames.lookup = (uid) async => null;
  });

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  Future<String> makeBoard(
      {String owner = alice, List<(String, int)> cards = const []}) async {
    final r = svc(owner).createBoard(
      name: 'Статья в журнал',
      template: 'paper',
      color: 1,
      icon: 'article',
      columns: ['Идеи', 'Черновик', 'Готово'],
      cards: cards,
    );
    await r.done;
    return r.id;
  }

  testWidgets('пустой список досок и создание доски по шаблону',
      (tester) async {
    await pumpApp(tester, BoardsScreen(service: svc(alice)));
    expect(find.text('Пока нет досок'), findsOneWidget);

    await tester.tap(find.text('Новая доска').first);
    await tester.pumpAndSettle();
    expect(find.text('Выберите шаблон'), findsOneWidget);
    await tester.tap(find.text('Заявка на грант'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Создать'));
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();

    // Открылась доска с колонками шаблона и стартовыми карточками.
    expect(find.text('Подготовка'), findsWidgets);
    expect(
        find.text('Проверить условия участия (eligibility)'), findsOneWidget);
    final boards = await db.collection('boards').get();
    expect(boards.docs.single['tpl'], 'grant');
  });

  testWidgets('доска: добавить задачу и перенести стрелкой в следующую колонку',
      (tester) async {
    final id = await makeBoard();
    await pumpApp(tester, BoardScreen(boardId: id, service: svc(alice)));
    expect(find.text('Идеи'), findsOneWidget);

    await tester.tap(find.text('Добавить задачу').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Собрать литературу');
    await tester.tap(find.text('Готово').last);
    await tester.pumpAndSettle();
    expect(find.text('Собрать литературу'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_forward).first);
    await tester.pumpAndSettle();
    final cards =
        await db.collection('boards').doc(id).collection('cards').get();
    final b = Board.fromMap(
        id, (await db.collection('boards').doc(id).get()).data()!);
    expect(cards.docs.single['col'], b.columns[1].id);
    expect(find.text('Перемещено в «Черновик»'), findsOneWidget);
  });

  testWidgets('перетаскивание карточки в другую колонку', (tester) async {
    final id = await makeBoard(cards: [('Задача А', 0)]);
    await pumpApp(tester, BoardScreen(boardId: id, service: svc(alice)));
    final card = find.text('Задача А');
    expect(card, findsOneWidget);
    // Тянем долгим нажатием к правому краю — доска листается на «Черновик».
    final g = await tester.startGesture(tester.getCenter(card));
    await tester.pump(const Duration(milliseconds: 600));
    final w = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    await g.moveTo(Offset(w - 10, 400));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await g.moveTo(Offset(w / 2, 400));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    final b = Board.fromMap(
        id, (await db.collection('boards').doc(id).get()).data()!);
    final cards =
        await db.collection('boards').doc(id).collection('cards').get();
    expect(cards.docs.single['col'], b.columns[1].id);
  });

  testWidgets('наблюдатель видит доску, но не может менять', (tester) async {
    final id = await makeBoard(cards: [('Задача А', 0)]);
    var b = Board.fromMap(
        id, (await db.collection('boards').doc(id).get()).data()!);
    await svc(alice).addMember(b, bob, BoardRole.viewer);
    await pumpApp(tester, BoardScreen(boardId: id, service: svc(bob)));
    expect(find.text('Вы наблюдатель: можно только смотреть'), findsOneWidget);
    expect(find.text('Добавить задачу'), findsNothing);
    expect(find.byIcon(Icons.arrow_forward), findsNothing);
  });

  testWidgets('окно задачи: приоритет, чек-лист, комментарий', (tester) async {
    final id = await makeBoard(cards: [('Задача А', 0)]);
    final cid =
        (await db.collection('boards').doc(id).collection('cards').get())
            .docs
            .single
            .id;
    await pumpApp(
        tester,
        Scaffold(
            body: CardSheet(boardId: id, cardId: cid, service: svc(alice))));
    expect(find.text('Задача А'), findsOneWidget);

    await tester.tap(find.text('Срочный'));
    await tester.pumpAndSettle();
    final scroll = find.byType(Scrollable).first;
    final addItem = find.widgetWithText(TextField, 'Добавить пункт');
    await tester.scrollUntilVisible(addItem, 200, scrollable: scroll);
    await tester.enterText(addItem, 'Прочитать 5 статей');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Прочитать 5 статей'), findsOneWidget);
    await tester.ensureVisible(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    final comment = find.widgetWithText(TextField, 'Написать комментарий');
    await tester.scrollUntilVisible(comment, 200, scrollable: scroll);
    await tester.enterText(comment, 'Начинаю');
    await tester.tap(find.byTooltip('Отправить'));
    await tester.pumpAndSettle();

    final c = TaskCard.fromMap(
        cid,
        id,
        (await db
                .collection('boards')
                .doc(id)
                .collection('cards')
                .doc(cid)
                .get())
            .data()!);
    expect(c.priority, 3);
    expect(c.checklist.single.done, isTrue);
    expect(find.text('Начинаю'), findsOneWidget);
  });

  testWidgets('мои задачи и плашка на Главной', (tester) async {
    final now = DateTime.now();
    final id = await makeBoard();
    final b = Board.fromMap(
        id, (await db.collection('boards').doc(id).get()).data()!);
    await svc(alice)
        .addCard(b, const [], b.columns[0].id, 'Просроченная',
            due: now.subtract(const Duration(days: 2)))
        .done;
    await svc(alice)
        .addCard(b, const [], b.columns[0].id, 'Сегодняшняя', due: now)
        .done;
    await svc(alice)
        .addCard(b, const [], b.columns[2].id, 'Сделанная', due: now)
        .done;

    await pumpApp(tester, Scaffold(body: TodayBanner(service: svc(alice))));
    expect(find.text('Сегодня: 1 · просрочено: 1'), findsOneWidget);

    await pumpApp(tester, MyTasksScreen(service: svc(alice)));
    expect(find.text('Просрочено'), findsOneWidget);
    expect(find.text('Просроченная'), findsOneWidget);
    expect(find.text('Сегодняшняя'), findsOneWidget);
    expect(find.text('Сделанная'), findsNothing);
  });

  group('Связка с грантами', () {
    GrantCall call(DateTime? deadline) => GrantCall(
          source: GrantSource.grantsGov,
          id: '364012',
          number: 'G27AS00164',
          title: 'Water Resources Research Act Program',
          url: 'https://www.grants.gov/search-results-detail/364012',
          status: CallStatus.open,
          deadline: deadline,
        );

    test('контрольные точки только в будущем', () {
      final now = DateTime(2026, 11, 5);
      final plan = grantPlan(call(DateTime(2026, 11, 25)), now);
      // 30 дней назад — уже прошло; 14 и 7 — впереди.
      expect(plan.length, 3);
      expect(plan[0].due, DateTime(2026, 11, 11));
      expect(plan[1].due, DateTime(2026, 11, 18));
      final submit = plan.last;
      expect(submit.column, 3);
      expect(submit.due, DateTime(2026, 11, 25));
      expect(submit.grants.single.url,
          'https://www.grants.gov/search-results-detail/364012');
      expect(submit.title, startsWith('Подать заявку: Water'));
    });

    test('без дедлайна — только карточка подачи', () {
      final plan = grantPlan(call(null), DateTime(2026, 11, 5));
      expect(plan.single.due, isNull);
    });

    test('колонка подачи есть в шаблоне заявки', () {
      expect(templateOf('grant').columns[3], 'check');
    });
  });
}
