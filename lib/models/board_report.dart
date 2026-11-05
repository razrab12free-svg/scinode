/// Сводка и данные PDF-отчёта по доске (чистые вычисления, без Flutter).
library;

import 'board.dart';

// ---------------------------------------------------------------- период

enum ReportPeriod { week, month, custom }

/// Полуинтервал дат [from, to): from — начало первого дня, to — начало дня
/// после последнего.
class ReportRange {
  const ReportRange(this.from, this.to);
  final DateTime from;
  final DateTime to;

  /// Последний включённый день (для подписи периода).
  DateTime get lastDay => to.subtract(const Duration(days: 1));

  bool contains(DateTime? d) {
    if (d == null) return false;
    final l = d.toLocal();
    return !l.isBefore(from) && l.isBefore(to);
  }

  /// Неделя — последние 7 дней, месяц — последние 30 дней (включая сегодня).
  /// Свой — с [customFrom] по [customTo] включительно.
  factory ReportRange.of(ReportPeriod p, DateTime now,
      {DateTime? customFrom, DateTime? customTo}) {
    final today = dayOf(now);
    final end = today.add(const Duration(days: 1));
    switch (p) {
      case ReportPeriod.week:
        return ReportRange(today.subtract(const Duration(days: 6)), end);
      case ReportPeriod.month:
        return ReportRange(today.subtract(const Duration(days: 29)), end);
      case ReportPeriod.custom:
        var a = dayOf(customFrom ?? today);
        var b = dayOf(customTo ?? today);
        if (b.isBefore(a)) (a, b) = (b, a);
        return ReportRange(a, b.add(const Duration(days: 1)));
    }
  }
}

