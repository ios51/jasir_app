import 'dart:math' as math;
import 'package:flutter/material.dart';

/// مؤشّر انتظار جاسر — شمس ذهبية أشعتها تظهر وتتلاشى بالتتابع أثناء الدوران.
class JasirSpinner extends StatefulWidget {
  final double size;
  const JasirSpinner({super.key, this.size = 44});

  @override
  State<JasirSpinner> createState() => _JasirSpinnerState();
}

class _JasirSpinnerState extends State<JasirSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) =>
            CustomPaint(painter: _SunPainter(_c.value)),
      ),
    );
  }
}

class _SunPainter extends CustomPainter {
  final double t; // 0..1
  _SunPainter(this.t);

  static const Color gold = Color(0xFFFBBF24);
  static const int rays = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    // القرص
    canvas.drawCircle(center, r * 0.28, Paint()..color = gold);
    final p = Paint()
      ..color = gold
      ..strokeWidth = r * 0.13
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < rays; i++) {
      final a = (i / rays) * 2 * math.pi;
      // شدّة كل شعاع تتبع موضع الدوران (تظهر وتتلاشى)
      final phase = (i / rays - t) % 1.0;
      final opacity = 0.15 + 0.85 * (1 - phase);
      p.color = gold.withOpacity(opacity.clamp(0.12, 1.0));
      final inner = Offset(
        center.dx + math.cos(a) * r * 0.46,
        center.dy + math.sin(a) * r * 0.46,
      );
      final outer = Offset(
        center.dx + math.cos(a) * r * 0.78,
        center.dy + math.sin(a) * r * 0.78,
      );
      canvas.drawLine(inner, outer, p);
    }
  }

  @override
  bool shouldRepaint(covariant _SunPainter old) => old.t != t;
}
