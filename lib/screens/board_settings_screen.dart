import 'package:flutter/material.dart';

import '../models/board.dart';
import '../models/chat.dart';
import '../models/profile.dart';
import '../services/board_service.dart';
import '../services/chat_service.dart';
import '../services/profile_service.dart';
import '../strings.dart';
import '../widgets/board_widgets.dart';

/// Настройки доски.
class BoardSettingsScreen extends StatefulWidget {
  const BoardSettingsScreen({super.key, required this.boardId, this.service});
  final String boardId;
  final BoardService? service;

  @override
  State<BoardSettingsScreen> createState() => _BoardSettingsScreenState();
}

class _BoardSettingsScreenState extends State<BoardSettingsScreen> {
  late final BoardService _svc = widget.service ?? BoardService.instance;
  late final Stream<Board?> _board = _svc.board(widget.boardId);
  late final Stream<List<TaskCard>> _cards = _svc.cards(widget.boardId);

  void _fire(Future<void> f) => fireAndReport(context, f);

  Widget _section(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
        child: Text(s,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary)),
      );

  // ------------------------------------------------------------- колонки

  Future<void> _editColumn(Board b, BoardColumn? col) async {
    final r = await showDialog<BoardColumn>(
      context: context,
      builder: (_) =>
          _ColumnDialog(column: col ?? BoardColumn(id: _svc.newId(), name: '')),
    );
    if (r == null || !mounted) return;
    final cols = col == null
        ? [...b.columns, r]
        : [for (final c in b.columns) c.id == col.id ? r : c];
    _fire(_svc.setColumns(b.id, cols));
  }

  Future<void> _deleteColumn(
      Board b, List<TaskCard> all, BoardColumn col) async {
    if (b.columns.length <= 1) {
      toast(context, t('bd.col_last'));
      return;
    }
    final targets = b.columns.where((c) => c.id != col.id).toList();
    final n = cardsIn(all, col.id).length;
    String target = targets.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text(t('bd.col_delete')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('bd.col_delete_q', {'col': col.name, 'n': n})),
              if (n > 0) ...[
                const SizedBox(height: 12),
                Text(t('bd.col_move_to'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                RadioGroup<String>(
                  groupValue: target,
                  onChanged: (v) => setD(() => target = v ?? target),
                  child: Column(
                    children: [
                      for (final c in targets)
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          value: c.id,
                          title: Text(c.name),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: Text(t('bd.cancel'))),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(96, 48),
                backgroundColor: Theme.of(d).colorScheme.error,
                foregroundColor: Theme.of(d).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(d, true),
              child: Text(t('bd.delete_do')),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    _fire(_svc.deleteColumn(b, all, col.id, target));
  }

  // --------------------------------------------------------------- метки

  Future<void> _editLabel(Board b, BoardLabel? l) async {
    final r = await showDialog<BoardLabel>(
      context: context,
      builder: (_) => _LabelDialog(
          label: l ?? BoardLabel(id: _svc.newId(), name: '', color: 7)),
    );
    if (r == null || !mounted) return;
    if (r.name.isEmpty) {
      // Пустое название — удалить метку.
      _fire(_svc.setLabels(b.id, [
        for (final x in b.labels)
          if (x.id != r.id) x
      ]));
      return;
    }
    final list = l == null
        ? [...b.labels, r]
        : [for (final x in b.labels) x.id == r.id ? r : x];
    _fire(_svc.setLabels(b.id, list));
  }

  // ----------------------------------------------------------- участники

  Future<void> _invite(Board b) async {
    final picked = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _InviteSheet(board: b, me: _svc.me),
    );
    if (picked == null || !mounted) return;
    _fire(_svc.addMember(b, picked.uid, BoardRole.editor));
    toast(context, t('bd.invited', {'name': picked.name}));
  }

  Future<void> _memberMenu(Board b, String uid) async {
    final me = _svc.me;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: MemberName(uid,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            for (final r in [BoardRole.editor, BoardRole.viewer])
              ListTile(
                minTileHeight: 56,
                leading: Icon(b.roleOf(uid) == r
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                title: Text(roleLabel(r)),
                onTap: () => Navigator.pop(ctx, r.name),
              ),
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.workspace_premium_outlined),
              title: Text(t('bd.make_owner')),
              onTap: () => Navigator.pop(ctx, 'owner'),
            ),
            ListTile(
              minTileHeight: 56,
              leading: Icon(Icons.person_remove_outlined,
                  color: Theme.of(ctx).colorScheme.error),
              title: Text(t('bd.remove_member'),
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'editor':
        _fire(_svc.setRole(b, uid, BoardRole.editor));
      case 'viewer':
        _fire(_svc.setRole(b, uid, BoardRole.viewer));
      case 'remove':
        _fire(_svc.removeMember(b, uid));
      case 'owner':
        final p = await MemberNames.lookup(uid);
        if (!mounted) return;
        final ok = await confirmDanger(context,
            title: t('bd.make_owner'),
            text:
                t('bd.make_owner_q', {'name': p?.name ?? t('bd.unknown_user')}),
            action: t('bd.ok'));
        if (ok && mounted) _fire(_svc.transferOwnership(b, uid));
    }
    if (uid == me) return;
  }

  Future<void> _leave(Board b) async {
    final ok = await confirmDanger(context,
        title: t('bd.leave'),
        text: t('bd.leave_q', {'name': b.name}),
        action: t('bd.leave'));
    if (!ok || !mounted) return;
    final nav = Navigator.of(context);
    _fire(_svc.leave(b));
    nav.popUntil((r) => r.isFirst);
  }

  Future<void> _delete(Board b) async {
    final ok = await confirmDanger(context,
        title: t('bd.delete'), text: t('bd.delete_q', {'name': b.name}));
    if (!ok || !mounted) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    nav.popUntil((r) => r.isFirst);
    try {
      await _svc.deleteBoard(b.id);
      messenger.showSnackBar(SnackBar(content: Text(t('bd.deleted'))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(boardError(e))));
    }
  }

  // ---------------------------------------------------------------- вид

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<Board?>(
      stream: _board,
      builder: (ctx, bs) => StreamBuilder<List<TaskCard>>(
        stream: _cards,
        builder: (ctx, cs) {
          final b = bs.data;
          final all = cs.data ?? const <TaskCard>[];
          if (b == null) {
            return Scaffold(
                appBar: AppBar(),
                body: const Center(child: CircularProgressIndicator()));
          }
          final me = _svc.me;
          final edit = b.canEdit(me);
          final owner = b.isOwner(me);
          final bottom = MediaQuery.of(ctx).viewPadding.bottom;
          return Scaffold(
            appBar: AppBar(title: Text(t('bd.settings'))),
            body: ListView(
              padding: EdgeInsets.only(bottom: 24 + bottom),
              children: [
                ListTile(
                  minTileHeight: 56,
                  leading: Icon(boardIcon(b.icon), color: boardColor(b.color)),
                  title: Text(b.name,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  trailing: edit ? const Icon(Icons.edit_outlined) : null,
                  onTap: edit
                      ? () async {
                          final v = await askText(context,
                              title: t('bd.rename'),
                              initial: b.name,
                              maxLength: maxBoardName);
                          if (v != null && mounted) _fire(_svc.rename(b.id, v));
                        }
                      : null,
                ),
                if (edit) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      children: [
                        for (var i = 0; i < boardColors.length; i++)
                          InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _fire(_svc.setLook(b.id, color: i)),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: boardColor(i),
                                    shape: BoxShape.circle,
                                    border: i == b.color
                                        ? Border.all(
                                            color: scheme.onSurface, width: 3)
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      children: [
                        for (final ic in boardIcons)
                          IconButton(
                            isSelected: ic == b.icon,
                            style: IconButton.styleFrom(
                                minimumSize: const Size(48, 48)),
                            icon: Icon(boardIcon(ic),
                                color:
                                    ic == b.icon ? boardColor(b.color) : null),
                            onPressed: () =>
                                _fire(_svc.setLook(b.id, icon: ic)),
                          ),
                      ],
                    ),
                  ),
                ],

                // Колонки.
                _section(t('bd.columns')),
                if (edit)
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    // newIndex уже учитывает убранный элемент.
                    onReorderItem: (from, to) {
                      final cols = [...b.columns];
                      final c = cols.removeAt(from);
                      cols.insert(to.clamp(0, cols.length), c);
                      _fire(_svc.setColumns(b.id, cols));
                    },
                    children: [
                      for (var i = 0; i < b.columns.length; i++)
                        ListTile(
                          key: ValueKey(b.columns[i].id),
                          minTileHeight: 56,
                          leading: ReorderableDragStartListener(
                            index: i,
                            child: const SizedBox(
                                width: 48,
                                height: 48,
                                child: Icon(Icons.drag_indicator)),
                          ),
                          title: Text(b.columns[i].name),
                          subtitle: Text([
                            '${cardsIn(all, b.columns[i].id).length}',
                            if (b.columns[i].limit > 0)
                              '≤ ${b.columns[i].limit}',
                            if (b.columns[i].done) t('bt.col.done'),
                          ].join(' · ')),
                          onTap: () => _editColumn(b, b.columns[i]),
                          trailing: IconButton(
                            tooltip: t('bd.col_delete'),
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                _deleteColumn(b, all, b.columns[i]),
                          ),
                        ),
                    ],
                  )
                else
                  for (final c in b.columns)
                    ListTile(title: Text(c.name), minTileHeight: 48),
                if (edit)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: b.columns.length >= maxColumns
                          ? () => toast(context, t('bd.col_max'))
                          : () => _editColumn(b, null),
                      icon: const Icon(Icons.add),
                      label: Text(t('bd.col_add')),
                    ),
                  ),

                // Метки.
                _section(t('bd.labels')),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final l in b.labels)
                        ActionChip(
                          avatar: CircleAvatar(
                              radius: 6, backgroundColor: boardColor(l.color)),
                          label: Text(l.name),
                          onPressed: edit ? () => _editLabel(b, l) : null,
                        ),
                      if (edit && b.labels.length < maxLabels)
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: Text(t('bd.label_add')),
                          onPressed: () => _editLabel(b, null),
                        ),
                    ],
                  ),
                ),

                // Участники.
                _section(t('bd.members')),
                for (final u in b.members)
                  ListTile(
                    minTileHeight: 56,
                    leading: MemberAvatar(u, radius: 18),
                    title: u == me ? Text(t('bd.f.me')) : MemberName(u),
                    subtitle: Text(roleLabel(b.roleOf(u) ?? BoardRole.viewer)),
                    trailing:
                        owner && u != me ? const Icon(Icons.more_vert) : null,
                    onTap: owner && u != me ? () => _memberMenu(b, u) : null,
                  ),
                if (owner)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: b.members.length >= maxMembers
                          ? () => toast(context, t('bd.err.limit'))
                          : () => _invite(b),
                      icon: const Icon(Icons.person_add_alt),
                      label: Text(t('bd.invite')),
                    ),
                  ),

                // Действия.
                const SizedBox(height: 24),
                if (edit)
                  ListTile(
                    minTileHeight: 56,
                    leading: Icon(b.archived
                        ? Icons.unarchive_outlined
                        : Icons.inventory_2_outlined),
                    title: Text(
                        b.archived ? t('bd.unarchive') : t('bd.archive_do')),
                    onTap: () => _fire(_svc.setArchived(b.id, !b.archived)),
                  ),
                if (!owner)
                  ListTile(
                    minTileHeight: 56,
                    leading: Icon(Icons.logout, color: scheme.error),
                    title: Text(t('bd.leave'),
                        style: TextStyle(color: scheme.error)),
                    onTap: () => _leave(b),
                  ),
                if (owner)
                  ListTile(
                    minTileHeight: 56,
                    leading: Icon(Icons.delete_forever_outlined,
                        color: scheme.error),
                    title: Text(t('bd.delete'),
                        style: TextStyle(color: scheme.error)),
                    onTap: () => _delete(b),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ColumnDialog extends StatefulWidget {
  const _ColumnDialog({required this.column});
  final BoardColumn column;

  @override
  State<_ColumnDialog> createState() => _ColumnDialogState();
}

class _ColumnDialogState extends State<_ColumnDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.column.name);
  late final TextEditingController _limit = TextEditingController(
      text: widget.column.limit > 0 ? '${widget.column.limit}' : '0');
  late bool _done = widget.column.done;

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    super.dispose();
  }

  void _ok() {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    final lim = int.tryParse(_limit.text.trim()) ?? 0;
    Navigator.pop(context,
        widget.column.copyWith(name: n, limit: lim.clamp(0, 99), done: _done));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title:
            Text(widget.column.name.isEmpty ? t('bd.col_add') : t('bd.rename')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                maxLength: 40,
                decoration: InputDecoration(
                    labelText: t('bd.col_name'),
                    border: const OutlineInputBorder()),
              ),
              TextField(
                controller: _limit,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: t('bd.col_limit'),
                    border: const OutlineInputBorder()),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _done,
                onChanged: (v) => setState(() => _done = v),
                title: Text(t('bd.col_done'),
                    style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t('bd.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
            onPressed: _ok,
            child: Text(t('bd.ok')),
          ),
        ],
      );
}