DateTime dayOf(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

// --------------------------------------------------------------- разделы

/// Разделы отчёта (порядок — порядок в PDF).
enum ReportSection {
  summary,
  columns,
  members,
  completed,
  overdue,
  links,
  focus
}

// ----------------------------------------------------------------- строки

class ColumnRow {
  const ColumnRow(this.column, this.cards);
  final BoardColumn column;
  final List<TaskCard> cards;
}

class MemberRow {
  const MemberRow({
    required this.uid,
    required this.open,
    required this.done,
    required this.overdue,
    required this.doneInPeriod,
    required this.focus,
  });

  /// uid участника; '' — задачи без исполнителя.
  final String uid;
  final int open;
  final int done;
  final int overdue;
  final int doneInPeriod;

  /// Время фокуса участника по всем карточкам доски, секунды.
  final int focus;
}

class PaperRow {
  const PaperRow(this.paper, this.cards);
  final LinkedPaper paper;

  /// Названия карточек, к которым привязана статья.
  final List<String> cards;
}

class GrantRow {
  const GrantRow(this.grant, this.cards);
  final LinkedGrant grant;
  final List<String> cards;
}

class FocusRow {
  const FocusRow(this.card, this.seconds);
  final TaskCard card;
  final int seconds;
}

// ----------------------------------------------------------------- отчёт

class BoardReport {
  const BoardReport({
    required this.board,
    required this.range,
    required this.generated,
    required this.total,
    required this.done,
    required this.overdue,
    required this.doneInPeriod,
    required this.createdInPeriod,
    required this.columns,
    required this.members,
    required this.completed,
    required this.overdueCards,
    required this.papers,
    required this.grants,
    required this.focusCards,
    required this.weekly,
  });

  final Board board;
  final ReportRange range;
  final DateTime generated;

  final int total;
  final int done;
  final int overdue;
  final int doneInPeriod;
  final int createdInPeriod;

  final List<ColumnRow> columns;

  /// Участники доски (по порядку участников), затем «без исполнителя»,
  /// если такие задачи есть.
  final List<MemberRow> members;

  /// Выполненные за период, по дате выполнения.
  final List<TaskCard> completed;

  /// Просроченные (не выполненные), самые старые сроки сверху.
  final List<TaskCard> overdueCards;
  final List<PaperRow> papers;
  final List<GrantRow> grants;

  /// Карточки со временем фокуса, по убыванию времени.
  final List<FocusRow> focusCards;

  /// Выполнено по неделям (4 последние недели до конца периода,
  /// самая старая первой).
  final List<int> weekly;

  int get open => total - done;
  int get percent => total == 0 ? 0 : (done * 100 / total).round();
  int get focusTotal => focusCards.fold(0, (a, r) => a + r.seconds);

  factory BoardReport.of(
    Board b,
    List<TaskCard> cards,
    ReportRange range,
    DateTime now,
  ) {
    var done = 0, overdue = 0, doneInPeriod = 0, createdInPeriod = 0;
    final completed = <TaskCard>[];
    final overdueCards = <TaskCard>[];
    final papers = <String, (LinkedPaper, List<String>)>{};
    final grants = <String, (LinkedGrant, List<String>)>{};
    final focusCards = <FocusRow>[];

    // Участники: open, done, overdue, doneInPeriod, focus.
    final stats = <String, List<int>>{
      for (final m in b.members) m: [0, 0, 0, 0, 0],
    };
    List<int> row(String uid) => stats.putIfAbsent(uid, () => [0, 0, 0, 0, 0]);

    for (final c in cards) {
      final isDone = b.isDoneColumn(c.column);
      final late = !isDone && dueState(c.due, now) == DueState.overdue;
      final inPeriod = isDone && range.contains(c.doneAt);
      if (isDone) done++;
      if (late) {
        overdue++;
        overdueCards.add(c);
      }
      if (inPeriod) {
        doneInPeriod++;
        completed.add(c);
      }
      if (range.contains(c.created)) createdInPeriod++;

      final who = c.assignees.isEmpty ? const [''] : c.assignees;
      for (final a in who) {
        final r = row(a);
        if (isDone) {
          r[1]++;
        } else {
          r[0]++;
        }
        if (late) r[2]++;
        if (inPeriod) r[3]++;
      }
      for (final e in c.focus.entries) {
        row(e.key)[4] += e.value;
      }
      if (c.focusTotal > 0) focusCards.add(FocusRow(c, c.focusTotal));

      for (final p in c.papers) {
        papers.putIfAbsent(p.id, () => (p, <String>[])).$2.add(c.title);
      }
      for (final g in c.grants) {
        grants
            .putIfAbsent('${g.source}/${g.id}', () => (g, <String>[]))
            .$2
            .add(c.title);
      }
    }

    completed.sort((a, b) => a.doneAt!.compareTo(b.doneAt!));
    overdueCards.sort((a, b) => a.due!.compareTo(b.due!));
    focusCards.sort((a, b) => b.seconds.compareTo(a.seconds));

    // Без исполнителя — только если такие задачи есть, и всегда в конце.
    final none = stats.remove('');
    final members = [
      for (final e in stats.entries)
        MemberRow(
          uid: e.key,
          open: e.value[0],
          done: e.value[1],
          overdue: e.value[2],
          doneInPeriod: e.value[3],
          focus: e.value[4],
        ),
      if (none != null && none.take(4).any((x) => x > 0))
        MemberRow(
          uid: '',
          open: none[0],
          done: none[1],
          overdue: none[2],
          doneInPeriod: none[3],
          focus: 0,
        ),
    ];

    return BoardReport(
      board: b,
      range: range,
      generated: now,
      total: cards.length,
      done: done,
      overdue: overdue,
      doneInPeriod: doneInPeriod,
      createdInPeriod: createdInPeriod,
      columns: [
        for (final col in b.columns) ColumnRow(col, cardsIn(cards, col.id))
      ],
      members: members,
      completed: completed,
      overdueCards: overdueCards,
      papers: [for (final v in papers.values) PaperRow(v.$1, v.$2)],
      grants: [for (final v in grants.values) GrantRow(v.$1, v.$2)],
      focusCards: focusCards,
      weekly: weeklyDone(b, cards, range.to, weeks: 4),
    );
  }
}

/// Сколько задач выполнено в каждую из [weeks] семидневок, заканчивающихся
/// перед [end] (самая старая первой).
List<int> weeklyDone(Board b, List<TaskCard> cards, DateTime end,
    {int weeks = 4}) {
  final out = List.filled(weeks, 0);
  for (final c in cards) {
    final d = c.doneAt;
    if (d == null || !b.isDoneColumn(c.column)) continue;
    final l = d.toLocal();
    if (!l.isBefore(end)) continue;
    final ago = end.difference(l).inHours ~/ (24 * 7);
    if (ago < weeks) out[weeks - 1 - ago]++;
  }
  return out;
}

/// «1 ч 25 мин» → части (часы, минуты) для подписей.
(int, int) hoursMinutes(int seconds) {
  final m = (seconds / 60).round();
  return (m ~/ 60, m % 60);
}
