import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class SciFiPortal extends PositionComponent {
  double time = 0;
  final List<PortalRing> rings = [];
  final math.Random _random = math.Random();
  
  // Simple flash effect properties
  bool isFlashing = false;
  double flashTimer = 0.0;
  static const double flashDuration = 0.5;

  SciFiPortal({
    required Vector2 position,
    double size = 60,
    int ringCount = 5,
  }) : super(
          position: position,
          size: Vector2(size, size),
          anchor: Anchor.center,
        ) {
    // Create multiple rings with different properties
    for (int i = 0; i < ringCount; i++) {
      rings.add(PortalRing(
        radius: size * 0.8 * (1 - i * 0.1),
        speed: 2.0 + i * 0.5,
        phase: i * 0.7,
        color: i.isEven ? Colors.cyanAccent : Colors.purpleAccent,
        pulseRange: 0.2 + i * 0.05,
      ));
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final center = Offset(size.x / 2, size.y / 2);

    // Draw a glowing background
    final backgroundPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.blue.withOpacity(0.2), Colors.transparent],
        stops: [0.0, 0.7],
      ).createShader(Rect.fromCircle(center: center, radius: size.x / 2))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawCircle(center, size.x / 2, backgroundPaint);

    // Draw all rings
    for (final ring in rings) {
      ring.render(canvas, center, time);
    }

    // Draw central energy core with simple spiral
    _renderCore(canvas, center);

    // Simple flash effect when spawning
    if (isFlashing) {
      _renderFlash(canvas, center);
    }

    // Draw outer glow
    final outerGlowPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 15);

    canvas.drawCircle(center, size.x / 2, outerGlowPaint);
  }

  void _renderCore(Canvas canvas, Offset center) {
    final coreRadius = size.x * 0.15;
    final pulseScale = 0.9 + 0.1 * math.sin(time * 5);
    
    // Simple spinning spiral lines in core
    final spiralPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    for (int i = 0; i < 2; i++) {
      final startAngle = time * 3 + i * math.pi;
      final endRadius = coreRadius * pulseScale;
      
      canvas.drawLine(
        center,
        Offset(
          center.dx + endRadius * math.cos(startAngle),
          center.dy + endRadius * math.sin(startAngle),
        ),
        spiralPaint,
      );
    }
    
    // Core gradient
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, Colors.cyanAccent, Colors.blue],
        stops: [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius * pulseScale))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.drawCircle(center, coreRadius * pulseScale, corePaint);
  }

  void _renderFlash(Canvas canvas, Offset center) {
    final flashProgress = 1.0 - (flashTimer / flashDuration);
    final flashIntensity = math.sin(flashProgress * math.pi) * 0.8;
    
    // Simple bright flash
    final flashPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(flashIntensity),
          Colors.cyanAccent.withOpacity(flashIntensity * 0.7),
          Colors.transparent,
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size.x * 0.6))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(center, size.x * 0.4, flashPaint);
    
    // Add a few simple energy sparks
    _renderSparks(canvas, center, flashIntensity);
  }

  void _renderSparks(Canvas canvas, Offset center, double intensity) {
    final sparkPaint = Paint()
      ..color = Colors.white.withOpacity(intensity)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (int i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2) + time * 8;
      final length = size.x * 0.25 * intensity;
      
      canvas.drawLine(
        center,
        Offset(
          center.dx + length * math.cos(angle),
          center.dy + length * math.sin(angle),
        ),
        sparkPaint,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    time += dt;
    
    // Update flash timer
    if (isFlashing) {
      flashTimer -= dt;
      if (flashTimer <= 0) {
        isFlashing = false;
      }
    }
  }

  void removeCompletely() {
    if (!isMounted) return;

    // Remove all child components
    for (final child in children.toList()) {
      child.removeFromParent();
    }

    // Remove this portal from its parent
    removeFromParent();
  }

  @override
  void onRemove() {
    removeCompletely();
    super.onRemove();
  }

  void spawnFlash() {
    // Simple flash trigger
    isFlashing = true;
    flashTimer = flashDuration;
    
    final flashCount = _random.nextInt(3) + 2; // 2-4 flashes

    for (int i = 0; i < flashCount; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final distance = _random.nextDouble() * size.x * 0.3;
      final flashPosition = Vector2(
        size.x / 2 + math.cos(angle) * distance,
        size.y / 2 + math.sin(angle) * distance,
      );

      final flash = EnergyFlash(
        position: flashPosition,
        angle: angle,
        size: Vector2(15, 4 + _random.nextDouble() * 8),
        color: _random.nextBool() ? Colors.cyanAccent : Colors.purpleAccent,
      );

      add(flash);

      // Random delay for each flash
      Future.delayed(Duration(milliseconds: _random.nextInt(100)), () {
        if (flash.isMounted) {
          flash.activate();
        }
      });
    }
  }
}

class PortalRing {
  final double radius;
  final double speed;
  final double phase;
  final Color color;
  final double pulseRange;

  PortalRing({
    required this.radius,
    required this.speed,
    required this.phase,
    required this.color,
    required this.pulseRange,
  });

  void render(Canvas canvas, Offset center, double time) {
    final scale = 1.0 + pulseRange * math.sin(time * speed + phase);
    final alpha = (150 + 100 * math.sin(time * speed * 1.5 + phase))
        .toInt()
        .clamp(0, 255);

    final paint = Paint()
      ..color = color.withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawCircle(center, radius * scale, paint);

    // Draw additional inner line for more detail
    final innerPaint = Paint()
      ..color = Colors.white.withAlpha((alpha * 0.5).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius * scale * 0.9, innerPaint);
  }
}

class EnergyFlash extends PositionComponent with HasPaint {
  final Color color;
  final double angle;
  bool activated = false;
  double opacity = 1.0;

  EnergyFlash({
    required Vector2 position,
    required this.angle,
    required Vector2 size,
    required this.color,
  }) : super(
          position: position,
          size: size,
          anchor: Anchor.center,
        ) {
    paint.color = color;
  }

  void activate() {
    if (activated) return;
    activated = true;

    // Scale effect
    add(ScaleEffect.by(
      Vector2(3.0, 1.0),
      EffectController(
        duration: 0.3,
        curve: Curves.easeOut,
      ),
    ));

    // Fade effect
    add(
      OpacityEffect.to(
        0,
        EffectController(duration: 0.3),
      )..onComplete = () {
          removeFromParent();
        },
    );

    // Rotation effect
    add(RotateEffect.by(
      math.pi / 4 * (math.sin(angle) > 0 ? 1 : -1),
      EffectController(duration: 0.3),
    ));
  }

  @override
  void render(Canvas canvas) {
    if (!activated) return;

    // Draw main flash
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
        const Radius.circular(8),
      ),
      paint,
    );

    // Draw glow effect
    final glowPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
        const Radius.circular(2),
      ),
      glowPaint,
    );
  }
}