class _LabelDialog extends StatefulWidget {
  const _LabelDialog({required this.label});
  final BoardLabel label;

  @override
  State<_LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends State<_LabelDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.label.name);
  late int _color = widget.label.color;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
            widget.label.name.isEmpty ? t('bd.label_add') : t('bd.rename')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 30,
              decoration: InputDecoration(
                  labelText: t('bd.label_name'),
                  border: const OutlineInputBorder()),
            ),
            Wrap(
              children: [
                for (var i = 0; i < boardColors.length; i++)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _color = i),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: boardColor(i),
                            shape: BoxShape.circle,
                            border: i == _color
                                ? Border.all(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    width: 3)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          if (widget.label.name.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context,
                  BoardLabel(id: widget.label.id, name: '', color: _color)),
              child: Text(t('bd.delete_do')),
            ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t('bd.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
            onPressed: () {
              final n = _name.text.trim();
              if (n.isEmpty) return;
              Navigator.pop(context,
                  BoardLabel(id: widget.label.id, name: n, color: _color));
            },
            child: Text(t('bd.ok')),
          ),
        ],
      );
}

/// Приглашение: собеседники из чата и поиск среди опубликованных профилей.
class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.board, required this.me});
  final Board board;
  final String me;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final TextEditingController _q = TextEditingController();
  List<UserProfile> _contacts = const [];
  List<UserProfile> _members = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _q.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final contacts = <UserProfile>[];
    final chat = ChatService.instance;
    if (chat.available) {
      try {
        final convs = await chat.conversations().first;
        for (final c in convs) {
          if (c.status != ChatStatus.accepted) continue;
          final p = await chat.profileOf(c.other(widget.me));
          if (p != null) contacts.add(p);
        }
      } catch (_) {}
    }
    final res = await ProfileService.instance.searchMembers();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _members = res.items;
      _loading = false;
    });
  }

  bool _can(UserProfile p) =>
      p.uid != widget.me && !widget.board.members.contains(p.uid);

  Widget _tile(UserProfile p) => ListTile(
        minTileHeight: 56,
        leading: MemberAvatar(p.uid, radius: 18),
        title: Text(p.name),
        subtitle: p.org.isEmpty ? null : Text(p.org, maxLines: 1),
        trailing: const Icon(Icons.person_add_alt),
        onTap: () => Navigator.pop(context, p),
      );

  @override
  Widget build(BuildContext context) {
    final q = _q.text.trim().toLowerCase();
    final contacts = [
      for (final p in _contacts)
        if (_can(p)) p
    ];
    final found = q.isEmpty
        ? const <UserProfile>[]
        : [
            for (final p in _members)
              if (_can(p) &&
                  p.name.toLowerCase().contains(q) &&
                  !contacts.any((c) => c.uid == p.uid))
                p,
          ];
    final bottom = MediaQuery.of(context).viewPadding.bottom +
        MediaQuery.of(context).viewInsets.bottom;
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(0, 0, 0, 16 + bottom),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(t('bd.invite_title'),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _q,
            decoration: InputDecoration(
              hintText: t('bd.invite_search'),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (contacts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(t('bd.invite_contacts'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final p in contacts)
              if (q.isEmpty || p.name.toLowerCase().contains(q)) _tile(p),
          ],
          for (final p in found) _tile(p),
          if (contacts.isEmpty && found.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(t('bd.invite_none'), textAlign: TextAlign.center),
            ),
        ],
      ],
    );
  }
}
