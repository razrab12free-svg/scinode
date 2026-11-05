/// Модели канбан-досок (Firestore `boards`, `boards/{id}/cards`, ...).
library;

import 'chat.dart' show readTime;

// ---------------------------------------------------------------- роли

enum BoardRole { owner, editor, viewer }

BoardRole? roleFrom(dynamic v) => switch (v) {
      'owner' => BoardRole.owner,
      'editor' => BoardRole.editor,
      'viewer' => BoardRole.viewer,
      _ => null,
    };

// ------------------------------------------------------------- лимиты

const maxBoardName = 80;
const maxColumns = 12;
const maxLabels = 20;
const maxMembers = 20;
const maxCardTitle = 200;
const maxCardDesc = 5000;
const maxChecklist = 50;
const maxChecklistText = 300;
const maxPapers = 20;
const maxGrants = 10;
const maxComment = 2000;

/// Цвета досок и меток (индексы хранятся в Firestore).
const boardColors = [
  0xFF5B4BFF,
  0xFF3B82F6,
  0xFF06B6D4,
  0xFF10B981,
  0xFF84CC16,
  0xFFF59E0B,
  0xFFF97316,
  0xFFEF4444,
  0xFFEC4899,
  0xFF8B5CF6,
  0xFF64748B,
  0xFFA16207,
];

/// Иконки досок (ключ → иконка задаётся в интерфейсе).
const boardIcons = [
  'science',
  'article',
  'payments',
  'school',
  'groups',
  'biotech',
  'calculate',
  'public',
  'menu_book',
  'lightbulb',
  'rocket',
  'flag',
];

// ----------------------------------------------------------- колонки

class BoardColumn {
  const BoardColumn({
    required this.id,
    required this.name,
    this.limit = 0,
    this.done = false,
  });
  final String id;
  final String name;

  /// Лимит карточек (0 — без лимита).
  final int limit;

  /// Колонка «Готово»: карточки в ней считаются выполненными.
  final bool done;

  BoardColumn copyWith({String? name, int? limit, bool? done}) => BoardColumn(
        id: id,
        name: name ?? this.name,
        limit: limit ?? this.limit,
        done: done ?? this.done,
      );

  Map<String, dynamic> toMap() =>
      {'id': id, 'n': name, 'lim': limit, 'dn': done};

  static BoardColumn? fromMap(dynamic m) {
    if (m is! Map) return null;
    final id = '${m['id'] ?? ''}';
    if (id.isEmpty) return null;
    final lim = m['lim'];
    return BoardColumn(
      id: id,
      name: '${m['n'] ?? ''}',
      limit: lim is num && lim > 0 ? lim.toInt() : 0,
      done: m['dn'] == true,
    );
  }
}

class BoardLabel {
  const BoardLabel({required this.id, required this.name, required this.color});
  final String id;
  final String name;
  final int color; // индекс в boardColors

  Map<String, dynamic> toMap() => {'id': id, 'n': name, 'c': color};

  static BoardLabel? fromMap(dynamic m) {
    if (m is! Map) return null;
    final id = '${m['id'] ?? ''}';
    if (id.isEmpty) return null;
    final c = m['c'];
    return BoardLabel(
      id: id,
      name: '${m['n'] ?? ''}',
      color: c is num ? c.toInt().clamp(0, boardColors.length - 1) : 0,
    );
  }
}

// -------------------------------------------------------------- доска

class Board {
  const Board({
    required this.id,
    required this.name,
    required this.owner,
    required this.members,
    required this.roles,
    required this.columns,
    this.labels = const [],
    this.color = 0,
    this.icon = 'science',
    this.archived = false,
    this.template = '',
    this.updated,
  });

  final String id;
  final String name;
  final String owner;
  final List<String> members;
  final Map<String, BoardRole> roles;
  final List<BoardColumn> columns;
  final List<BoardLabel> labels;
  final int color;
  final String icon;
  final bool archived;
  final String template;
  final DateTime? updated;

  bool get isShared => members.length > 1;

  BoardRole? roleOf(String uid) => uid == owner ? BoardRole.owner : roles[uid];

  bool canEdit(String uid) {
    final r = roleOf(uid);
    return r == BoardRole.owner || r == BoardRole.editor;
  }

