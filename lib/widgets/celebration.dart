import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/board.dart' show boardColors;
import '../services/motivation_service.dart';
import '../strings.dart';

/// Короткий праздник: конфетти и надпись поверх экрана (около 1,6 с).
/// Если в системе отключены анимации — только надпись внизу.
void celebrate(BuildContext context, String text) {
  HapticFeedback.mediumImpact();
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  if (overlay == null || reduce) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    return;
  }
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Celebration(text: text, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

/// Праздник при переносе задачи в «Готово» (+ серия и недельная цель).
void celebrateDone(BuildContext context, String boardId, String cardId) {
  final ev = MotivationService.instance.taskDone(boardId, cardId);
  final m = MotivationService.instance;
  final text = ev.goalReached
      ? t('mo.goal_reached', {'n': m.goal})
      : (ev.newDay && m.streak > 1
          ? t('mo.done_streak', {'n': m.streak})
          : t('mo.done'));
  celebrate(context, text);
}

class _Celebration extends StatefulWidget {
  const _Celebration({required this.text, required this.onDone});
  final String text;
  final VoidCallback onDone;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward().whenComplete(widget.onDone);
  late final List<_Piece> _pieces = _Piece.burst(Random(), 70);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final v = _c.value;
          // Надпись: появляется, держится, исчезает.
          final o = v < 0.15 ? v / 0.15 : (v > 0.8 ? (1 - v) / 0.2 : 1.0);
          final s = 0.8 + 0.2 * Curves.elasticOut.transform(min(1, v * 2.5));
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _ConfettiPainter(_pieces, v)),
              ),
              Center(
                child: Opacity(
                  opacity: o.clamp(0, 1),
                  child: Transform.scale(
                    scale: s,
                    child: Material(
                      color: scheme.primaryContainer,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 18),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: Text(
                            widget.text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Piece {
  _Piece(this.angle, this.speed, this.spin, this.color, this.size);
  final double angle;
  final double speed;
  final double spin;
  final Color color;
  final double size;

  static List<_Piece> burst(Random r, int n) => [
        for (var i = 0; i < n; i++)
          _Piece(
            -pi / 2 + (r.nextDouble() - 0.5) * pi * 0.9,
            0.6 + r.nextDouble() * 0.7,
            (r.nextDouble() - 0.5) * 12,
            Color(boardColors[r.nextInt(10)]),
            5 + r.nextDouble() * 6,
          ),
      ];
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.62);
    final h = size.height;
    final fade = t > 0.75 ? (1 - t) / 0.25 : 1.0;
    for (final p in pieces) {
      final v = p.speed * h * 0.9;
      final dx = cos(p.angle) * v * t;
      // Взлёт и падение под «гравитацией».
      final dy = sin(p.angle) * v * t + 0.9 * h * t * t;
      final paint = Paint()..color = p.color.withAlpha((255 * fade).round());
      canvas.save();
      canvas.translate(origin.dx + dx, origin.dy + dy);
      canvas.rotate(p.spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.55),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
