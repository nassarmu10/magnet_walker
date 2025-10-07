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

    // Calculate beam angle for effects
    final direction = (endPosition - startPosition).normalized();
    final angle = math.atan2(direction.y, direction.x);

    // === MUZZLE FLASH AT START POSITION ===
    // Only show muzzle flash in the first 30% of lifetime
    if (fadeProgress < 0.3) {
      final flashProgress = fadeProgress / 0.3;
      final flashOpacity = (1.0 - flashProgress).clamp(0.0, 1.0);

      // Outer muzzle glow
      final muzzleGlowPaint = Paint()
        ..color = Colors.red.withOpacity(flashOpacity * 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(startPosition.toOffset(),
          15.0 * (1.0 - flashProgress * 0.5), muzzleGlowPaint);

      // Middle muzzle flash
      final muzzleFlashPaint = Paint()
        ..color = Colors.orange.withOpacity(flashOpacity * 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(startPosition.toOffset(),
          8.0 * (1.0 - flashProgress * 0.5), muzzleFlashPaint);

      // Bright muzzle core
      final muzzleCorePaint = Paint()
        ..color = Colors.white.withOpacity(flashOpacity);
      canvas.drawCircle(startPosition.toOffset(),
          4.0 * (1.0 - flashProgress * 0.5), muzzleCorePaint);

      // Forward cone flares (directional muzzle flash)
      canvas.save();
      canvas.translate(startPosition.x, startPosition.y);
      canvas.rotate(angle);

      final conePath = Path()
        ..moveTo(0, 0)
        ..lineTo(20, -8)
        ..lineTo(20, 8)
        ..close();

      final conePaint = Paint()
        ..color = Colors.orange.withOpacity(flashOpacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(conePath, conePaint);

      canvas.restore();
    }

    // === MAIN LASER BEAM ===
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

    // Draw bright core with slight pulse effect
    final pulseEffect = 1.0 + math.sin(lifetime * 50) * 0.15;
    final corePaint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 1.5 * pulseEffect
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      startPosition.toOffset(),
      endPosition.toOffset(),
      corePaint,
    );

    // === IMPACT EFFECT AT END POSITION ===
    // Add impact glow
    final impactGlowRadius = 12.0 * (1.0 - fadeProgress * 0.5);
    final impactGlowPaint = Paint()
      ..color = Colors.orange.withOpacity(opacity * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(
        endPosition.toOffset(), impactGlowRadius, impactGlowPaint);

    // Add spark effect at the end (impact point)
    final sparkRadius = 8.0 * (1.0 - fadeProgress);
    final sparkPaint = Paint()
      ..color = Colors.orange.withOpacity(opacity * 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(endPosition.toOffset(), sparkRadius, sparkPaint);

    // Add bright spark center
    final sparkCenterPaint = Paint()..color = Colors.white.withOpacity(opacity);
    canvas.drawCircle(
        endPosition.toOffset(), sparkRadius * 0.4, sparkCenterPaint);

    // Add random spark particles around impact
    if (fadeProgress < 0.5) {
      final random = math.Random(endPosition.x.toInt() + endPosition.y.toInt());
      for (int i = 0; i < 6; i++) {
        final sparkAngle =
            (angle + math.pi) + (random.nextDouble() - 0.5) * math.pi * 0.8;
        final sparkDistance = 10.0 + random.nextDouble() * 15.0;
        final sparkPos = endPosition +
            Vector2(
              math.cos(sparkAngle) * sparkDistance * fadeProgress * 2,
              math.sin(sparkAngle) * sparkDistance * fadeProgress * 2,
            );

        final particlePaint = Paint()
          ..color =
              Colors.yellow.withOpacity(opacity * (1.0 - fadeProgress * 2));
        canvas.drawCircle(sparkPos.toOffset(), 1.5, particlePaint);
      }
    }
  }
}
