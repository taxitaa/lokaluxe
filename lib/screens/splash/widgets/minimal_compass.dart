import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class MinimalCompassWidget extends StatelessWidget {
  final double size;
  final double rotationAngle;

  const MinimalCompassWidget({
    super.key,
    this.size = 100,
    this.rotationAngle = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer subtle ring
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.goldAccent.withValues(alpha: 0.35),
                width: 1.5,
              ),
              color: AppColors.pureWhite.withValues(alpha: 0.6),
              boxShadow: [
                BoxShadow(
                  color: AppColors.charcoalDark.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),

          // Custom Painted Compass Dial & Needle
          Transform.rotate(
            angle: rotationAngle,
            child: CustomPaint(
              size: Size(size, size),
              painter: _CompassPainter(),
            ),
          ),

          // Center Monogram / Dot
          Container(
            width: size * 0.38,
            height: size * 0.38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.warmCream,
              border: Border.all(
                color: AppColors.goldAccent,
                width: 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'L',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: size * 0.22,
                fontWeight: FontWeight.bold,
                color: AppColors.charcoalDark,
                letterSpacing: -1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final tickPaint = Paint()
      ..color = AppColors.charcoalDark.withValues(alpha: 0.35)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final goldPaint = Paint()
      ..color = AppColors.goldAccent
      ..style = PaintingStyle.fill;

    // Draw 8 cardinal tick marks
    for (int i = 0; i < 8; i++) {
      final angle = i * (math.pi / 4);
      final isMajor = i % 2 == 0;
      final tickLength = isMajor ? radius * 0.16 : radius * 0.09;
      final startRadius = radius * 0.88;

      final startPoint = Offset(
        center.dx + startRadius * math.cos(angle),
        center.dy + startRadius * math.sin(angle),
      );
      final endPoint = Offset(
        center.dx + (startRadius - tickLength) * math.cos(angle),
        center.dy + (startRadius - tickLength) * math.sin(angle),
      );

      if (i == 6) { // North (top)
        final path = Path();
        path.moveTo(center.dx, center.dy - radius * 0.88);
        path.lineTo(center.dx - 4, center.dy - radius * 0.70);
        path.lineTo(center.dx + 4, center.dy - radius * 0.70);
        path.close();
        canvas.drawPath(path, goldPaint);
      } else {
        canvas.drawLine(startPoint, endPoint, tickPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
