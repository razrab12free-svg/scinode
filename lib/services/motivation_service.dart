import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth_service.dart';
import '../models/board_report.dart' show dayOf;

/// Серия рабочих дней и недельная цель (на телефоне, отдельно для аккаунта).
///
/// Серия — сколько дней подряд вы двигали задачи (перенос, чек-лист,
/// фокус, новая задача). Цель — сколько задач перенести в «Готово» за
/// неделю (с понедельника).
class MotivationState {
  MotivationState({Set<String>? days, Map<String, String>? done, this.goal = 5})
      : days = days ?? <String>{},
        done = done ?? <String, String>{};

  /// Дни с активностью, `yyyy-mm-dd`.
  final Set<String> days;

  /// Выполненные задачи: `доска/карточка` → день выполнения (без повторов).
  final Map<String, String> done;
  int goal;

  static const minGoal = 1;
  static const maxGoal = 50;
  static const defaultGoal = 5;

  static String key(DateTime d) {
    final l = dayOf(d);
    String two(int x) => x.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)}';
  }

  /// Понедельник текущей недели.
  static DateTime weekStart(DateTime now) {
    final d = dayOf(now);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  /// Отмечает активность сегодня. Возвращает true, если день новый.
  bool markActive(DateTime now) => days.add(key(now));

  /// Отмечает выполнение задачи. Возвращает true, если она ещё не была
  /// засчитана на этой неделе.
  bool markDone(String id, DateTime now) {
    markActive(now);
    final prev = done[id];
    if (prev != null && !_parse(prev).isBefore(weekStart(now))) return false;
    done[id] = key(now);
    return true;
  }

  /// Серия: дни подряд до сегодня. Если сегодня ещё ничего не было,
  /// серия со вчерашнего дня не сгорает.
  int streak(DateTime now) {
    var d = dayOf(now);
    if (!days.contains(key(d))) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (days.contains(key(d))) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  bool activeToday(DateTime now) => days.contains(key(now));

  /// Выполнено на этой неделе.
  int doneThisWeek(DateTime now) {
    final from = weekStart(now);
    return done.values.where((v) => !_parse(v).isBefore(from)).length;
  }

  /// Удаляет старые записи (дни старше 400 дней, выполненное — старше
  /// двух недель).
  void prune(DateTime now) {
    final d = dayOf(now);
    final daysFrom = d.subtract(const Duration(days: 400));
    final doneFrom = weekStart(now).subtract(const Duration(days: 7));
    days.removeWhere((k) => _parse(k).isBefore(daysFrom));
    done.removeWhere((_, v) => _parse(v).isBefore(doneFrom));
  }

  static DateTime _parse(String k) {
    final p = k.split('-');
    if (p.length != 3) return DateTime(1970);
    return DateTime(int.tryParse(p[0]) ?? 1970, int.tryParse(p[1]) ?? 1,
        int.tryParse(p[2]) ?? 1);
  }

  Map<String, dynamic> toJson() =>
      {'d': days.toList()..sort(), 'x': done, 'g': goal};

  factory MotivationState.fromJson(dynamic m) {
    if (m is! Map) return MotivationState();
    final g = m['g'];
    final x = m['x'];
    return MotivationState(
      days: {for (final v in (m['d'] as List? ?? const [])) '$v'},
      done: {
        if (x is Map)
          for (final e in x.entries) '${e.key}': '${e.value}',
      },
      goal: g is num
          ? g.toInt().clamp(minGoal, maxGoal)
          : MotivationState.defaultGoal,
    );
  }
}

/// Итог события: что показать пользователю.
class MotivationEvent {
  const MotivationEvent({this.newDay = false, this.goalReached = false});
  final bool newDay;

  /// Именно этим событием достигнута недельная цель.
  final bool goalReached;
}

class MotivationService extends ChangeNotifier {
  MotivationService._();
  static MotivationService instance = MotivationService._();

  /// Для тестов.
  @visibleForTesting
  factory MotivationService.test() => MotivationService._();

  MotivationState _s = MotivationState();
  String _loadedFor = '';

  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  String get _key => 'motivation_${AuthService.instance.user?.uid ?? 'local'}';

  int get streak => _s.streak(clock());
  bool get activeToday => _s.activeToday(clock());
  int get goal => _s.goal;
  int get doneThisWeek => _s.doneThisWeek(clock());

  Future<void> ensureLoaded() async {
    final k = _key;
    if (_loadedFor == k) return;
    _loadedFor = k;
    _s = MotivationState();
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(k);
      if (raw != null) _s = MotivationState.fromJson(jsonDecode(raw));
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    _s.prune(clock());
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _loadedFor.isEmpty ? _key : _loadedFor, jsonEncode(_s.toJson()));
    } catch (_) {}
  }

  /// Любое движение задач (перенос, чек-лист, фокус, новая задача).
  MotivationEvent active() {
    final n = _s.markActive(clock());
    if (n) _save();
    return MotivationEvent(newDay: n);
  }

  /// Задача перенесена в «Готово».
  MotivationEvent taskDone(String boardId, String cardId) {
    final now = clock();
    final newDay = !_s.activeToday(now);
    final before = _s.doneThisWeek(now);
    final counted = _s.markDone('$boardId/$cardId', now);
    _save();
    final after = _s.doneThisWeek(now);
    return MotivationEvent(
      newDay: newDay,
      goalReached: counted && before < _s.goal && after >= _s.goal,
    );
  }

  Future<void> setGoal(int g) async {
    _s.goal = g.clamp(MotivationState.minGoal, MotivationState.maxGoal);
    await _save();
  }
}
