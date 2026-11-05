import 'package:flutter/material.dart';

import '../models/board.dart';
import '../services/board_service.dart';
import '../services/motivation_service.dart';
import '../strings.dart';
import '../widgets/board_widgets.dart';
import 'card_sheet.dart';

/// «Мои задачи»: задачи из всех досок, сгруппированные по срокам.
class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key, this.service});
  final BoardService? service;

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  late final BoardService _svc = widget.service ?? BoardService.instance;
  late final Stream<List<MyTask>>? _tasks =
      _svc.available ? _svc.myTasks() : null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t('bd.my_tasks'))),
      body: _tasks == null
          ? Center(child: Text(t('bd.not_ready')))
          : StreamBuilder<List<MyTask>>(
              stream: _tasks,
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(child: Text(t('bd.err.load')));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final groups = groupMyTasks(snap.data!, DateTime.now());
                final any = groups.values.any((l) => l.isNotEmpty);
                if (!any) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.task_alt, size: 64, color: scheme.primary),
                          const SizedBox(height: 12),
                          Text(t('bd.my_empty'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 15)),
                        ],
                      ),
                    ),
                  );
                }
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                      16, 4, 16, 24 + MediaQuery.of(ctx).viewPadding.bottom),
                  children: [
                    for (final g in TaskGroup.values)
                      if (groups[g]!.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                          child: Row(
                            children: [
                              Text(t('bd.g.${g.name}'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: g == TaskGroup.overdue
                                        ? scheme.error
                                        : null,
                                  )),
                              const SizedBox(width: 8),
                              Text('${groups[g]!.length}',
                                  style: TextStyle(
                                      color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        for (final task in groups[g]!)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TaskTile(
                              board: task.board,
                              card: task.card,
                              showBoard: true,
                              onTap: () => showCardSheet(
                                  context, task.board.id, task.card.id,
                                  service: _svc),
                            ),
                          ),
                      ],
                  ],
                );
              },
            ),
    );
  }
}

/// Плашка «Мои задачи на сегодня» для Главной.
class TodayBanner extends StatefulWidget {
  const TodayBanner({super.key, this.service});
  final BoardService? service;

  @override
  State<TodayBanner> createState() => _TodayBannerState();
}

class _TodayBannerState extends State<TodayBanner> {
  late final BoardService _svc = widget.service ?? BoardService.instance;
  late final Stream<List<MyTask>>? _tasks =
      _svc.available ? _svc.myTasks() : null;

  @override
  void initState() {
    super.initState();
    MotivationService.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final s = _tasks;
    if (s == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<MyTask>>(
      stream: s,
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
        final g = groupMyTasks(snap.data!, DateTime.now());
        final today = g[TaskGroup.today]!.length;
        final overdue = g[TaskGroup.overdue]!.length;
        final urgent = overdue > 0;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Material(
            color: urgent ? scheme.errorContainer : scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => MyTasksScreen(service: _svc))),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    child: Row(
                      children: [
                        Icon(
                            urgent
                                ? Icons.warning_amber_rounded
                                : Icons.task_alt,
                            color: urgent
                                ? scheme.onErrorContainer
                                : scheme.onSecondaryContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t('bd.my_tasks'),
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800)),
                              Text(
                                today == 0 && overdue == 0
                                    ? t('bd.today_none')
                                    : t('bd.today_banner',
                                        {'t': today, 'o': overdue}),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
                const MotivationRow(),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Серия дней и кольцо недельной цели (нажатие на кольцо — изменить цель).
class MotivationRow extends StatelessWidget {
  const MotivationRow({super.key});

  Future<void> _editGoal(BuildContext context) async {
    final m = MotivationService.instance;
    var v = m.goal.toDouble();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text(t('mo.goal_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('mo.goal_text')),
              const SizedBox(height: 12),
              Center(
                child: Text(t('mo.goal_n', {'n': v.round()}),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              Slider(
                value: v,
                min: MotivationState.minGoal.toDouble(),
                max: MotivationState.maxGoal.toDouble(),
                divisions: MotivationState.maxGoal - MotivationState.minGoal,
                label: '${v.round()}',
                onChanged: (x) => set(() => v = x),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: Text(t('bd.cancel'))),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
              onPressed: () => Navigator.pop(d, true),
              child: Text(t('bd.ok')),
            ),
          ],
        ),
      ),
    );
    if (ok == true) await m.setGoal(v.round());
  }

  @override
  Widget build(BuildContext context) {
    final m = MotivationService.instance;
    return ListenableBuilder(
      listenable: m,
      builder: (ctx, _) {
        final streak = m.streak;
        final done = m.doneThisWeek;
        final goal = m.goal;
        final reached = done >= goal;
        const green = Color(0xFF16A34A);
        return InkWell(
          onTap: () => _editGoal(ctx),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: (done / goal).clamp(0.0, 1.0)),
                        duration: const Duration(milliseconds: 600),
                        builder: (_, v, __) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 5,
                          strokeCap: StrokeCap.round,
                          color: reached ? green : null,
                          backgroundColor: Colors.black.withAlpha(25),
                        ),
                      ),
                      Center(
                        child: reached
                            ? const Icon(Icons.emoji_events,
                                size: 20, color: green)
                            : Text('$done',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        streak > 0
                            ? t('mo.streak', {'n': streak})
                            : t('mo.streak_start'),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      Text(t('mo.goal', {'d': done, 'n': goal}),
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.edit_outlined, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}
