import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/board.dart';
import '../services/board_service.dart';
import '../strings.dart';
import '../widgets/board_widgets.dart';
import 'board_settings_screen.dart';
import 'card_sheet.dart';

/// Доска: колонки с карточками, перетаскивание, фильтры.
class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key, required this.boardId, this.service});
  final String boardId;
  final BoardService? service;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  late final BoardService _svc = widget.service ?? BoardService.instance;
  late final Stream<Board?> _board = _svc.board(widget.boardId);
  late final Stream<List<TaskCard>> _cards = _svc.cards(widget.boardId);
  final PageController _pages = PageController(viewportFraction: 0.86);
  CardFilter _filter = const CardFilter();
  Timer? _edgeTimer;
  bool _dragging = false;

  @override
  void dispose() {
    _edgeTimer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  // --------------------------------------------------------- перетаскивание

  /// При перетаскивании к краю экрана листаем колонки.
  void _onDragUpdate(DragUpdateDetails d) {
    final w = MediaQuery.of(context).size.width;
    final x = d.globalPosition.dx;
    final dir = x < 36 ? -1 : (x > w - 36 ? 1 : 0);
    if (dir == 0) {
      _edgeTimer?.cancel();
      _edgeTimer = null;
      return;
    }
    if (_edgeTimer != null) return;
    _edgeTimer = Timer(const Duration(milliseconds: 450), () {
      _edgeTimer = null;
      if (!_pages.hasClients) return;
      final page = (_pages.page ?? 0).round() + dir;
      _pages.animateToPage(page.clamp(0, 99),
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
      HapticFeedback.selectionClick();
    });
  }

  void _move(Board b, List<TaskCard> all, TaskCard c, String colId, int index) {
    if (!b.canEdit(_svc.me)) return;
    final col = b.column(colId);
    if (col == null) return;
    final count = cardsIn(all, colId).where((x) => x.id != c.id).length;
    fireAndReport(context, _svc.moveCard(b, all, c, colId, index));
    HapticFeedback.lightImpact();
    if (col.limit > 0 && count + 1 > col.limit && c.column != colId) {
      toast(context, t('bd.limit_warn', {'col': col.name, 'max': col.limit}));
    }
  }

  void _next(Board b, List<TaskCard> all, TaskCard c) {
    final n = b.nextColumn(c.column);
    if (n == null) return;
    _move(b, all, c, n.id, cardsIn(all, n.id).length);
    toast(context, t('bd.moved', {'col': n.name}));
  }

  // ------------------------------------------------------------- действия

  Future<void> _addCard(Board b, List<TaskCard> all, String colId) async {
    final title = await askText(context,
        title: t('bd.add_card'),
        hint: t('bd.card_title_hint'),
        maxLength: maxCardTitle);
    if (title == null || !mounted) return;
    final r = _svc.addCard(b, all, colId, title);
    fireAndReport(context, r.done);
    HapticFeedback.lightImpact();
  }

  Future<void> _columnMenu(Board b, List<TaskCard> all, BoardColumn col) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.add),
              title: Text(t('bd.add_card')),
              onTap: () => Navigator.pop(ctx, 'add'),
            ),
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.edit_outlined),
              title: Text(t('bd.rename')),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.tune),
              title: Text(t('bd.settings')),
              onTap: () => Navigator.pop(ctx, 'settings'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'add') await _addCard(b, all, col.id);
    if (action == 'rename') {
      final name = await askText(context,
          title: t('bd.rename'), initial: col.name, maxLength: 40);
      if (name == null || !mounted) return;
      fireAndReport(
          context,
          _svc.setColumns(b.id, [
            for (final c in b.columns)
              c.id == col.id ? c.copyWith(name: name) : c,
          ]));
    }
    if (action == 'settings') _openSettings();
  }

  void _openSettings() => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            BoardSettingsScreen(boardId: widget.boardId, service: _svc),
      ));

  Future<void> _openFilter(Board b) async {
    final f = await showModalBottomSheet<CardFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(board: b, filter: _filter, me: _svc.me),
    );
    if (f != null && mounted) setState(() => _filter = f);
  }

  // ------------------------------------------------------------ интерфейс

  Widget _column(Board b, List<TaskCard> all, BoardColumn col, int index) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final canEdit = b.canEdit(_svc.me);
    final inCol = cardsIn(all, col.id);
    final shown = [
      for (final c in inCol)
        if (_filter.matches(c, now, done: col.done)) c,
    ];
    final over = col.limit > 0 && inCol.length > col.limit;

    Widget cardWidget(TaskCard c) {
      final tile = TaskTile(
        board: b,
        card: c,
        onTap: () => showCardSheet(context, b.id, c.id, service: _svc),
        onNext: canEdit && b.nextColumn(c.column) != null
            ? () => _next(b, all, c)
            : null,
      );
      if (!canEdit) return tile;
      return LongPressDraggable<TaskCard>(
        data: c,
        hapticFeedbackOnStart: true,
        onDragStarted: () => setState(() => _dragging = true),
        onDragEnd: (_) => setState(() => _dragging = false),
        onDraggableCanceled: (_, __) => setState(() => _dragging = false),
        onDragUpdate: _onDragUpdate,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.78,
            child: Transform.rotate(
              angle: -0.03,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(16),
                child: TaskTile(board: b, card: c),
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: tile),
        child: tile,
      );
    }

    // Цель «вставить перед этой карточкой».
    // Место считаем среди остальных карточек колонки (без перетаскиваемой).
    int indexBefore(TaskCard target, TaskCard dragged) => inCol
        .where((x) => x.id != dragged.id)
        .toList()
        .indexWhere((x) => x.id == target.id);

    Widget slot(TaskCard c) => DragTarget<TaskCard>(
          onWillAcceptWithDetails: (d) => d.data.id != c.id,
          onAcceptWithDetails: (d) =>
              _move(b, all, d.data, col.id, indexBefore(c, d.data)),
          builder: (ctx, cand, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: cand.isNotEmpty ? 56 : 0,
                margin: EdgeInsets.only(bottom: cand.isNotEmpty ? 8 : 0),
                // Рамку рисуем только при наведении, иначе видна полоска.
                decoration: cand.isEmpty
                    ? null
                    : BoxDecoration(
                        color: scheme.primary.withAlpha(40),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: scheme.primary, width: 2),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: cardWidget(c),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Заголовок колонки.
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 4, 2),
              child: Row(
                children: [
                  if (col.done)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.check_circle,
                          size: 18, color: Color(0xFF16A34A)),
                    ),
                  Expanded(
                    child: Text(col.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: over
                          ? scheme.errorContainer
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      col.limit > 0
                          ? t('bd.limit', {'n': inCol.length, 'max': col.limit})
                          : '${inCol.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: over ? scheme.onErrorContainer : null,
                      ),
                    ),
                  ),
                  if (canEdit)
                    IconButton(
                      tooltip: t('lib.more'),
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _columnMenu(b, all, col),
                    ),
                ],
              ),
            ),
            // Карточки.
            Expanded(
              child: DragTarget<TaskCard>(
                onWillAcceptWithDetails: (_) => canEdit,
                onAcceptWithDetails: (d) => _move(b, all, d.data, col.id,
                    inCol.where((x) => x.id != d.data.id).length),
                builder: (ctx, cand, _) => AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: cand.isNotEmpty
                        ? scheme.primary.withAlpha(20)
                        : Colors.transparent,
                  ),
                  child: shown.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              _filter.isEmpty
                                  ? t('bd.col_empty')
                                  : t('lib.nothing'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
                          children: [
                            for (var i = 0; i < shown.length; i++)
                              canEdit
                                  ? slot(shown[i])
                                  : Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: cardWidget(shown[i]),
                                    ),
                          ],
                        ),
                ),
              ),
            ),
            if (canEdit)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                  onPressed: () => _addCard(b, all, col.id),
                  icon: const Icon(Icons.add),
                  label: Text(t('bd.add_card')),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<Board?>(
      stream: _board,
      builder: (ctx, bs) {
        final b = bs.data;
        if (bs.hasError) {
          return Scaffold(
              appBar: AppBar(), body: Center(child: Text(t('bd.err.load'))));
        }
        if (b == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: bs.connectionState == ConnectionState.waiting
                  ? const CircularProgressIndicator()
                  : Text(t('bd.deleted')),
            ),
          );
        }
        final color = boardColor(b.color);
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                Icon(boardIcon(b.icon), color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(b.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: t('bd.filter'),
                isSelected: !_filter.isEmpty,
                icon: Badge(
                  isLabelVisible: !_filter.isEmpty,
                  smallSize: 8,
                  child: const Icon(Icons.filter_list),
                ),
                onPressed: () => _openFilter(b),
              ),
              IconButton(
                tooltip: t('bd.settings'),
                icon: const Icon(Icons.tune),
                onPressed: _openSettings,
              ),
            ],
          ),
          body: StreamBuilder<List<TaskCard>>(
            stream: _cards,
            builder: (ctx, cs) {
              final all = cs.data ?? const <TaskCard>[];
              return Column(
                children: [
                  if (!b.canEdit(_svc.me))
                    MaterialBanner(
                      content: Text(t('bd.read_only')),
                      leading: const Icon(Icons.visibility_outlined),
                      actions: const [SizedBox.shrink()],
                    ),
                  if (!_filter.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              t('bd.f.found', {
                                'n': all
                                    .where((c) => _filter.matches(
                                        c, DateTime.now(),
                                        done: b.isDoneColumn(c.column)))
                                    .length,
                              }),
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48)),
                            onPressed: () =>
                                setState(() => _filter = const CardFilter()),
                            child: Text(t('bd.filter_reset')),
                          ),
                        ],
                      ),
                    ),
                  // Точки-индикатор колонок.
                  _PageDots(controller: _pages, count: b.columns.length),
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      padEnds: false,
                      // Во время перетаскивания листаем только у краёв экрана.
                      physics: _dragging
                          ? const NeverScrollableScrollPhysics()
                          : const PageScrollPhysics(),
                      itemCount: b.columns.length,
                      itemBuilder: (_, i) => Padding(
                        padding: EdgeInsets.only(
                          left: i == 0 ? 10 : 0,
                          bottom: MediaQuery.of(ctx).viewPadding.bottom,
                        ),
                        child: _column(b, all, b.columns[i], i),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.controller, required this.count});
  final PageController controller;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final page = controller.hasClients && controller.positions.length == 1
            ? (controller.page ?? 0).round()
            : 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == page ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == page ? scheme.primary : scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Нижняя панель фильтров.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet(
      {required this.board, required this.filter, required this.me});
  final Board board;
  final CardFilter filter;
  final String me;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late CardFilter _f = widget.filter;
  late final TextEditingController _q =
      TextEditingController(text: widget.filter.query);

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Widget _title(String s) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(s,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      );

  @override
  Widget build(BuildContext context) {
    final b = widget.board;
    final bottom = MediaQuery.of(context).viewPadding.bottom +
        MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('bd.filter'),
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(
            controller: _q,
            decoration: InputDecoration(
              hintText: t('bd.search'),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          _title(t('bd.f.assignee')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip(t('bd.f.anyone'), _f.assignee == null,
                () => setState(() => _f = _f.copyWith(assignee: () => null))),
            _chip(
                t('bd.f.me'),
                _f.assignee == widget.me,
                () => setState(
                    () => _f = _f.copyWith(assignee: () => widget.me))),
            _chip(t('bd.f.nobody'), _f.assignee == '',
                () => setState(() => _f = _f.copyWith(assignee: () => ''))),
            for (final m in b.members)
              if (m != widget.me)
                ChoiceChip(
                  label: MemberName(m),
                  selected: _f.assignee == m,
                  showCheckmark: false,
                  onSelected: (_) =>
                      setState(() => _f = _f.copyWith(assignee: () => m)),
                ),
          ]),
          if (b.labels.isNotEmpty) ...[
            _title(t('bd.f.label')),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _chip(t('bd.f.any_label'), _f.label == null,
                  () => setState(() => _f = _f.copyWith(label: () => null))),
              for (final l in b.labels)
                ChoiceChip(
                  avatar: CircleAvatar(
                      radius: 6, backgroundColor: boardColor(l.color)),
                  label: Text(l.name),
                  selected: _f.label == l.id,
                  showCheckmark: false,
                  onSelected: (_) =>
                      setState(() => _f = _f.copyWith(label: () => l.id)),
                ),
            ]),
          ],
          _title(t('bd.f.priority')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip(t('bd.f.any_priority'), _f.priority == null,
                () => setState(() => _f = _f.copyWith(priority: () => null))),
            for (var p = 3; p >= 0; p--)
              ChoiceChip(
                avatar:
                    CircleAvatar(radius: 6, backgroundColor: priorityColor(p)),
                label: Text(priorityLabel(p)),
                selected: _f.priority == p,
                showCheckmark: false,
                onSelected: (_) =>
                    setState(() => _f = _f.copyWith(priority: () => p)),
              ),
          ]),
          _title(t('bd.f.due')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final d in DueFilter.values)
              _chip(t('bd.f.due.${d.name}'), _f.due == d,
                  () => setState(() => _f = _f.copyWith(due: d))),
          ]),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  onPressed: () => Navigator.pop(context, const CardFilter()),
                  child: Text(t('bd.filter_reset')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, _f.copyWith(query: _q.text)),
                  child: Text(t('bd.ok')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
