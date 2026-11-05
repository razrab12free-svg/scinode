import 'package:flutter/material.dart';

import '../models/board.dart';
import '../models/grant.dart';
import '../services/board_service.dart';
import '../strings.dart';
import '../widgets/board_widgets.dart';
import 'board_screen.dart';

/// Ссылка на конкурс для карточки.
LinkedGrant linkedFromCall(GrantCall c) => LinkedGrant(
      source: c.source.name,
      id: c.id,
      number: c.number,
      title: c.title,
      url: c.url,
      deadline: c.deadline,
    );

String _cut(String s, int n) => s.length > n ? '${s.substring(0, n - 1)}…' : s;

/// Карточки доски «Заявка на грант» для конкурса [c]: карточка подачи
/// с дедлайном и ссылкой, плюс контрольные точки за 30, 14 и 7 дней
/// (только те, что ещё впереди).
List<NewCard> grantPlan(GrantCall c, DateTime now) {
  final g = linkedFromCall(c);
  final title = _cut(c.title, 150);
  final out = <NewCard>[];
  final dl = c.deadline;
  if (dl != null) {
    final today = DateTime(now.year, now.month, now.day);
    for (final (days, key) in [(30, 'm30'), (14, 'm14'), (7, 'm7')]) {
      final d = dl.subtract(Duration(days: days));
      if (!DateTime(d.year, d.month, d.day).isBefore(today)) {
        out.add(NewCard(title: t('bd.grant_$key'), column: 0, due: d));
      }
    }
  }
  // Колонка «На проверке» шаблона заявки — предпоследняя (индекс 3).
  out.add(NewCard(
    title: t('bd.grant_card', {'title': title}),
    column: 3,
    due: dl,
    grants: [g],
  ));
  return out;
}

/// «Готовить заявку»: доска по шаблону заявки с контрольными точками.
void prepareApplication(BuildContext context, GrantCall c,
    {BoardService? service}) {
  final svc = service ?? BoardService.instance;
  final tpl = templateOf('grant');
  final r = svc.createBoard(
    name: _cut(t('bd.grant_board_name', {'title': c.title}), maxBoardName),
    template: tpl.key,
    color: tpl.color,
    icon: tpl.icon,
    columns: [for (final col in tpl.columns) t('bt.col.$col')],
    cards: [for (final (k, col) in tpl.cards) (t('bt.card.$k'), col)],
    extra: grantPlan(c, DateTime.now()),
  );
  fireAndReport(context, r.done);
  toast(context, t('bd.grant_created'));
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => BoardScreen(boardId: r.id, service: svc),
  ));
}

/// «Добавить в проект»: карточка с конкурсом в первой колонке выбранной доски.
Future<void> addGrantToProject(BuildContext context, GrantCall c,
    {BoardService? service}) async {
  final svc = service ?? BoardService.instance;
  List<Board> boards;
  try {
    boards = (await svc.boards().first)
        .where((b) => !b.archived && b.canEdit(svc.me))
        .toList();
  } catch (e) {
    if (context.mounted) toast(context, boardError(e));
    return;
  }
  if (!context.mounted) return;
  if (boards.isEmpty) {
    toast(context, t('bd.no_boards'));
    return;
  }
  final b = await showModalBottomSheet<Board>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => ListView(
      shrinkWrap: true,
      padding:
          EdgeInsets.only(bottom: 16 + MediaQuery.of(ctx).viewPadding.bottom),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(t('bd.choose_board'),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ),
        for (final b in boards)
          ListTile(
            minTileHeight: 56,
            leading: Icon(boardIcon(b.icon), color: boardColor(b.color)),
            title: Text(b.name),
            onTap: () => Navigator.pop(ctx, b),
          ),
      ],
    ),
  );
  if (b == null || !context.mounted) return;
  final cards = await svc.cards(b.id).first;
  if (!context.mounted) return;
  final r = svc.addCard(
    b,
    cards,
    b.columns.first.id,
    t('bd.grant_card', {'title': _cut(c.title, 150)}),
    due: c.deadline,
    grants: [linkedFromCall(c)],
  );
  fireAndReport(context, r.done);
  toast(context, t('bd.added_to', {'name': b.name}));
}