  bool isOwner(String uid) => uid == owner;

  BoardColumn? column(String id) {
    for (final c in columns) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Колонка «Готово» (если отмечена).
  bool isDoneColumn(String colId) => column(colId)?.done ?? false;

  BoardLabel? label(String id) {
    for (final l in labels) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Следующая колонка после [colId] (для свайпа вправо).
  BoardColumn? nextColumn(String colId) {
    final i = columns.indexWhere((c) => c.id == colId);
    if (i < 0 || i + 1 >= columns.length) return null;
    return columns[i + 1];
  }

  factory Board.fromMap(String id, Map<String, dynamic> m) {
    final rl = m['rl'];
    return Board(
      id: id,
      name: '${m['n'] ?? ''}',
      owner: '${m['ow'] ?? ''}',
      members: [for (final x in (m['mb'] as List? ?? const [])) '$x'],
      roles: {
        if (rl is Map)
          for (final e in rl.entries)
            if (roleFrom(e.value) != null) '${e.key}': roleFrom(e.value)!,
      },
      columns: [
        for (final c in (m['cols'] as List? ?? const []))
          if (BoardColumn.fromMap(c) != null) BoardColumn.fromMap(c)!,
      ],
      labels: [
        for (final l in (m['lbs'] as List? ?? const []))
          if (BoardLabel.fromMap(l) != null) BoardLabel.fromMap(l)!,
      ],
      color: (m['c'] is num ? (m['c'] as num).toInt() : 0)
          .clamp(0, boardColors.length - 1),
      icon: boardIcons.contains(m['ic']) ? '${m['ic']}' : 'science',
      archived: m['ar'] == true,
      template: '${m['tpl'] ?? ''}',
      updated: readTime(m['up']),
    );
  }
}

// ----------------------------------------------------------- карточка

class ChecklistItem {
  const ChecklistItem(this.text, {this.done = false});
  final String text;
  final bool done;

  Map<String, dynamic> toMap() => {'t': text, 'x': done};
  static ChecklistItem? fromMap(dynamic m) =>
      m is Map ? ChecklistItem('${m['t'] ?? ''}', done: m['x'] == true) : null;
}

class LinkedPaper {
  const LinkedPaper({required this.id, required this.title, this.doi});
  final String id;
  final String title;
  final String? doi;

  Map<String, dynamic> toMap() =>
      {'id': id, 't': title, if (doi != null) 'doi': doi};
  static LinkedPaper? fromMap(dynamic m) {
    if (m is! Map || m['id'] == null) return null;
    final doi = m['doi'];
    return LinkedPaper(
      id: '${m['id']}',
      title: '${m['t'] ?? ''}',
      doi: doi is String && doi.isNotEmpty ? doi : null,
    );
  }
}

class LinkedGrant {
  const LinkedGrant({
    required this.source,
    required this.id,
    required this.number,
    required this.title,
    required this.url,
    this.deadline,
  });
  final String source; // eu / grantsGov
  final String id;
  final String number;
  final String title;
  final String url;
  final DateTime? deadline;

  Map<String, dynamic> toMap() => {
        'src': source,
        'id': id,
        'no': number,
        't': title,
        'url': url,
        if (deadline != null) 'dl': deadline!.millisecondsSinceEpoch,
      };

  static LinkedGrant? fromMap(dynamic m) {
    if (m is! Map || m['id'] == null) return null;
    final dl = m['dl'];
    final url = '${m['url'] ?? ''}';
    // Открываем только http(s)-ссылки.
    final u = Uri.tryParse(url);
    return LinkedGrant(
      source: '${m['src'] ?? ''}',
      id: '${m['id']}',
      number: '${m['no'] ?? ''}',
      title: '${m['t'] ?? ''}',
      url: u != null && (u.scheme == 'https' || u.scheme == 'http') ? url : '',
      deadline: dl is int ? DateTime.fromMillisecondsSinceEpoch(dl) : null,
    );
  }
}

/// Приоритет: 0 — низкий, 1 — средний, 2 — высокий, 3 — срочный.
const priorityCount = 4;

class TaskCard {
  const TaskCard({
    required this.id,
    required this.boardId,
    required this.title,
    required this.column,
    required this.order,
    this.description = '',
    this.due,
    this.priority = 1,
    this.labels = const [],
    this.assignees = const [],
    this.checklist = const [],
    this.papers = const [],
    this.grants = const [],
    this.createdBy = '',
    this.created,
    this.updated,
    this.doneAt,
  });

  final String id;
  final String boardId;
  final String title;
  final String column;
  final double order;
  final String description;
  final DateTime? due;
  final int priority;
  final List<String> labels;
  final List<String> assignees;
  final List<ChecklistItem> checklist;
  final List<LinkedPaper> papers;
  final List<LinkedGrant> grants;
  final String createdBy;
  final DateTime? created;
  final DateTime? updated;

  /// Когда карточка попала в колонку «Готово» (для отчётов).
  final DateTime? doneAt;

  int get checkDone => checklist.where((c) => c.done).length;

  factory TaskCard.fromMap(String id, String boardId, Map<String, dynamic> m) {
    final o = m['o'];
    final p = m['p'];
    return TaskCard(
      id: id,
      boardId: boardId,
      title: '${m['t'] ?? ''}',
      column: '${m['col'] ?? ''}',
      order: o is num ? o.toDouble() : 0,
      description: '${m['d'] ?? ''}',
      due: readTime(m['due']),
      priority: p is num ? p.toInt().clamp(0, priorityCount - 1) : 1,
      labels: [for (final x in (m['lb'] as List? ?? const [])) '$x'],
      assignees: [for (final x in (m['as'] as List? ?? const [])) '$x'],
      checklist: [
        for (final x in (m['ck'] as List? ?? const []))
          if (ChecklistItem.fromMap(x) != null) ChecklistItem.fromMap(x)!,
      ],
      papers: [
        for (final x in (m['pp'] as List? ?? const []))
          if (LinkedPaper.fromMap(x) != null) LinkedPaper.fromMap(x)!,
      ],
      grants: [
        for (final x in (m['gr'] as List? ?? const []))
          if (LinkedGrant.fromMap(x) != null) LinkedGrant.fromMap(x)!,
      ],
      createdBy: '${m['by'] ?? ''}',
      created: readTime(m['cr']),
      updated: readTime(m['up']),
      doneAt: readTime(m['dn']),
    );
  }
}

class CardComment {
  const CardComment({
    required this.id,
    required this.by,
    required this.text,
    this.at,
  });
  final String id;
  final String by;
  final String text;
  final DateTime? at;

  factory CardComment.fromMap(String id, Map<String, dynamic> m) => CardComment(
        id: id,
        by: '${m['by'] ?? ''}',
        text: '${m['t'] ?? ''}',
        at: readTime(m['at']),
      );
}

/// Запись истории доски.
class BoardActivity {
  const BoardActivity({
    required this.id,
    required this.by,
    required this.kind,
    this.card = '',
    this.cardTitle = '',
    this.from = '',
    this.to = '',
    this.at,
  });
  final String id;
  final String by;

  /// create, move, edit, delete, comment, done.
  final String kind;
  final String card;
  final String cardTitle;
  final String from;
  final String to;
  final DateTime? at;

  factory BoardActivity.fromMap(String id, Map<String, dynamic> m) =>
      BoardActivity(
        id: id,
        by: '${m['by'] ?? ''}',
        kind: '${m['k'] ?? ''}',
        card: '${m['card'] ?? ''}',
        cardTitle: '${m['ct'] ?? ''}',
        from: '${m['from'] ?? ''}',
        to: '${m['to'] ?? ''}',
        at: readTime(m['at']),
      );
}

// ------------------------------------------------------ порядок карточек

const orderStep = 1024.0;

/// Карточки колонки по порядку.
List<TaskCard> cardsIn(List<TaskCard> all, String colId) =>
    all.where((c) => c.column == colId).toList()
      ..sort((a, b) {
        final o = a.order.compareTo(b.order);
        return o != 0 ? o : a.id.compareTo(b.id);
      });

/// Порядок для вставки между [before] и [after] (любой может быть null).
/// Возвращает null, если места между соседями не осталось — тогда колонку
/// нужно перенумеровать ([renumber]).
double? orderBetween(double? before, double? after) {
  if (before == null && after == null) return orderStep;
  if (before == null) return after! - orderStep;
  if (after == null) return before + orderStep;
  if (after - before < 1e-6) return null;
  return (before + after) / 2;
}

/// Новый порядок для карточки [card], перенесённой в колонку [colId]
/// на позицию [index] (среди остальных карточек этой колонки).
/// Возвращает null, если нужна перенумерация.
double? orderForMove(
    List<TaskCard> all, TaskCard card, String colId, int index) {
  final others = cardsIn(all, colId).where((c) => c.id != card.id).toList();
  final i = index.clamp(0, others.length);
  final before = i > 0 ? others[i - 1].order : null;
  final after = i < others.length ? others[i].order : null;
  return orderBetween(before, after);
}

/// Равномерные порядки для списка карточек (перенумерация колонки).
Map<String, double> renumber(List<TaskCard> ordered) => {
      for (var i = 0; i < ordered.length; i++)
        ordered[i].id: (i + 1) * orderStep,
    };

/// Перенумерация колонки со вставкой [card] на позицию [index].
Map<String, double> renumberWithInsert(
    List<TaskCard> all, TaskCard card, String colId, int index) {
  final others = cardsIn(all, colId).where((c) => c.id != card.id).toList();
  others.insert(index.clamp(0, others.length), card);
  return renumber(others);
}

// ---------------------------------------------------------------- сроки

enum DueState { none, overdue, today, week, later, done }

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

DueState dueState(DateTime? due, DateTime now, {bool done = false}) {
  if (done) return DueState.done;
  if (due == null) return DueState.none;
  final days = _day(due.toLocal()).difference(_day(now.toLocal())).inDays;
  if (days < 0) return DueState.overdue;
  if (days == 0) return DueState.today;
  if (days <= 7) return DueState.week;
  return DueState.later;
}

// ------------------------------------------------------------- фильтры

enum DueFilter { any, overdue, week, none }

class CardFilter {
  const CardFilter({
    this.query = '',
    this.assignee,
    this.label,
    this.priority,
    this.due = DueFilter.any,
  });

  final String query;

  /// uid исполнителя, '' — без исполнителя, null — любой.
  final String? assignee;
  final String? label;
  final int? priority;
  final DueFilter due;

  bool get isEmpty =>
      query.trim().isEmpty &&
      assignee == null &&
      label == null &&
      priority == null &&
      due == DueFilter.any;

  CardFilter copyWith({
    String? query,
    String? Function()? assignee,
    String? Function()? label,
    int? Function()? priority,
    DueFilter? due,
  }) =>
      CardFilter(
        query: query ?? this.query,
        assignee: assignee != null ? assignee() : this.assignee,
        label: label != null ? label() : this.label,
        priority: priority != null ? priority() : this.priority,
        due: due ?? this.due,
      );

  bool matches(TaskCard c, DateTime now, {required bool done}) {
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty &&
        !'${c.title} ${c.description}'.toLowerCase().contains(q)) {
      return false;
    }
    final a = assignee;
    if (a != null) {
      if (a.isEmpty ? c.assignees.isNotEmpty : !c.assignees.contains(a)) {
        return false;
      }
    }
    if (label != null && !c.labels.contains(label)) return false;
    if (priority != null && c.priority != priority) return false;
    final s = dueState(c.due, now, done: done);
    switch (due) {
      case DueFilter.any:
        break;
      case DueFilter.overdue:
        if (s != DueState.overdue) return false;
      case DueFilter.week:
        if (!(s == DueState.overdue ||
            s == DueState.today ||
            s == DueState.week)) {
          return false;
        }
      case DueFilter.none:
        if (c.due != null) return false;
    }
    return true;
  }
}

// ------------------------------------------------------------ статистика

class BoardStats {
  const BoardStats({
    required this.total,
    required this.done,
    required this.overdue,
    required this.perColumn,
    required this.openPerMember,
  });
  final int total;
  final int done;
  final int overdue;
  final Map<String, int> perColumn;

