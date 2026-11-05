/// Заметки с формулами (Firestore `notes/{id}`) и помощники редактора.
library;

import 'chat.dart' show readTime;

const maxNoteTitle = 200;
const maxNoteBody = 20000;

/// Статья, к которой привязана заметка (поле `p`).
class NotePaper {
  const NotePaper({required this.id, required this.title, this.doi, this.page});
  final String id;
  final String title;
  final String? doi;

  /// Страница PDF (с 1) или null.
  final int? page;

  Map<String, dynamic> toMap() => {
        'id': id,
        't': title.length > 300 ? title.substring(0, 300) : title,
        if (doi != null) 'doi': doi,
        if (page != null) 'pg': page,
      };

  static NotePaper? fromMap(dynamic m) {
    if (m is! Map || m['id'] is! String) return null;
    final pg = m['pg'];
    final doi = m['doi'];
    return NotePaper(
      id: m['id'] as String,
      title: '${m['t'] ?? ''}',
      doi: doi is String && doi.isNotEmpty ? doi : null,
      page: pg is num && pg > 0 ? pg.toInt() : null,
    );
  }
}

/// Задача на доске, к которой привязана заметка (поле `c`).
class NoteCard {
  const NoteCard(
      {required this.boardId, required this.cardId, required this.title});
  final String boardId;
  final String cardId;
  final String title;

  Map<String, dynamic> toMap() => {
        'b': boardId,
        'c': cardId,
        't': title.length > 200 ? title.substring(0, 200) : title,
      };

  static NoteCard? fromMap(dynamic m) {
    if (m is! Map || m['b'] is! String || m['c'] is! String) return null;
    return NoteCard(
      boardId: m['b'] as String,
      cardId: m['c'] as String,
      title: '${m['t'] ?? ''}',
    );
  }
}

class Note {
  const Note({
    required this.id,
    required this.owner,
    this.title = '',
    this.body = '',
    this.paper,
    this.card,
    this.created,
    this.updated,
  });

  final String id;
  final String owner;
  final String title;

  /// Текст в Markdown с формулами LaTeX.
  final String body;
  final NotePaper? paper;
  final NoteCard? card;
  final DateTime? created;
  final DateTime? updated;

  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty;

  /// Заголовок для списка: заданный или первая строка текста.
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    for (final l in body.split('\n')) {
      final s = l.replaceAll(RegExp(r'^[#>\-*\s]+'), '').trim();
      if (s.isNotEmpty) return s.length > 80 ? '${s.substring(0, 80)}…' : s;
    }
    return '';
  }

  factory Note.fromMap(String id, Map<String, dynamic> m) => Note(
        id: id,
        owner: '${m['o'] ?? ''}',
        title: '${m['t'] ?? ''}',
        body: '${m['b'] ?? ''}',
        paper: NotePaper.fromMap(m['p']),
        card: NoteCard.fromMap(m['c']),
        created: readTime(m['cr']),
        updated: readTime(m['up']),
      );
}

enum NoteFilter { all, papers, tasks, free }

bool noteMatches(Note n, NoteFilter f, String query) {
  final ok = switch (f) {
    NoteFilter.all => true,
    NoteFilter.papers => n.paper != null,
    NoteFilter.tasks => n.card != null,
    NoteFilter.free => n.paper == null && n.card == null,
  };
  if (!ok) return false;
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return '${n.title}\n${n.body}\n${n.paper?.title ?? ''}\n${n.card?.title ?? ''}'
      .toLowerCase()
      .contains(q);
}

/// Новые сверху.
List<Note> sortNotes(List<Note> notes) => [...notes]..sort((a, b) {
    final ua = a.updated, ub = b.updated;
    if (ua == null && ub == null) return a.id.compareTo(b.id);
    if (ua == null) return -1; // ещё не сохранена на сервере — самая свежая
    if (ub == null) return 1;
    return ub.compareTo(ua);
  });

// ------------------------------------------------------------- формулы

/// Формула в тексте: [start, end) — вместе с ограничителями,
/// [texStart, texEnd) — только сама формула.
class FormulaSpan {
  const FormulaSpan(this.start, this.end, this.texStart, this.texEnd,
      {required this.display});
  final int start;
  final int end;
  final int texStart;
  final int texEnd;
  final bool display;

  String texOf(String text) => text.substring(texStart, texEnd).trim();
}

/// Те же правила, что и при отображении (см. `MathInlineSyntax`).
final _formulaRe = RegExp(
  r'\$\$([\s\S]+?)\$\$' // 1: $$…$$, в том числе на нескольких строках
  r'|\\\[([\s\S]+?)\\\]' // 2: \[…\]
  r'|(?<![\\$])\$(?![\s$])([^$\n]*?(?:[^\s\\$]|\\[A-Za-z]+ ))\$(?![\d$])' // 3: $…$
  r'|(?<![\\$])\$([^\s\\$])\$(?![\d$])' // 4: $x$
  r'|\\\((.+?)\\\)', // 5: \(…\)
);

/// Все формулы текста по порядку.
List<FormulaSpan> findFormulas(String text) {
  final out = <FormulaSpan>[];
  for (final m in _formulaRe.allMatches(text)) {
    for (var g = 1; g <= 5; g++) {
      final s = m[g];
      if (s == null) continue;
      final open = switch (g) { 1 || 2 => 2, 3 || 4 => 1, _ => 2 };
      final texStart = m.start + open;
      out.add(FormulaSpan(m.start, m.end, texStart, texStart + s.length,
          display: g <= 2));
      break;
    }
  }
  return out;
}

/// Формула, внутри которой стоит курсор, или null.
FormulaSpan? formulaAt(String text, int offset) {
  for (final f in findFormulas(text)) {
    if (offset >= f.texStart && offset <= f.texEnd) return f;
  }
  return null;
}

/// Курсор внутри формулы: в готовой формуле или после незакрытого `$`.
bool insideMath(String text, int offset) {
  if (formulaAt(text, offset) != null) return true;
  final before = text.substring(0, offset.clamp(0, text.length));
  final dollars = RegExp(r'(?<!\\)\$').allMatches(before).length; // без \$
  return dollars.isOdd;
}

/// Все формулы текста одним списком LaTeX (для «Скопировать формулы»).
List<String> allFormulas(String text) => [
      for (final f in findFormulas(text))
        if (f.texOf(text).isNotEmpty) f.texOf(text),
    ];

/// Результат вставки в поле ввода.
class Edit {
  const Edit(this.text, this.selStart, [int? selEnd])
      : selEnd = selEnd ?? selStart;
  final String text;
  final int selStart;
  final int selEnd;
}

/// Вставляет шаблон [snippet] в [text] вместо выделения [start]–[end].
/// `¦` в шаблоне — место курсора; выделенный текст попадает туда же.
/// Если [math] и курсор не в формуле — шаблон оборачивается в `$…$`.
Edit insertSnippet(String text, int start, int end, String snippet,
    {bool math = true}) {
  final a = start.clamp(0, text.length);
  final b = end.clamp(a, text.length);
  final selected = text.substring(a, b);
  var s = snippet.contains('¦') ? snippet : '$snippet¦';
  if (math && !insideMath(text, a)) s = '\$$s\$';
  final cursor = s.indexOf('¦');
  final filled = s.replaceFirst('¦', selected);
  final out = text.substring(0, a) + filled + text.substring(b);
  final pos = a + cursor;
  return Edit(out, pos, pos + selected.length);
}
