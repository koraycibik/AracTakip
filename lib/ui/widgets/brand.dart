// Tekerim logosu: beyaz teker + amber ilerleme yayı (uygulamadaki kalan süre halkası).
// Uygulama ikonu dosyalarıyla aynı çizim; 108 birimlik kareye göre ölçeklenir.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

const kAppName = 'Tekerim';

class TekerimMark extends StatelessWidget {
  const TekerimMark({super.key, this.size = 56, this.background = true});
  final double size;

  /// Lacivert yuvarlatılmış kare zemin (koyu zemin üzerinde false verilebilir).
  final bool background;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$kAppName logosu',
      image: true,
      child: CustomPaint(size: Size.square(size), painter: _MarkPainter(background)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.background);
  final bool background;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 108;
    canvas.scale(s);
    if (background) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 108, 108), const Radius.circular(26)),
        Paint()..color = AppColors.navy,
      );
    }
    const c = Offset(54, 54);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..color = Colors.white;
    canvas.drawCircle(c, 29, ring);
    // Amber yay: tepe noktasından saat yönünde ~115°.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: 29),
      -math.pi / 2,
      58 / 29,
      false,
      ring
        ..color = AppColors.accent
        ..strokeCap = StrokeCap.round,
    );
    final spoke = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * 9,
        c + Offset(math.cos(a), math.sin(a)) * 24,
        spoke,
      );
    }
    canvas.drawCircle(c, 9, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) => old.background != background;
}
