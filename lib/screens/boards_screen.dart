import 'package:flutter/material.dart';

import '../models/board.dart';
import '../services/board_service.dart';
import '../strings.dart';
import '../widgets/board_widgets.dart';
import 'board_screen.dart';
import 'my_tasks_screen.dart';

/// «Мои проекты»: список досок.
class BoardsScreen extends StatefulWidget {
  const BoardsScreen({super.key, this.service});
  final BoardService? service;

  @override
  State<BoardsScreen> createState() => _BoardsScreenState();
}

class _BoardsScreenState extends State<BoardsScreen> {
  late final BoardService _svc = widget.service ?? BoardService.instance;
  late final Stream<List<Board>>? _boards =
      _svc.available ? _svc.boards() : null;
  bool _showArchive = false;

  Future<void> _create() async {
    final id = await showCreateBoardSheet(context, _svc);
    if (id != null && mounted) openBoard(context, id, service: _svc);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('bd.title')),
        actions: [
          if (_boards != null)
            IconButton(
              tooltip: t('bd.my_tasks'),
              icon: const Icon(Icons.task_alt),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => MyTasksScreen(service: _svc))),
            ),
        ],
      ),
      floatingActionButton: _boards == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: Text(t('bd.new')),
            ),
      body: _boards == null
          ? _Empty(icon: Icons.lock_outline, text: t('bd.not_ready'))
          : StreamBuilder<List<Board>>(
              stream: _boards,
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return _Empty(icon: Icons.cloud_off, text: t('bd.err.load'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final active = snap.data!.where((b) => !b.archived).toList();
                final archived = snap.data!.where((b) => b.archived).toList();
                if (active.isEmpty && archived.isEmpty) {
                  return _Empty(
                    icon: Icons.view_kanban_outlined,
                    title: t('bd.empty_title'),
                    text: t('bd.empty_text'),
                    action: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(200, 52)),
                      onPressed: _create,
                      icon: const Icon(Icons.add),
                      label: Text(t('bd.new')),
                    ),
                  );
                }
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                      16, 8, 16, 96 + MediaQuery.of(ctx).viewPadding.bottom),
                  children: [
                    for (final b in active) _BoardTile(board: b, svc: _svc),
                    if (archived.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text('${t('bd.archive')} (${archived.length})'),
                        trailing: Icon(_showArchive
                            ? Icons.expand_less
                            : Icons.expand_more),
                        onTap: () =>
                            setState(() => _showArchive = !_showArchive),
                      ),
                      if (_showArchive)
                        for (final b in archived)
                          _BoardTile(board: b, svc: _svc),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(
      {required this.icon, required this.text, this.title, this.action});
  final IconData icon;
  final String text;
  final String? title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: scheme.primary.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            if (title != null) ...[
              Text(title!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
            ],
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15)),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class _BoardTile extends StatelessWidget {
  const _BoardTile({required this.board, required this.svc});
  final Board board;
  final BoardService svc;

  /// Меню доски в списке: архив, удалить (владелец) или выйти.
  Future<void> _menu(BuildContext context) async {
    final me = svc.me;
    final owner = board.isOwner(me);
    final scheme = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (board.canEdit(me))
              ListTile(
                minTileHeight: 56,
                leading: Icon(board.archived
                    ? Icons.unarchive_outlined
                    : Icons.inventory_2_outlined),
                title: Text(
                    board.archived ? t('bd.unarchive') : t('bd.archive_do')),
                onTap: () => Navigator.pop(ctx, 'archive'),
              ),
            ListTile(
              minTileHeight: 56,
              leading: Icon(
                  owner ? Icons.delete_forever_outlined : Icons.logout,
                  color: scheme.error),
              title: Text(owner ? t('bd.delete') : t('bd.leave'),
                  style: TextStyle(color: scheme.error)),
              onTap: () => Navigator.pop(ctx, owner ? 'delete' : 'leave'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'archive':
        fireAndReport(context, svc.setArchived(board.id, !board.archived));
      case 'leave':
        final ok = await confirmDanger(context,
            title: t('bd.leave'),
            text: t('bd.leave_q', {'name': board.name}),
            action: t('bd.leave'));
        if (ok && context.mounted) fireAndReport(context, svc.leave(board));
      case 'delete':
        final ok = await confirmDanger(context,
            title: t('bd.delete'),
            text: t('bd.delete_q', {'name': board.name}));
        if (!ok || !context.mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        try {
          await svc.deleteBoard(board.id);
          messenger.showSnackBar(SnackBar(content: Text(t('bd.deleted'))));
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(boardError(e))));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = boardColor(board.color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openBoard(context, board.id, service: svc),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withAlpha(40),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(boardIcon(board.icon), color: color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(board.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      StreamBuilder<List<TaskCard>>(
                        stream: svc.cards(board.id),
                        builder: (_, s) {
                          final cards = s.data ?? const <TaskCard>[];
                          final st =
                              BoardStats.of(board, cards, DateTime.now());
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: st.total == 0 ? 0 : st.done / st.total,
                                  minHeight: 6,
                                  color: color,
                                  backgroundColor: color.withAlpha(40),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 10,
                                children: [
                                  Text(t('bd.progress', {'p': st.percent}),
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: scheme.onSurfaceVariant)),
                                  Text(t('bd.tasks_count', {'n': st.total}),
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: scheme.onSurfaceVariant)),
                                  if (st.overdue > 0)
                                    Text(
                                        '${t('bd.f.due.overdue')}: ${st.overdue}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: scheme.error)),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    if (board.isShared)
                      Tooltip(
                        message: t('bd.shared'),
                        child: Icon(Icons.people_outline,
                            color: scheme.onSurfaceVariant),
                      ),
                    if (board.archived)
                      Tooltip(
                        message: t('bd.archived'),
                        child: Icon(Icons.inventory_2_outlined,
                            color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
                IconButton(
                  tooltip: t('lib.more'),
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _menu(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Открывает доску.
void openBoard(BuildContext context, String id, {BoardService? service}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BoardScreen(boardId: id, service: service),
    ));

/// Окно создания доски: шаблон, название, цвет, значок.
/// Возвращает id созданной доски.
Future<String?> showCreateBoardSheet(BuildContext context, BoardService svc,
    {String? initialTemplate}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _CreateSheet(svc: svc, initial: initialTemplate),
  );
}

class _CreateSheet extends StatefulWidget {
  const _CreateSheet({required this.svc, this.initial});
  final BoardService svc;
  final String? initial;

  @override
  State<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends State<_CreateSheet> {
  late BoardTemplate _tpl = templateOf(widget.initial ?? 'paper');
  late final TextEditingController _name =
      TextEditingController(text: t('bt.${_tpl.key}'));
  late int _color = _tpl.color;
  late String _icon = _tpl.icon;
  bool _nameTouched = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _pick(BoardTemplate tpl) {
    setState(() {
      _tpl = tpl;
      _color = tpl.color;
      _icon = tpl.icon;
      if (!_nameTouched) _name.text = t('bt.${tpl.key}');
    });
  }

  void _create() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = t('bd.name_required'));
      return;
    }
    final r = widget.svc.createBoard(
      name: name,
      template: _tpl.key,
      color: _color,
      icon: _icon,
      columns: [for (final c in _tpl.columns) t('bt.col.$c')],
      cards: [for (final (k, col) in _tpl.cards) (t('bt.card.$k'), col)],
    );
    fireAndReport(context, r.done);
    Navigator.pop(context, r.id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewPadding.bottom +
        MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('bd.new'),
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(t('bd.choose_template'),
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final tpl in boardTemplates)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: tpl == _tpl
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _pick(tpl),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(boardIcon(tpl.icon),
                            color: boardColor(tpl.color), size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t('bt.${tpl.key}'),
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                              Text(
                                tpl.columns
                                    .map((c) => t('bt.col.$c'))
                                    .join(' → '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        if (tpl == _tpl)
                          Icon(Icons.check_circle, color: scheme.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            maxLength: maxBoardName,
            onChanged: (_) => _nameTouched = true,
            decoration: InputDecoration(
              labelText: t('bd.name'),
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
          Text(t('bd.color'),
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 0; i < boardColors.length; i++)
                Semantics(
                  selected: i == _color,
                  button: true,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _color = i),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: boardColor(i),
                            shape: BoxShape.circle,
                            border: i == _color
                                ? Border.all(color: scheme.onSurface, width: 3)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(t('bd.icon'),
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final ic in boardIcons)
                IconButton(
                  isSelected: ic == _icon,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor:
                        ic == _icon ? boardColor(_color).withAlpha(50) : null,
                  ),
                  icon: Icon(boardIcon(ic),
                      color: ic == _icon ? boardColor(_color) : null),
                  onPressed: () => setState(() => _icon = ic),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: Text(t('bd.create')),
          ),
        ],
      ),
    );
  }
}
