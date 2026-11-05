import 'package:flutter/material.dart';

import '../models/board.dart';
import '../services/board_service.dart';
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
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => MyTasksScreen(service: _svc))),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  children: [
                    Icon(urgent ? Icons.warning_amber_rounded : Icons.task_alt,
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
                                  fontSize: 15, fontWeight: FontWeight.w800)),
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
          ),
        );
      },
    );
  }
}
