import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' show TtfParser;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scinode/models/board.dart';
import 'package:scinode/models/board_report.dart';
import 'package:scinode/services/motivation_service.dart';
import 'package:scinode/services/report_pdf.dart';
import 'package:scinode/strings.dart';
import 'package:scinode/strings_board.dart';
import 'package:scinode/strings_report.dart';
import 'package:scinode/widgets/focus_timer.dart';

const alice = 'alice', bob = 'bob';

Board board() => const Board(
      id: 'b',
      name: 'Заявка на грант ERC',
      owner: alice,
      members: [alice, bob],
      roles: {alice: BoardRole.owner, bob: BoardRole.editor},
      columns: [
        BoardColumn(id: 'todo', name: 'Подготовка'),
        BoardColumn(id: 'work', name: 'Документы'),
        BoardColumn(id: 'done', name: 'Подано', done: true),
      ],
    );

TaskCard card(String id, String col,
        {DateTime? due,
        DateTime? doneAt,
        DateTime? created,
        List<String> as = const [],
        Map<String, int> focus = const {},
        List<LinkedPaper> pp = const [],
        List<LinkedGrant> gr = const [],
        double o = 1}) =>
    TaskCard(
      id: id,
      boardId: 'b',
      title: 'Задача $id',
      column: col,
      order: o,
      due: due,
      doneAt: doneAt,
      created: created,
      assignees: as,
      focus: focus,
      papers: pp,
      grants: gr,
    );

const paper = LinkedPaper(id: 'W1', title: 'Deep learning', doi: '10.1/x');
const grant = LinkedGrant(
    source: 'eu',
    id: 'G1',
    number: 'ERC-2027-STG',
    title: 'ERC Starting Grant',
    url: 'https://example.org');

