import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/board.dart';
import '../models/note.dart';
import '../models/paper.dart';
import '../services/board_service.dart';
import '../services/library_service.dart';
import '../services/motivation_service.dart';
import '../services/note_service.dart';
import '../services/pdf_store.dart';
import '../services/reading_progress.dart';
import '../strings.dart';
import '../utils.dart';
import '../widgets/board_widgets.dart';
import '../widgets/celebration.dart';
import '../widgets/focus_timer.dart';
import '../widgets/math_markdown.dart';
import '../widgets/grant_card.dart' show dateLabel;
import 'chat_screen.dart';
import 'notes_screen.dart';
import 'paper_actions.dart';

/// Окно задачи (нижняя панель почти на весь экран).
Future<void> showCardSheet(BuildContext context, String boardId, String cardId,
    {BoardService? service}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.94,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (ctx, sc) => CardSheet(
        boardId: boardId,
        cardId: cardId,
        service: service ?? BoardService.instance,
        scroll: sc,
      ),
    ),
  );
}

class CardSheet extends StatefulWidget {
  const CardSheet({
    super.key,
    required this.boardId,
    required this.cardId,
    required this.service,
    this.scroll,
  });
  final String boardId;
  final String cardId;
  final BoardService service;
  final ScrollController? scroll;

  @override
  State<CardSheet> createState() => _CardSheetState();
}

class _CardSheetState extends State<CardSheet> {
  BoardService get _svc => widget.service;
  late final Stream<Board?> _board = _svc.board(widget.boardId);
  late final Stream<List<TaskCard>> _cards = _svc.cards(widget.boardId);
  late final Stream<List<CardComment>> _comments =
      _svc.comments(widget.boardId, widget.cardId);
  late final Stream<List<BoardActivity>> _activity =
      _svc.activity(widget.boardId);
  late final Stream<List<Note>>? _notes =
      NoteService.instance.available ? NoteService.instance.notes() : null;
  final TextEditingController _comment = TextEditingController();
  final TextEditingController _newItem = TextEditingController();

  @override
  void initState() {
    super.initState();
    ReadingProgress.instance.ensureLoaded();
    LibraryService.instance.ensureLoaded();
    PdfStore.instance.ensureLoaded();
  }

  @override
  void dispose() {
    _comment.dispose();
    _newItem.dispose();
    super.dispose();
  }

  void _update(Map<String, Object?> data) => fireAndReport(
      context, _svc.updateCard(widget.boardId, widget.cardId, data));

  // ------------------------------------------------------------- поля

  Future<void> _editTitle(TaskCard c) async {
    final v = await askText(context,
        title: t('bd.c.title'), initial: c.title, maxLength: maxCardTitle);
    if (v != null && v != c.title && mounted) _update({'t': v});
  }

  Future<void> _editDesc(TaskCard c) async {
    final v = await showDialog<String>(
      context: context,
      builder: (_) => _LongTextDialog(initial: c.description),
    );
    if (v != null && v != c.description && mounted) _update({'d': v});
  }

