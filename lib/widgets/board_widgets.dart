import 'dart:async';

import 'package:flutter/material.dart';

import '../models/board.dart';
import '../models/profile.dart';
import '../services/board_service.dart';
import '../services/chat_service.dart';
import '../strings.dart';
import 'grant_card.dart' show urgencyColors, Pill;
import '../models/grant.dart' show Urgency;
import 'scientist_card.dart' show initials;

/// Иконка доски по ключу.
IconData boardIcon(String key) => switch (key) {
      'article' => Icons.article_outlined,
      'payments' => Icons.payments_outlined,
      'school' => Icons.school_outlined,
      'groups' => Icons.groups_outlined,
      'biotech' => Icons.biotech_outlined,
      'calculate' => Icons.calculate_outlined,
      'public' => Icons.public,
      'menu_book' => Icons.menu_book_outlined,
      'lightbulb' => Icons.lightbulb_outline,
      'rocket' => Icons.rocket_launch_outlined,
      'flag' => Icons.flag_outlined,
      _ => Icons.science_outlined,
    };

Color boardColor(int i) =>
    Color(boardColors[i.clamp(0, boardColors.length - 1)]);

/// Цвет приоритета.
Color priorityColor(int p) => switch (p) {
      3 => const Color(0xFFDC2626),
      2 => const Color(0xFFF97316),
      1 => const Color(0xFF3B82F6),
      _ => const Color(0xFF64748B),
    };

String priorityLabel(int p) => t('bd.p.${p.clamp(0, 3)}');

String roleLabel(BoardRole r) => t('bd.role.${r.name}');

/// Понятная ошибка досок.
String boardError(Object e) =>
    t('bd.err.${e is BoardException ? e.kind : BoardException.from(e).kind}');

/// Запускает запись, не дожидаясь сервера (Firestore сохранит её офлайн),
/// и показывает ошибку, если она всё-таки случится.
void fireAndReport(BuildContext context, Future<void> f) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  unawaited(f.catchError((Object e) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(boardError(e))));
  }));
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Подпись срока: «Сегодня», «Завтра», «Через 3 дн.», «Просрочено на 2 дн.».
String dueLabel(DateTime due, DateTime now) {
  DateTime d(DateTime x) => DateTime(x.year, x.month, x.day);
  final n = d(due.toLocal()).difference(d(now.toLocal())).inDays;
  if (n < 0) return t('bd.due.overdue', {'n': -n});
  if (n == 0) return t('bd.due.today');
  if (n == 1) return t('bd.due.tomorrow');
  return t('bd.due.in', {'n': n});
}

/// Плашка срока с цветом срочности (как в «Грантах»).
class DueChip extends StatelessWidget {
  const DueChip({super.key, required this.due, this.done = false});
  final DateTime due;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final s = dueState(due, now, done: done);
    final u = switch (s) {
      DueState.overdue || DueState.today => Urgency.urgent,
      DueState.week => Urgency.soon,
      DueState.done => Urgency.none,
      _ => Urgency.normal,
    };
    final (bg, fg) = urgencyColors(context, u);
    return Pill(
      text: done ? t('bt.col.done') : dueLabel(due, now),
      bg: bg,
      fg: fg,
      icon: done ? Icons.check_circle_outline : Icons.event,
    );
  }
}

/// Имена участников по uid (из опубликованных профилей, с кэшем).
class MemberNames {
  MemberNames._();
  static Future<UserProfile?> Function(String uid) lookup =
      (uid) => ChatService.instance.profileOf(uid);
}

class MemberName extends StatelessWidget {
  const MemberName(this.uid, {super.key, this.style, this.prefix = ''});
  final String uid;
  final TextStyle? style;
  final String prefix;