void main() {
  final now = DateTime(2026, 11, 5, 15); // четверг

  List<TaskCard> cards() => [
        card('1', 'todo',
            due: DateTime(2026, 11, 1), as: [alice], pp: [paper], o: 1),
        card('2', 'todo', due: DateTime(2026, 11, 20), o: 2),
        card('3', 'work',
            as: [alice, bob],
            focus: {alice: 1500, bob: 600},
            pp: [paper],
            gr: [grant],
            created: DateTime(2026, 11, 2)),
        card('4', 'done',
            due: DateTime(2026, 10, 1),
            doneAt: DateTime(2026, 11, 3, 10),
            as: [bob],
            focus: {bob: 3000},
            gr: [grant]),
        card('5', 'done', doneAt: DateTime(2026, 10, 1), as: [alice]),
        card('6', 'done', doneAt: DateTime(2026, 11, 5, 9)),
      ];

  group('Период отчёта', () {
    test('неделя — последние 7 дней включая сегодня', () {
      final r = ReportRange.of(ReportPeriod.week, now);
      expect(r.from, DateTime(2026, 10, 30));
      expect(r.to, DateTime(2026, 11, 6));
      expect(r.lastDay, DateTime(2026, 11, 5));
      expect(r.contains(DateTime(2026, 10, 30)), isTrue);
      expect(r.contains(DateTime(2026, 11, 5, 23, 59)), isTrue);
      expect(r.contains(DateTime(2026, 11, 6)), isFalse);
      expect(r.contains(DateTime(2026, 10, 29, 23)), isFalse);
      expect(r.contains(null), isFalse);
    });

    test('месяц — последние 30 дней', () {
      final r = ReportRange.of(ReportPeriod.month, now);
      expect(r.from, DateTime(2026, 10, 7));
      expect(r.to.difference(r.from).inDays, 30);
    });

    test('свой период включает оба дня, перепутанные даты меняются местами',
        () {
      final r = ReportRange.of(ReportPeriod.custom, now,
          customFrom: DateTime(2026, 11, 10), customTo: DateTime(2026, 11, 1));
      expect(r.from, DateTime(2026, 11, 1));
      expect(r.to, DateTime(2026, 11, 11));
    });
  });

  group('Статистика отчёта', () {
    final r = BoardReport.of(
        board(), cards(), ReportRange.of(ReportPeriod.week, now), now);

    test('итоги', () {
      expect(r.total, 6);
      expect(r.done, 3);
      expect(r.open, 3);
      expect(r.percent, 50);
      // Просрочена только незавершённая 1; выполненная 4 — нет.
      expect(r.overdue, 1);
      expect(r.overdueCards.map((c) => c.id), ['1']);
      expect(r.doneInPeriod, 2);
      expect(r.createdInPeriod, 1);
    });

    test('выполненные за период — по дате выполнения', () {
      expect(r.completed.map((c) => c.id), ['4', '6']);
    });

    test('колонки в порядке доски', () {
      expect(r.columns.map((c) => c.column.id), ['todo', 'work', 'done']);
      expect(r.columns.map((c) => c.cards.length), [2, 1, 3]);
      expect(r.columns.first.cards.map((c) => c.id), ['1', '2']);
    });

    test('участники и «без исполнителя» в конце', () {
      expect(r.members.map((m) => m.uid), [alice, bob, '']);
      final a = r.members[0], b = r.members[1], none = r.members[2];
      expect([a.open, a.done, a.overdue, a.doneInPeriod, a.focus],
          [2, 1, 1, 0, 1500]);
      expect([b.open, b.done, b.overdue, b.doneInPeriod, b.focus],
          [1, 1, 0, 1, 3600]);
      expect([none.open, none.done, none.doneInPeriod], [1, 1, 1]);
    });

    test('статьи и гранты без повторов, с карточками', () {
      expect(r.papers.length, 1);
      expect(r.papers.first.cards, ['Задача 1', 'Задача 3']);
      expect(r.grants.length, 1);
      expect(r.grants.first.cards, ['Задача 3', 'Задача 4']);
    });

    test('фокус: по убыванию, сумма', () {
      expect(r.focusCards.map((f) => f.card.id), ['4', '3']);
      expect(r.focusTotal, 5100);
      expect(hoursMinutes(5100), (1, 25));
    });

    test('по неделям: последняя неделя справа', () {
      // 4 и 6 — эта неделя; 5 — 1 октября (5 недель назад, не попадает).
      expect(r.weekly, [0, 0, 0, 2]);
    });

    test('пустая доска', () {
      final e = BoardReport.of(
          board(), const [], ReportRange.of(ReportPeriod.week, now), now);
      expect(e.total, 0);
      expect(e.percent, 0);
      expect(e.members.map((m) => m.uid), [alice, bob]);
      expect(e.weekly, [0, 0, 0, 0]);
    });
  });

  test('readFocus отбрасывает мусор', () {
    expect(
        readFocus({'a': 60, 'b': -5, 'c': 'x', 'd': 1.7}), {'a': 60, 'd': 1});
    expect(readFocus(null), isEmpty);
    expect(
        TaskCard.fromMap('c', 'b', {
          't': 'x',
          'ft': {alice: 120}
        }).focusTotal,
        120);
  });

  group('Серия и недельная цель', () {
    test('серия считает дни подряд и не сгорает до конца сегодняшнего дня', () {
      final s = MotivationState();
      for (final d in [1, 2, 3, 4]) {
        s.markActive(DateTime(2026, 11, d, 10));
      }
      // Сегодня (5-е) ещё ничего не делали — серия 4.
      expect(s.streak(now), 4);
      s.markActive(now);
      expect(s.streak(now), 5);
      // Пропуск дня обнуляет.
      expect(s.streak(DateTime(2026, 11, 7)), 0);
    });

    test('серия через границу месяца', () {
      final s = MotivationState()
        ..markActive(DateTime(2026, 10, 31))
        ..markActive(DateTime(2026, 11, 1));
      expect(s.streak(DateTime(2026, 11, 1, 20)), 2);
    });

    test('неделя начинается в понедельник', () {
      expect(MotivationState.weekStart(now), DateTime(2026, 11, 2));
      expect(MotivationState.weekStart(DateTime(2026, 11, 2)),
          DateTime(2026, 11, 2));
      expect(MotivationState.weekStart(DateTime(2026, 11, 8, 23)),
          DateTime(2026, 11, 2));
    });

    test('задача засчитывается один раз за неделю', () {
      final s = MotivationState(goal: 2);
      expect(s.markDone('b/1', now), isTrue);
      expect(s.markDone('b/1', now), isFalse);
      expect(s.markDone('b/2', now), isTrue);
      expect(s.doneThisWeek(now), 2);
      // Прошлая неделя не считается.
      s.done['b/old'] = '2026-10-28';
      expect(s.doneThisWeek(now), 2);
      // На следующей неделе та же задача засчитывается снова.
      expect(s.markDone('b/1', DateTime(2026, 11, 10)), isTrue);
    });

    test('сохранение и чистка', () {
      final s = MotivationState(goal: 7)
        ..markActive(DateTime(2025, 1, 1))
        ..markActive(now)
        ..markDone('b/1', DateTime(2026, 10, 1));
      s.prune(now);
      expect(s.days, {'2026-10-01', '2026-11-05'});
      expect(s.done, isEmpty);
      final back = MotivationState.fromJson(s.toJson());
      expect(back.goal, 7);
      expect(back.days, s.days);
      expect(
          MotivationState.fromJson({'g': 999}).goal, MotivationState.maxGoal);
      expect(
          MotivationState.fromJson('мусор').goal, MotivationState.defaultGoal);
    });

    test('сервис сообщает о достижении цели один раз', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final m = MotivationService.test()..clock = () => now;
      await m.setGoal(2);
      expect(m.taskDone('b', '1').goalReached, isFalse);
      expect(m.taskDone('b', '2').goalReached, isTrue);
      expect(m.taskDone('b', '3').goalReached, isFalse);
      expect(m.doneThisWeek, 3);
      expect(m.streak, 1);
    });
  });

  group('Таймер фокуса', () {
    final t0 = DateTime(2026, 11, 5, 10);

    test('25 минут работы, затем перерыв; время работы копится', () {
      final c = FocusClock()..start(t0);
      expect(c.left(t0.add(const Duration(minutes: 5))),
          const Duration(minutes: 20));
      expect(c.tick(t0.add(const Duration(minutes: 24))), isFalse);
      expect(c.tick(t0.add(const Duration(minutes: 25, seconds: 3))), isTrue);
      expect(c.resting, isTrue);
      expect(c.unsaved, 1500);
      // Перерыв не считается работой.
      expect(c.pending(t0.add(const Duration(minutes: 28))), 1500);
      expect(c.tick(t0.add(const Duration(minutes: 31))), isTrue);
      expect(c.resting, isFalse);
    });

    test('пауза останавливает отсчёт', () {
      final c = FocusClock()..start(t0);
      c.pause(t0.add(const Duration(minutes: 10)));
      expect(c.unsaved, 600);
      expect(c.left(t0.add(const Duration(hours: 2))),
          const Duration(minutes: 15));
      c.start(t0.add(const Duration(hours: 2)));
      expect(c.pending(t0.add(const Duration(hours: 2, minutes: 5))), 900);
    });

    test('take забирает время и продолжает отсчёт', () {
      final c = FocusClock()..start(t0);
      expect(c.take(t0.add(const Duration(minutes: 7))), 420);
      expect(c.unsaved, 0);
      expect(c.left(t0.add(const Duration(minutes: 10))),
          const Duration(minutes: 15));
      // Больше длины фазы не записываем, даже если телефон «проспал».
      expect(c.take(t0.add(const Duration(hours: 3))), 1080);
    });
  });

  group('PDF-отчёт', () {
    late ReportFonts fonts;
    late TtfParser regular;

    setUpAll(() {
      ByteData read(String f) =>
          ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync());
      fonts = ReportFonts.fromBytes(
          read('NotoSans-Regular.ttf'), read('NotoSans-Bold.ttf'));
      regular = TtfParser(read('NotoSans-Regular.ttf'));
    });

    test('в шрифте есть все буквы текстов отчёта (ru, uz, en)', () {
      final missing = <String>{};
      final texts = [
        for (final e in reportStrings.entries)
          if (e.key.startsWith('rp.') || e.key.startsWith('fo.')) ...e.value,
        ...boardStrings['bd.f.nobody']!,
        ...boardStrings['bd.unknown_user']!,
        for (var p = 0; p < 4; p++) ...boardStrings['bd.p.$p']!,
        'ЁёЎўҚқҒғҲҳ Oʻzbekiston Gʻ oʼ — · ‘’ “”',
      ];
      for (final s in texts) {
        for (final r in s.runes) {
          if (r > 32 && !regular.charToGlyphIndexMap.containsKey(r)) {
            missing.add(String.fromCharCode(r));
          }
        }
      }
      expect(missing, isEmpty);
    });

    for (final lang in ['ru', 'uz', 'en']) {
      test('собирается на языке $lang', () async {
        Strings.instance.lang = lang;
        final r = BoardReport.of(
            board(), cards(), ReportRange.of(ReportPeriod.month, now), now);
        final bytes = await buildReportPdf(
          r,
          sections: ReportSection.values.toSet(),
          names: {alice: 'Алиса Каримова', bob: 'Bobur Oʻrinov'},
          fonts: fonts,
          lang: lang,
        );
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
        expect(bytes.length, greaterThan(10000));
        // Для ручной проверки: REPORT_PDF_OUT=/путь flutter test ...
        final out = Platform.environment['REPORT_PDF_OUT'];
        if (out != null) File('$out/report_$lang.pdf').writeAsBytesSync(bytes);
      });
    }

    test('только обложка, если разделы не выбраны', () async {
      Strings.instance.lang = 'ru';
      final r = BoardReport.of(
          board(), const [], ReportRange.of(ReportPeriod.week, now), now);
      final bytes = await buildReportPdf(r,
          sections: const {}, names: const {}, fonts: fonts, lang: 'ru');
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
