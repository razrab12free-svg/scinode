import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scinode/models/board.dart';
import 'package:scinode/screens/board_report_sheet.dart';
import 'package:scinode/screens/board_screen.dart';
import 'package:scinode/screens/board_summary_screen.dart';
import 'package:scinode/screens/card_sheet.dart';
import 'package:scinode/services/board_service.dart';
import 'package:scinode/services/motivation_service.dart';
import 'package:scinode/strings.dart';
import 'package:scinode/widgets/board_widgets.dart';
import 'package:scinode/widgets/focus_timer.dart';
import 'package:shared_preferences/shared_preferences.dart';

const alice = 'alice';

void main() {
  late FakeFirebaseFirestore db;
  BoardService svc() => BoardService(db: db, uid: () => alice, rnd: Random(3));

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

  Future<String> makeBoard(List<(String, int)> cards) async {
    final r = svc().createBoard(
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

  Future<List<TaskCard>> cardsOf(String id) async => [
        for (final d
            in (await db.collection('boards').doc(id).collection('cards').get())
                .docs)
          TaskCard.fromMap(d.id, id, d.data()),
      ];

  test('addFocus прибавляет моё время и ограничивает сеанс 4 часами', () async {
    final id = await makeBoard([('Задача', 0)]);
    final c = (await cardsOf(id)).single;
    await svc().addFocus(id, c.id, 1500);
    await svc().addFocus(id, c.id, 600);
    await svc().addFocus(id, c.id, 0);
    expect((await cardsOf(id)).single.focus, {alice: 2100});
    await svc().addFocus(id, c.id, 99999);
    expect((await cardsOf(id)).single.focus[alice], 2100 + maxFocusSession);
  });

  test('имя файла отчёта без запрещённых символов', () {
    expect(reportFileName('Статья: обзор / 2026?', DateTime(2026, 11, 5)),
        'Scinode_Статья_обзор_2026_2026-11-05.pdf');
  });

  testWidgets('сводка доски: прогресс, колонки, кнопка отчёта', (tester) async {
    final id = await makeBoard([('Первая', 0), ('Вторая', 2)]);
    await pumpApp(tester, BoardScreen(boardId: id, service: svc()));
    await tester.tap(find.byTooltip('Сводка'));
    await tester.pumpAndSettle();

    expect(find.byType(BoardSummaryScreen), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Всего задач: 2'), findsOneWidget);
    expect(find.text('По колонкам'), findsOneWidget);
    expect(find.text('Черновик'), findsOneWidget);

    // Настройка отчёта: период и разделы.
    await tester.tap(find.text('PDF-отчёт'));
    await tester.pumpAndSettle();
    expect(find.text('Отчёт по доске'), findsOneWidget);
    expect(find.text('Неделя'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(7));
    for (final s in ['Итоги', 'Задачи по колонкам', 'Время фокуса']) {
      expect(find.text(s), findsOneWidget);
    }
    // Без разделов отчёт не создаётся.
    for (var i = 0; i < 7; i++) {
      await tester.ensureVisible(find.byType(CheckboxListTile).at(i));
      await tester.tap(find.byType(CheckboxListTile).at(i));
      await tester.pump();
    }
    await tester.ensureVisible(find.text('Создать отчёт'));
    await tester.tap(find.text('Создать отчёт'));
    await tester.pump();
    expect(find.text('Выберите хотя бы один раздел'), findsOneWidget);
  });

  testWidgets('перенос в «Готово» — праздник и счёт недельной цели',
      (tester) async {
    await MotivationService.instance.ensureLoaded();
    final before = MotivationService.instance.doneThisWeek;
    final id = await makeBoard([('Задача', 1)]);
    await pumpApp(tester, BoardScreen(boardId: id, service: svc()));
    // Карточка во второй колонке: листаем и жмём стрелку.
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_forward).first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Готово!'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.textContaining('Готово!'), findsNothing);
    expect(MotivationService.instance.doneThisWeek, before + 1);
    expect(MotivationService.instance.activeToday, isTrue);
  });

  testWidgets('окно задачи: таймер фокуса и праздник за чек-лист',
      (tester) async {
    final id = await makeBoard([('Задача', 0)]);
    final cid = (await cardsOf(id)).single.id;
    await svc().setChecklist(id, cid, const [ChecklistItem('Один')]);
    await pumpApp(tester,
        Scaffold(body: CardSheet(boardId: id, cardId: cid, service: svc())));

    expect(find.text('Время фокуса'), findsOneWidget);
    expect(find.textContaining('Пока не засекали'), findsOneWidget);

    // Закрываем единственный пункт — праздник.
    await tester.ensureVisible(find.text('Один'));
    await tester.tap(find.byType(Checkbox));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Чек-лист закрыт! ✅'), findsOneWidget);
    await tester.pumpAndSettle();

    // Таймер: 25:00, пауза, стоп (меньше минуты — не записываем).
    await tester.ensureVisible(find.text('Фокус 25 мин'));
    await tester.tap(find.text('Фокус 25 мин'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(FocusTimerSheet), findsOneWidget);
    expect(find.text('Работаем'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^2[45]:')), findsOneWidget);
    await tester.tap(find.text('Пауза'));
    await tester.pump();
    expect(find.text('Продолжить'), findsOneWidget);
    await tester.tap(find.text('Стоп'));
    await tester.pumpAndSettle();
    expect(find.byType(FocusTimerSheet), findsNothing);
    expect((await cardsOf(id)).single.focus, isEmpty);
  });

  test('подписи времени фокуса', () {
    Strings.instance.lang = 'ru';
    expect(focusLabel(59), '0 мин');
    expect(focusLabel(1500), '25 мин');
    expect(focusLabel(5100), '1 ч 25 мин');
    Strings.instance.lang = 'uz';
    expect(focusLabel(3600), '1 soat 0 daq');
  });
}
