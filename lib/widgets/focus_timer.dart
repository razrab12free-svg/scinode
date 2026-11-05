import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/board.dart';
import '../services/board_service.dart';
import '../services/motivation_service.dart';
import '../strings.dart';
import 'board_widgets.dart';

const focusWork = Duration(minutes: 25);
const focusBreak = Duration(minutes: 5);

/// Меньше минуты работы не записываем.
const minFocusSeconds = 60;

/// «1 ч 25 мин», «25 мин», «0 мин».
String focusLabel(int seconds) {
  final m = (seconds / 60).floor();
  final h = m ~/ 60;
  if (h == 0) return t('fo.min', {'m': m});
  return t('fo.hmin', {'h': h, 'm': m % 60});
}

/// Таймер фокуса 25/5 для карточки. Время работы прибавляется к карточке.
Future<void> showFocusTimer(BuildContext context,
    {required BoardService service,
    required String boardId,
    required TaskCard card}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    isDismissible: false,
    builder: (_) =>
        FocusTimerSheet(service: service, boardId: boardId, card: card),
  );
}

/// Чистая логика таймера (для тестов): фаза и остаток по реальному времени,
/// чтобы таймер не сбивался, если телефон засыпал.
class FocusClock {
  FocusClock({this.work = focusWork, this.rest = focusBreak});
  final Duration work;
  final Duration rest;

  bool resting = false;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero; // до последней паузы

  /// Сколько секунд работы ещё не записано.
  int unsaved = 0;

  bool get running => _startedAt != null;
  Duration get phase => resting ? rest : work;

  Duration elapsed(DateTime now) =>
      _elapsed +
      (_startedAt == null ? Duration.zero : now.difference(_startedAt!));

  Duration left(DateTime now) {
    final l = phase - elapsed(now);
    return l.isNegative ? Duration.zero : l;
  }

  double progress(DateTime now) =>
      (elapsed(now).inMilliseconds / phase.inMilliseconds).clamp(0.0, 1.0);

  void start(DateTime now) => _startedAt ??= now;

  void pause(DateTime now) {
    if (_startedAt == null) return;
    final e = elapsed(now);
    if (!resting) unsaved += (e - _elapsed).inSeconds;
    _elapsed = e;
    _startedAt = null;
  }

  /// Проверяет конец фазы. Возвращает true, если фаза сменилась.
  bool tick(DateTime now) {
    if (_startedAt == null || elapsed(now) < phase) return false;
    if (!resting) unsaved += (phase - _elapsed).inSeconds;
    resting = !resting;
    _elapsed = Duration.zero;
    _startedAt = now;
    return true;
  }

  /// Незаписанное время работы с учётом идущей фазы, секунды.
  int pending(DateTime now) {
    if (resting || _startedAt == null) return unsaved;
    final e = elapsed(now);
    final cap = e > work ? work : e;
    return unsaved + (cap - _elapsed).inSeconds;
  }

  /// Забирает незаписанное время работы (с учётом идущей фазы).
  int take(DateTime now) {
    if (!resting && _startedAt != null) {
      final e = elapsed(now);
      final cap = e > work ? work : e;
      unsaved += (cap - _elapsed).inSeconds;
      _elapsed = cap;
      _startedAt = now;
    }
    final s = unsaved;
    unsaved = 0;
    return s;
  }
}

class FocusTimerSheet extends StatefulWidget {
  const FocusTimerSheet({
    super.key,
    required this.service,
    required this.boardId,
    required this.card,
  });
  final BoardService service;
  final String boardId;
  final TaskCard card;

  @override
  State<FocusTimerSheet> createState() => _FocusTimerSheetState();
}

class _FocusTimerSheetState extends State<FocusTimerSheet> {
  final FocusClock _clock = FocusClock();
  Timer? _ticker;
  int _saved = 0;
  ScaffoldMessengerState? _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _flush();
    super.dispose();
  }

  void _start() {
    _clock.start(DateTime.now());
    _ticker ??= Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      if (_clock.tick(DateTime.now())) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        if (_clock.resting) _flush();
      }
      setState(() {});
    });
    setState(() {});
  }

  void _pause() {
    _clock.pause(DateTime.now());
    _ticker?.cancel();
    _ticker = null;
    setState(() {});
  }

  /// Записывает накопленное время работы (если набралась хотя бы минута).
  void _flush() {
    final now = DateTime.now();
    if (_clock.pending(now) < minFocusSeconds) return;
    final s = _clock.take(now);
    if (s <= 0) return;
    _saved += s;
    MotivationService.instance.active();
    final f = widget.service.addFocus(widget.boardId, widget.card.id, s);
    final m = _messenger;
    unawaited(f.catchError((Object e) {
      m
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(boardError(e))));
    }));
  }

  void _stop() {
    _pause();
    _flush();
    Navigator.pop(context);
  }

  String _mmss(Duration d) {
    final s = d.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:'
        '${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final resting = _clock.resting;
    final color = resting ? const Color(0xFF10B981) : scheme.primary;
    final size = min(MediaQuery.of(context).size.width * 0.62, 260.0);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.card.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text(resting ? t('fo.break') : t('fo.work'),
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 20),
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: 1 - _clock.progress(now),
                    strokeWidth: 14,
                    strokeCap: StrokeCap.round,
                    color: color,
                    backgroundColor: color.withAlpha(40),
                  ),
                  Center(
                    child: Text(
                      _mmss(_clock.left(now)),
                      style: TextStyle(
                        fontSize: size * 0.22,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t('fo.saved', {'t': focusLabel(_saved + _clock.pending(now))}),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54)),
                    onPressed: _stop,
                    icon: const Icon(Icons.stop),
                    label: Text(t('fo.stop')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _clock.running ? _pause : _start,
                    icon: Icon(_clock.running ? Icons.pause : Icons.play_arrow),
                    label:
                        Text(_clock.running ? t('fo.pause') : t('fo.resume')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
