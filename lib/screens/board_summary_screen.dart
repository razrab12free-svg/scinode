import 'dart:math';

import 'package:flutter/material.dart';

import '../models/board.dart';
import '../models/board_report.dart';
import '../services/board_service.dart';
import '../strings.dart';
import '../widgets/board_widgets.dart';
import '../widgets/focus_timer.dart' show focusLabel;
import 'board_report_sheet.dart';
import 'card_sheet.dart';

const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);
const _blue = Color(0xFF3B82F6);

/// Сводка доски: прогресс, колонки, нагрузка участников, недели, просроченные.
class BoardSummaryScreen extends StatefulWidget {
  const BoardSummaryScreen({super.key, required this.boardId, this.service});
  final String boardId;
  final BoardService? service;

  @override
  State<BoardSummaryScreen> createState() => _BoardSummaryScreenState();
}

class _BoardSummaryScreenState extends State<BoardSummaryScreen> {
  late final BoardService _svc = widget.service ?? BoardService.instance;
  late final Stream<Board?> _board = _svc.board(widget.boardId);
  late final Stream<List<TaskCard>> _cards = _svc.cards(widget.boardId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Board?>(
      stream: _board,
      builder: (ctx, bs) => StreamBuilder<List<TaskCard>>(
        stream: _cards,
        builder: (ctx, cs) {
          final b = bs.data;
          final all = cs.data;
          Widget body;
          if (bs.hasError || cs.hasError) {
            body = Center(child: Text(t('bd.err.load')));
          } else if (b == null || all == null) {
            body = const Center(child: CircularProgressIndicator());
          } else {
            body = _content(b, all);
          }
          return Scaffold(
            appBar: AppBar(title: Text(t('rp.summary_title'))),
            body: body,
            bottomNavigationBar: b == null || all == null
                ? null
                : SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: FilledButton.icon(
                        onPressed: () => showReportSheet(context, b, all),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(t('rp.make_pdf')),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _content(Board b, List<TaskCard> all) {
    final now = DateTime.now();
    final r =
        BoardReport.of(b, all, ReportRange.of(ReportPeriod.week, now), now);
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant);
    final maxCol = r.columns.fold(0, (a, c) => max(a, c.cards.length));
    final maxOpen = r.members.fold(0, (a, m) => max(a, m.open));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Icon(boardIcon(b.icon), color: boardColor(b.color)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(b.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (r.total == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child:
                Text(t('rp.empty'), textAlign: TextAlign.center, style: muted),
          )
        else ...[
          _Panel(
            child: Row(
              children: [
                _Ring(value: r.done / r.total, percent: r.percent),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('rp.total', {'n': r.total}),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      _Stat(color: _green, label: t('rp.done'), n: r.done),
                      _Stat(color: _blue, label: t('rp.open'), n: r.open),
                      _Stat(color: _red, label: t('rp.overdue'), n: r.overdue),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _Title(t('rp.by_column')),
          _Panel(
            child: Column(
              children: [
                for (final c in r.columns)
                  _Bar(
                    label: c.column.name,
                    value: c.cards.length,
                    max: maxCol,
                    color: c.column.done ? _green : boardColor(b.color),
                    icon: c.column.done ? Icons.check_circle : null,
                  ),
              ],
            ),
          ),
          _Title(t('rp.by_member')),
          _Panel(
            child: Column(
              children: [
                for (final m in r.members)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        if (m.uid.isEmpty)
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: scheme.surfaceContainerHighest,
                            child:
                                const Icon(Icons.person_off_outlined, size: 18),
                          )
                        else
                          MemberAvatar(m.uid, radius: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              m.uid.isEmpty
                                  ? Text(t('bd.f.nobody'),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700))
                                  : MemberName(m.uid,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              _Line(
                                  value: m.open,
                                  max: maxOpen,
                                  color: m.overdue > 0 ? _red : _blue),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  t('rp.member_line',
                                      {'o': m.open, 'd': m.done}),
                                  if (m.focus > 0)
                                    t('rp.focus_line',
                                        {'t': focusLabel(m.focus)}),
                                ].join(' · '),
                                style: muted.copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          _Title(t('rp.weekly')),
          _Panel(child: _Weeks(r.weekly, color: boardColor(b.color))),
          _Title(t('rp.overdue_list')),
          if (r.overdueCards.isEmpty)
            _Panel(
              child: Row(
                children: [
                  const Icon(Icons.celebration_outlined, color: _green),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t('rp.no_overdue'))),
                ],
              ),
            )
          else
            for (final c in r.overdueCards)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TaskTile(
                  board: b,
                  card: c,
                  onTap: () =>
                      showCardSheet(context, b.id, c.id, service: _svc),
                ),
              ),
        ],
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );
}

class _Ring extends StatelessWidget {
  const _Ring({required this.value, required this.percent});
  final double value;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 112,
      height: 112,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: v,
              strokeWidth: 12,
              strokeCap: StrokeCap.round,
              color: v >= 1 ? _green : scheme.primary,
              backgroundColor: scheme.primary.withAlpha(30),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$percent%',
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w800)),
                  Text(t('rp.percent'),
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.color, required this.label, required this.n});
  final Color color;
  final String label;
  final int n;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
            Text('$n',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      );
}

/// Полоска со значением [value] из [max].
class _Line extends StatelessWidget {
  const _Line({required this.value, required this.max, required this.color});
  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final f = max == 0 ? 0.0 : value / max;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: f),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => LinearProgressIndicator(
          value: v,
          minHeight: 10,
          color: color,
          backgroundColor: color.withAlpha(30),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    this.icon,
  });
  final String label;
  final int value;
  final int max;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text('$value',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 4),
            _Line(value: value, max: max, color: color),
          ],
        ),
      );
}

/// Столбики «выполнено по неделям» (последняя — текущая неделя).
class _Weeks extends StatelessWidget {
  const _Weeks(this.weeks, {required this.color});
  final List<int> weeks;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final top = max(1, weeks.fold(0, max));
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < weeks.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${weeks[i]}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: weeks[i] / top),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => Container(
                      width: 36,
                      height: 4 + 80 * v,
                      decoration: BoxDecoration(
                        color: i == weeks.length - 1
                            ? color
                            : color.withAlpha(110),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    i == weeks.length - 1
                        ? t('rp.this_week')
                        : t('rp.weeks_ago', {'n': weeks.length - 1 - i}),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