  @override
  Widget build(BuildContext context) => FutureBuilder<UserProfile?>(
        future: MemberNames.lookup(uid),
        builder: (_, s) => Text(
          '$prefix${s.data?.name.isNotEmpty == true ? s.data!.name : t('bd.unknown_user')}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      );
}

class MemberAvatar extends StatelessWidget {
  const MemberAvatar(this.uid, {super.key, this.radius = 14});
  final String uid;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<UserProfile?>(
      future: MemberNames.lookup(uid),
      builder: (_, s) => CircleAvatar(
        radius: radius,
        backgroundColor: scheme.primaryContainer,
        child: Text(
          initials(s.data?.name ?? '?'),
          style: TextStyle(
            fontSize: radius * 0.7,
            fontWeight: FontWeight.w800,
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

/// Цветная метка доски.
class LabelChip extends StatelessWidget {
  const LabelChip(this.label, {super.key});
  final BoardLabel label;

  @override
  Widget build(BuildContext context) {
    final c = boardColor(label.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withAlpha(40),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withAlpha(140)),
      ),
      child: Text(
        label.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }
}

/// Компактная карточка задачи (на доске и в «Моих задачах»).
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.board,
    required this.card,
    this.onTap,
    this.onNext,
    this.showBoard = false,
  });
  final Board board;
  final TaskCard card;
  final VoidCallback? onTap;

  /// Кнопка «в следующую колонку» (null — не показывать).
  final VoidCallback? onNext;
  final bool showBoard;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = card;
    final done = board.isDoneColumn(c.column);
    final labels = [
      for (final id in c.labels)
        if (board.label(id) != null) board.label(id)!,
    ];
    final muted = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: priorityColor(c.priority), width: 4),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showBoard)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(boardIcon(board.icon),
                          size: 14, color: boardColor(board.color)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(board.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: muted.copyWith(
                                color: boardColor(board.color),
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              if (labels.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, right: 8),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [for (final l in labels) LabelChip(l)],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        c.title,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done ? scheme.onSurfaceVariant : null,
                        ),
                      ),
                    ),
                  ),
                  if (onNext != null)
                    IconButton(
                      tooltip: board.nextColumn(c.column) == null
                          ? null
                          : t('bd.swipe_next',
                              {'col': board.nextColumn(c.column)!.name}),
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: onNext,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (c.due != null) DueChip(due: c.due!, done: done),
                  if (c.checklist.isNotEmpty)
                    _Mini(
                      icon: Icons.checklist,
                      text: '${c.checkDone}/${c.checklist.length}',
                      color: c.checkDone == c.checklist.length
                          ? const Color(0xFF16A34A)
                          : scheme.onSurfaceVariant,
                    ),
                  if (c.papers.isNotEmpty)
                    _Mini(
                        icon: Icons.article_outlined,
                        text: '${c.papers.length}',
                        color: scheme.onSurfaceVariant),
                  if (c.grants.isNotEmpty)
                    _Mini(
                        icon: Icons.payments_outlined,
                        text: '${c.grants.length}',
                        color: scheme.onSurfaceVariant),
                  for (final a in c.assignees.take(3))
                    MemberAvatar(a, radius: 11),
                  if (c.assignees.length > 3)
                    Text('+${c.assignees.length - 3}', style: muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 2),
          Text(text,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      );
}

/// Простое окно ввода текста.
Future<String?> askText(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
  int maxLength = 80,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
          title: title, initial: initial, hint: hint, maxLength: maxLength),
    );

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.maxLength,
  });
  final String title;
  final String initial;
  final String hint;
  final int maxLength;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _ok() {
    final v = _c.text.trim();
    if (v.isEmpty) return;
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _c,
          autofocus: true,
          maxLength: widget.maxLength,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => _ok(),
          decoration: InputDecoration(
            hintText: widget.hint,
            border: const OutlineInputBorder(),
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

/// Подтверждение опасного действия.
Future<bool> confirmDanger(BuildContext context,
    {required String title, required String text, String? action}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: Text(text),
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
          child: Text(action ?? t('bd.delete_do')),
        ),
      ],
    ),
  );
  return ok == true;
}