  /// Незавершённые задачи по исполнителям ('' — без исполнителя).
  final Map<String, int> openPerMember;

  int get open => total - done;
  int get percent => total == 0 ? 0 : (done * 100 / total).round();

  factory BoardStats.of(Board b, List<TaskCard> cards, DateTime now) {
    var done = 0, overdue = 0;
    final perCol = {for (final c in b.columns) c.id: 0};
    final perMember = <String, int>{};
    for (final c in cards) {
      final isDone = b.isDoneColumn(c.column);
      perCol[c.column] = (perCol[c.column] ?? 0) + 1;
      if (isDone) {
        done++;
        continue;
      }
      if (dueState(c.due, now) == DueState.overdue) overdue++;
      if (c.assignees.isEmpty) {
        perMember[''] = (perMember[''] ?? 0) + 1;
      } else {
        for (final a in c.assignees) {
          perMember[a] = (perMember[a] ?? 0) + 1;
        }
      }
    }
    return BoardStats(
      total: cards.length,
      done: done,
      overdue: overdue,
      perColumn: perCol,
      openPerMember: perMember,
    );
  }
}

// ---------------------------------------------------------- мои задачи

enum TaskGroup { overdue, today, week, later, noDate }

/// Моя задача: карточка с её доской.
class MyTask {
  const MyTask(this.board, this.card);
  final Board board;
  final TaskCard card;
}

/// Группирует незавершённые задачи по срокам; внутри — по сроку и приоритету.
Map<TaskGroup, List<MyTask>> groupMyTasks(List<MyTask> tasks, DateTime now) {
  final out = {for (final g in TaskGroup.values) g: <MyTask>[]};
  for (final t in tasks) {
    if (t.board.isDoneColumn(t.card.column) || t.board.archived) continue;
    final g = switch (dueState(t.card.due, now)) {
      DueState.overdue => TaskGroup.overdue,
      DueState.today => TaskGroup.today,
      DueState.week => TaskGroup.week,
      DueState.later => TaskGroup.later,
      _ => TaskGroup.noDate,
    };
    out[g]!.add(t);
  }
  for (final l in out.values) {
    l.sort((a, b) {
      final da = a.card.due, db = b.card.due;
      if (da != null && db != null && da != db) return da.compareTo(db);
      return b.card.priority.compareTo(a.card.priority);
    });
  }
  return out;
}

/// Задача относится ко мне: я исполнитель, или это моя личная доска.
bool isMyTask(Board b, TaskCard c, String me) =>
    c.assignees.contains(me) || (!b.isShared && b.members.contains(me));

// --------------------------------------------------------------- шаблоны

/// Шаблон доски: ключи строк колонок (последняя — «Готово») и стартовых карточек.
class BoardTemplate {
  const BoardTemplate({
    required this.key,
    required this.icon,
    required this.color,
    required this.columns,
    this.cards = const [],
  });
  final String key;
  final String icon;
  final int color;

