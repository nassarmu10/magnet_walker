import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class LaserBeam extends Component {
  final Vector2 startPosition;
  final Vector2 endPosition;
  double lifetime = 0.0;
  final double maxLifetime = 0.3; // Laser lasts 0.3 seconds

  LaserBeam({
    required this.startPosition,
    required this.endPosition,
  });

  @override
  void update(double dt) {
    super.update(dt);
    lifetime += dt;

    if (lifetime >= maxLifetime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Calculate opacity based on lifetime (fade out)
    final fadeProgress = lifetime / maxLifetime;
    final opacity = (1.0 - fadeProgress).clamp(0.0, 1.0);

    // Draw outer glow
    final glowPaint = Paint()
      ..color = Colors.red.withOpacity(opacity * 0.3)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawLine(
      startPosition.toOffset(),
      endPosition.toOffset(),
      glowPaint,
    );

    // Draw middle beam
    final beamPaint = Paint()
      ..color = Colors.redAccent.withOpacity(opacity * 0.7)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      startPosition.toOffset(),
      endPosition.toOffset(),
      beamPaint,
    );

    // Draw bright core
    final corePaint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      startPosition.toOffset(),
      endPosition.toOffset(),
      corePaint,
    );

    // Add spark effect at the end (impact point)
    final sparkRadius = 8.0 * (1.0 - fadeProgress);
    final sparkPaint = Paint()
      ..color = Colors.orange.withOpacity(opacity * 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawCircle(endPosition.toOffset(), sparkRadius, sparkPaint);

    // Add bright spark center
    final sparkCenterPaint = Paint()
      ..color = Colors.white.withOpacity(opacity);

    canvas.drawCircle(endPosition.toOffset(), sparkRadius * 0.4, sparkCenterPaint);
  }
}
