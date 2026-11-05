import 'package:flutter/material.dart';

/// Логотип: сеть узлов (учёные и университеты).
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  static const _pts = [
    Offset(512, 512),
    Offset(330, 380),
    Offset(700, 340),
    Offset(690, 690),
    Offset(350, 690),
  ];
  static const _rad = [100.0, 62.0, 56.0, 66.0, 52.0];
  static const _cols = [
    Color(0xFFFFFFFF),
    Color(0xFF22D3EE),
    Color(0xFFA78BFA),
    Color(0xFF34D399),
    Color(0xFFFBBF24),
  ];
  static const _edges = [
    (0, 1),
    (0, 2),
    (0, 3),
    (0, 4),
    (1, 2),
    (2, 3),
    (3, 4),
    (4, 1),
  ];

  @override
  void paint(Canvas canvas, Size s) {
    final k = s.width / 1024;
    for (final e in _edges) {
      final main = e.$1 == 0;
      final p = Paint()
        ..color = Colors.white.withAlpha(main ? 200 : 110)
        ..strokeWidth = (main ? 16 : 10) * k
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(_pts[e.$1] * k, _pts[e.$2] * k, p);
    }
    for (var i = 0; i < _pts.length; i++) {
      canvas.drawCircle(_pts[i] * k, _rad[i] * k, Paint()..color = _cols[i]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