  Future<void> _pickDue(TaskCard c) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: c.due ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 10),
    );
    if (d == null || !mounted) return;
    fireAndReport(context, _svc.setDue(widget.boardId, widget.cardId, d));
  }

  void _toggleIn(String field, List<String> list, String v) {
    final next = list.contains(v)
        ? [
            for (final x in list)
              if (x != v) x
          ]
        : [...list, v];
    _update({field: next});
  }

  void _setChecklist(List<ChecklistItem> items) => fireAndReport(
      context, _svc.setChecklist(widget.boardId, widget.cardId, items));

  /// Отмечает пункт; если закрыт весь чек-лист — праздник.
  void _tick(TaskCard c, int index, bool done) {
    final items = [
      for (var j = 0; j < c.checklist.length; j++)
        j == index
            ? ChecklistItem(c.checklist[j].text, done: done)
            : c.checklist[j],
    ];
    _setChecklist(items);
    if (!done) return;
    MotivationService.instance.active();
    final wasAll = c.checklist.every((i) => i.done);
    if (!wasAll && items.every((i) => i.done)) {
      celebrate(context, t('mo.checklist'));
    }
  }

  void _addItem(TaskCard c) {
    final v = _newItem.text.trim();
    if (v.isEmpty || c.checklist.length >= maxChecklist) return;
    _setChecklist([
      ...c.checklist,
      ChecklistItem(
          v.length > maxChecklistText ? v.substring(0, maxChecklistText) : v),
    ]);
    _newItem.clear();
    HapticFeedback.selectionClick();
  }

  Future<void> _attachPaper(TaskCard c) async {
    final lib = LibraryService.instance.items;
    if (lib.isEmpty) {
      toast(context, t('bd.c.no_library'));
      return;
    }
    final picked = await showModalBottomSheet<Paper>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding:
            EdgeInsets.only(bottom: 16 + MediaQuery.of(ctx).viewPadding.bottom),
        children: [
          for (final p in lib)
            if (!c.papers.any((x) => x.id == p.id))
              ListTile(
                minTileHeight: 56,
                leading: Icon(PdfStore.instance.has(PdfStore.idOf(p))
                    ? Icons.picture_as_pdf
                    : Icons.article_outlined),
                title:
                    Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(p.authorsLine,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(ctx, p),
              ),
        ],
      ),
    );
    if (picked == null || !mounted || c.papers.length >= maxPapers) return;
    fireAndReport(
        context,
        _svc.setPapers(widget.boardId, widget.cardId, [
          ...c.papers,
          LinkedPaper(id: picked.id, title: picked.title, doi: picked.doiShort),
        ]));
  }

  void _openPaper(LinkedPaper lp) {
    Paper? p;
    for (final x in LibraryService.instance.items) {
      if (x.id == lp.id) p = x;
    }
    if (p != null) {
      openPaper(context, p);
    } else if (lp.doi != null) {
      openLink(context, 'https://doi.org/${lp.doi}');
    }
  }

  Future<void> _tickForPaper(TaskCard c) async {
    final open = [
      for (var i = 0; i < c.checklist.length; i++)
        if (!c.checklist[i].done) i,
    ];
    if (open.isEmpty) return;
    final idx = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final i in open)
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.check_box_outline_blank),
                title: Text(c.checklist[i].text),
                onTap: () => Navigator.pop(ctx, i),
              ),
          ],
        ),
      ),
    );
    if (idx == null || !mounted) return;
    _tick(c, idx, true);
  }

  Future<void> _moveTo(Board b, List<TaskCard> all, TaskCard c) async {
    final col = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final col in b.columns)
              ListTile(
                minTileHeight: 56,
                leading: Icon(col.id == c.column
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                title: Text(col.name),
                trailing: col.done
                    ? const Icon(Icons.check_circle, color: Color(0xFF16A34A))
                    : null,
                onTap: () => Navigator.pop(ctx, col.id),
              ),
          ],
        ),
      ),
    );
    if (col == null || col == c.column || !mounted) return;
    fireAndReport(
        context, _svc.moveCard(b, all, c, col, cardsIn(all, col).length));
    HapticFeedback.lightImpact();
    if (b.isDoneColumn(col) && !b.isDoneColumn(c.column)) {
      celebrateDone(context, b.id, c.id);
    } else {
      MotivationService.instance.active();
    }
  }

  Future<void> _delete(Board b, TaskCard c) async {
    final ok = await confirmDanger(context,
        title: t('bd.c.delete'), text: t('bd.c.delete_q'));
    if (!ok || !mounted) return;
    final nav = Navigator.of(context);
    fireAndReport(context, _svc.deleteCard(b, c));
    nav.pop();
  }

  void _sendComment(Board b, TaskCard c) {
    final v = _comment.text.trim();
    if (v.isEmpty) return;
    fireAndReport(context, _svc.addComment(b, c, v));
    _comment.clear();
    FocusScope.of(context).unfocus();
  }

  // ------------------------------------------------------------- вид

  Widget _section(String title, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800)),
            ),
            if (trailing != null) trailing,
          ],
        ),
      );

  String _historyText(BoardActivity a, String who) => switch (a.kind) {
        'create' => t('bd.h.create', {'who': who}),
        'move' => t('bd.h.move', {'who': who, 'from': a.from, 'to': a.to}),
        'done' => t('bd.h.done', {'who': who, 'to': a.to}),
        'delete' => t('bd.h.delete', {'who': who}),
        'comment' => t('bd.h.comment', {'who': who}),
        _ => who,
      };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Board?>(
      stream: _board,
      builder: (ctx, bs) => StreamBuilder<List<TaskCard>>(
        stream: _cards,
        builder: (ctx, cs) {
          final b = bs.data;
          final all = cs.data;
          if (b == null || all == null) {
            return const Center(child: CircularProgressIndicator());
          }
          TaskCard? c;
          for (final x in all) {
            if (x.id == widget.cardId) c = x;
          }
          if (c == null) {
            return Center(child: Text(t('bd.deleted')));
          }
          return _content(b, all, c);
        },
      ),
    );
  }

  Widget _content(Board b, List<TaskCard> all, TaskCard c) {
    final scheme = Theme.of(context).colorScheme;
    final me = _svc.me;
    final edit = b.canEdit(me);
    final done = b.isDoneColumn(c.column);
    final bottom = MediaQuery.of(context).viewPadding.bottom +
        MediaQuery.of(context).viewInsets.bottom;
    final col = b.column(c.column);
    final muted = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);
    final others = [
      for (final a in c.assignees)
        if (a != me) a
    ];

    return ListView(
      controller: widget.scroll,
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottom),
      children: [
        // Колонка и кнопка «переместить».
        Row(
          children: [
            Icon(boardIcon(b.icon), size: 18, color: boardColor(b.color)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(b.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: edit ? () => _editTitle(c) : null,
          borderRadius: BorderRadius.circular(8),
          child: Text(c.title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                decoration: done ? TextDecoration.lineThrough : null,
              )),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: Icon(
                  done ? Icons.check_circle : Icons.view_column_outlined,
                  size: 18,
                  color: done ? const Color(0xFF16A34A) : null),
              label: Text(col?.name ?? '—'),
              onPressed: edit ? () => _moveTo(b, all, c) : null,
            ),
            if (c.due != null) DueChip(due: c.due!, done: done),
          ],
        ),

        // Приоритет.
        _section(t('bd.c.priority')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var p = 0; p < priorityCount; p++)
              ChoiceChip(
                avatar:
                    CircleAvatar(radius: 6, backgroundColor: priorityColor(p)),
                label: Text(priorityLabel(p)),
                selected: c.priority == p,
                showCheckmark: false,
                onSelected: edit ? (_) => _update({'p': p}) : null,
              ),
          ],
        ),

        // Срок.
        _section(t('bd.c.due')),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: edit ? () => _pickDue(c) : null,
                icon: const Icon(Icons.event),
                label: Text(c.due == null
                    ? t('bd.c.set_due')
                    : '${dateLabel(c.due!)} · ${dueLabel(c.due!, DateTime.now())}'),
              ),
            ),
            if (c.due != null && edit)
              IconButton(
                tooltip: t('bd.c.clear_due'),
                icon: const Icon(Icons.close),
                onPressed: () =>
                    fireAndReport(context, _svc.setDue(b.id, c.id, null)),
              ),
          ],
        ),

        // Время фокуса.
        _section(t('fo.section')),
        Text(
          c.focusTotal == 0
              ? t('fo.none')
              : t('fo.total', {
                  't': focusLabel(c.focusTotal),
                  'm': focusLabel(c.focus[me] ?? 0),
                }),
          style: muted,
        ),
        if (edit && !done)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              onPressed: () => showFocusTimer(context,
                  service: _svc, boardId: b.id, card: c),
              icon: const Icon(Icons.play_arrow),
              label: Text(t('fo.start')),
            ),
          ),

        // Описание.
        _section(t('bd.c.desc'),
            trailing: edit
                ? IconButton(
                    tooltip: t('bd.c.desc'),
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editDesc(c))
                : null),
        InkWell(
          onTap: edit ? () => _editDesc(c) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: c.description.isEmpty
                ? Text(t('bd.c.desc_hint'), style: muted)
                : MathMarkdown(c.description),
          ),
        ),

        // Мои заметки к задаче (с формулами).
        if (_notes != null) ...[
          _section(t('nt.title'),
              trailing: IconButton(
                tooltip: t('nt.new'),
                icon: const Icon(Icons.note_add_outlined),
                onPressed: () => openNewNote(context,
                    card:
                        NoteCard(boardId: b.id, cardId: c.id, title: c.title)),
              )),
          StreamBuilder<List<Note>>(
            stream: _notes,
            builder: (_, s) {
              final mine = [
                for (final n in s.data ?? const <Note>[])
                  if (n.card?.cardId == c.id) n
              ];
              if (mine.isEmpty) return Text(t('nt.card_none'), style: muted);
              return Column(
                children: [
                  for (final n in mine)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: NoteTile(
                          note: n, onTap: () => openNote(context, n.id)),
                    ),
                ],
              );
            },
          ),
        ],

        // Исполнители.
        _section(t('bd.c.assignees')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in b.members)
              FilterChip(
                showCheckmark: false,
                avatar: MemberAvatar(m, radius: 12),
                label: m == me ? Text(t('bd.f.me')) : MemberName(m),
                selected: c.assignees.contains(m),
                onSelected:
                    edit ? (_) => _toggleIn('as', c.assignees, m) : null,
              ),
          ],
        ),
        if (others.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () async {
                final p = await MemberNames.lookup(others.first);
                if (!mounted) return;
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ChatScreen(
                      otherUid: others.first,
                      otherName: p?.name ?? t('bd.unknown_user')),
                ));
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(t('bd.c.write_to')),
            ),
          ),

        // Метки.
        if (b.labels.isNotEmpty) ...[
          _section(t('bd.c.labels')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in b.labels)
                FilterChip(
                  showCheckmark: false,
                  avatar: CircleAvatar(
                      radius: 6, backgroundColor: boardColor(l.color)),
                  label: Text(l.name),
                  selected: c.labels.contains(l.id),
                  onSelected:
                      edit ? (_) => _toggleIn('lb', c.labels, l.id) : null,
                ),
            ],
          ),
        ],

        // Чек-лист.
        _section(
          t('bd.c.checklist'),
          trailing: c.checklist.isEmpty
              ? null
              : Text(
                  t('bd.c.check_progress',
                      {'d': c.checkDone, 'n': c.checklist.length}),
                  style: muted),
        ),
        if (c.checklist.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: c.checkDone / c.checklist.length),
                duration: const Duration(milliseconds: 300),
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  color: v >= 1 ? const Color(0xFF16A34A) : null,
                ),
              ),
            ),
          ),
        for (var i = 0; i < c.checklist.length; i++)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: c.checklist[i].done,
            onChanged: edit
                ? (v) {
                    HapticFeedback.selectionClick();
                    _tick(c, i, v == true);
                  }
                : null,
            title: Text(c.checklist[i].text,
                style: TextStyle(
                  decoration:
                      c.checklist[i].done ? TextDecoration.lineThrough : null,
                )),
            secondary: edit
                ? IconButton(
                    tooltip: t('bd.delete_do'),
                    icon: const Icon(Icons.close),
                    onPressed: () => _setChecklist([
                      for (var j = 0; j < c.checklist.length; j++)
                        if (j != i) c.checklist[j],
                    ]),
                  )
                : null,
          ),
        if (edit && c.checklist.length < maxChecklist)
          TextField(
            controller: _newItem,
            maxLength: maxChecklistText,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _addItem(c),
            decoration: InputDecoration(
              hintText: t('bd.c.check_add'),
              counterText: '',
              prefixIcon: const Icon(Icons.add),
              suffixIcon: IconButton(
                tooltip: t('bd.c.check_add'),
                icon: const Icon(Icons.check),
                onPressed: () => _addItem(c),
              ),
              border: const OutlineInputBorder(),
            ),
          ),

        // Статьи.
        _section(t('bd.c.papers'),
            trailing: edit
                ? IconButton(
                    tooltip: t('bd.c.add_paper'),
                    icon: const Icon(Icons.add_link),
                    onPressed: () => _attachPaper(c))
                : null),
        if (c.papers.isEmpty)
          Text(t('bd.c.add_paper'), style: muted)
        else
          ListenableBuilder(
            listenable: ReadingProgress.instance,
            builder: (_, __) => Column(
              children: [
                for (final p in c.papers) _paperTile(c, p, edit),
              ],
            ),
          ),

        // Гранты.
        if (c.grants.isNotEmpty) ...[
          _section(t('bd.c.grants')),
          for (final g in c.grants)
            ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: 56,
              leading: const Icon(Icons.payments_outlined),
              title:
                  Text(g.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text([
                g.number,
                if (g.deadline != null) dateLabel(g.deadline!),
              ].join(' · ')),
              onTap: g.url.isEmpty ? null : () => openLink(context, g.url),
              trailing: edit
                  ? IconButton(
                      tooltip: t('bd.delete_do'),
                      icon: const Icon(Icons.link_off),
                      onPressed: () => fireAndReport(
                          context,
                          _svc.setGrants(b.id, c.id, [
                            for (final x in c.grants)
                              if (x.id != g.id) x
                          ])),
                    )
                  : null,
            ),
        ],

        // Комментарии.
        _section(t('bd.c.comments')),
        StreamBuilder<List<CardComment>>(
          stream: _comments,
          builder: (_, s) {
            final list = s.data ?? const <CardComment>[];
            if (list.isEmpty) return Text(t('bd.c.no_comments'), style: muted);
            return Column(
              children: [
                for (final cm in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MemberAvatar(cm.by, radius: 14),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: MemberName(cm.by,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  if (cm.at != null) ...[
                                    const SizedBox(width: 6),
                                    Text(dateLabel(cm.at!), style: muted),
                                  ],
                                ],
                              ),
                              SelectableText(cm.text),
                            ],
                          ),
                        ),
                        if (cm.by == me || b.isOwner(me))
                          IconButton(
                            tooltip: t('bd.delete_do'),
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => fireAndReport(
                                context, _svc.deleteComment(b.id, c.id, cm.id)),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        if (edit)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextField(
              controller: _comment,
              minLines: 1,
              maxLines: 4,
              maxLength: maxComment,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: t('bd.c.comment_hint'),
                counterText: '',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: t('chat.send'),
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendComment(b, c),
                ),
              ),
            ),
          ),

        // История.
        _section(t('bd.c.history')),
        StreamBuilder<List<BoardActivity>>(
          stream: _activity,
          builder: (_, s) {
            final list = [
              for (final a in s.data ?? const <BoardActivity>[])
                if (a.card == c.id) a,
            ];
            if (list.isEmpty) return Text(t('bd.c.no_history'), style: muted);
            return Column(
              children: [
                for (final a in list.take(30))
                  FutureBuilder(
                    future: MemberNames.lookup(a.by),
                    builder: (_, ps) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.history, size: 20),
                      title: Text(_historyText(
                          a,
                          ps.data?.name.isNotEmpty == true
                              ? ps.data!.name
                              : t('bd.h.someone'))),
                      subtitle: a.at == null ? null : Text(dateLabel(a.at!)),
                    ),
                  ),
              ],
            );
          },
        ),

        if (edit) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: scheme.error,
            ),
            onPressed: () => _delete(b, c),
            icon: const Icon(Icons.delete_outline),
            label: Text(t('bd.c.delete')),
          ),
        ],
      ],
    );
  }

  Widget _paperTile(TaskCard c, LinkedPaper p, bool edit) {
    final pos = ReadingProgress.instance
        .of(PdfStore.idOf(Paper(id: p.id, title: p.title)));
    final finished = pos != null && pos.pages > 0 && pos.page >= pos.pages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          minTileHeight: 56,
          leading: Icon(finished ? Icons.task_alt : Icons.article_outlined,
              color: finished ? const Color(0xFF16A34A) : null),
          title: Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: pos == null
              ? null
              : Text(t('bd.c.reading', {'p': pos.page, 'n': pos.pages})),
          onTap: () => _openPaper(p),
          trailing: edit
              ? IconButton(
                  tooltip: t('bd.delete_do'),
                  icon: const Icon(Icons.link_off),
                  onPressed: () => fireAndReport(
                      context,
                      _svc.setPapers(widget.boardId, widget.cardId, [
                        for (final x in c.papers)
                          if (x.id != p.id) x
                      ])),
                )
              : null,
        ),
        if (finished && edit && c.checklist.any((i) => !i.done))
          TextButton.icon(
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => _tickForPaper(c),
            icon: const Icon(Icons.check),
            label: Text(t('bd.c.read_done')),
          ),
      ],
    );
  }
}

class _LongTextDialog extends StatefulWidget {
  const _LongTextDialog({required this.initial});
  final String initial;

  @override
  State<_LongTextDialog> createState() => _LongTextDialogState();
}

class _LongTextDialogState extends State<_LongTextDialog> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(t('bd.c.desc')),
        content: TextField(
          controller: _c,
          autofocus: true,
          minLines: 4,
          maxLines: 10,
          maxLength: maxCardDesc,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: t('bd.c.desc_hint'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t('bd.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
            onPressed: () => Navigator.pop(context, _c.text.trim()),
            child: Text(t('bd.c.save')),
          ),
        ],
      );
}