  /// Ключи названий колонок `bt.col.*`.
  final List<String> columns;

  /// (ключ названия карточки `bt.card.*`, индекс колонки).
  final List<(String, int)> cards;
}

const boardTemplates = [
  BoardTemplate(
    key: 'paper',
    icon: 'article',
    color: 1,
    columns: ['ideas', 'lit', 'experiment', 'draft', 'review', 'published'],
    cards: [
      ('paper_topic', 0),
      ('paper_lit', 1),
      ('paper_journal', 0),
    ],
  ),
  BoardTemplate(
    key: 'grant',
    icon: 'payments',
    color: 3,
    columns: ['prepare', 'documents', 'budget', 'check', 'submitted'],
    cards: [
      ('grant_eligibility', 0),
      ('grant_team', 0),
      ('grant_letters', 1),
      ('grant_narrative', 1),
      ('grant_budget', 2),
      ('grant_final', 3),
    ],
  ),
  BoardTemplate(
    key: 'thesis',
    icon: 'school',
    color: 9,
    columns: ['lit', 'method', 'results', 'abstract', 'defense'],
    cards: [
      ('thesis_plan', 0),
      ('thesis_review', 0),
      ('thesis_method', 1),
    ],
  ),
  BoardTemplate(
    key: 'lab',
    icon: 'groups',
    color: 0,
    columns: ['ideas', 'work', 'check', 'done'],
  ),
  BoardTemplate(
    key: 'empty',
    icon: 'lightbulb',
    color: 10,
    columns: ['todo', 'work', 'done'],
  ),
];

BoardTemplate templateOf(String key) => boardTemplates
    .firstWhere((t) => t.key == key, orElse: () => boardTemplates.last);
