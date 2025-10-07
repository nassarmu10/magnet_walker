import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class SciFiPortal extends PositionComponent {
  double time = 0;
  final List<PortalRing> rings = [];
  final math.Random _random = math.Random();

  // Enhanced flash effect properties
  bool isFlashing = false;
  double flashTimer = 0.0;
  static const double flashDuration = 1.2;
  final List<EnergyWave> energyWaves = [];

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

    // Draw central energy core with enhanced spiral
    _renderCore(canvas, center);

    // Enhanced flash effect when spawning
    if (isFlashing) {
      _renderEnhancedFlash(canvas, center);
    }

    // Draw energy waves
    for (final wave in energyWaves) {
      wave.render(canvas, center);
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

    // Enhanced spinning spiral lines in core
    final spiralPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);

    for (int i = 0; i < 4; i++) {
      final startAngle = time * 4 + i * (math.pi / 2);
      final endRadius = coreRadius * pulseScale;

      // Create spiral effect
      final path = Path();
      path.moveTo(center.dx, center.dy);

      for (double t = 0; t <= 1; t += 0.1) {
        final spiralRadius = endRadius * t;
        final spiralAngle = startAngle + t * math.pi * 2;
        path.lineTo(
          center.dx + spiralRadius * math.cos(spiralAngle),
          center.dy + spiralRadius * math.sin(spiralAngle),
        );
      }

      canvas.drawPath(path, spiralPaint);
    }

    // Core gradient with enhanced glow
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, Colors.cyanAccent, Colors.blue.withOpacity(0.8)],
        stops: [0.0, 0.6, 1.0],
      ).createShader(
          Rect.fromCircle(center: center, radius: coreRadius * pulseScale))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawCircle(center, coreRadius * pulseScale, corePaint);
  }

  void _renderEnhancedFlash(Canvas canvas, Offset center) {
    final flashProgress = flashTimer / flashDuration;
    final fadeProgress = 1.0 - flashProgress;

    // Multiple flash layers for depth
    _renderEnergyBurst(canvas, center, flashProgress, fadeProgress);
    _renderLightningBolts(canvas, center, flashProgress, fadeProgress);
    _renderParticleRing(canvas, center, flashProgress, fadeProgress);
  }

  void _renderEnergyBurst(
      Canvas canvas, Offset center, double progress, double fade) {
    // Central energy burst
    final burstSize = size.x * 0.8 * (1 - progress);
    final intensity = math.exp(-progress * 3) * 0.9;

    final burstPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(intensity),
          Colors.cyanAccent.withOpacity(intensity * 0.7),
          Colors.purpleAccent.withOpacity(intensity * 0.4),
          Colors.transparent,
        ],
        stops: [0.0, 0.4, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: burstSize))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(center, burstSize, burstPaint);
  }

  void _renderLightningBolts(
      Canvas canvas, Offset center, double progress, double fade) {
    final boltPaint = Paint()
      ..color = Colors.white.withOpacity(fade * 0.9)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    // Draw jagged lightning bolts radiating outward
    for (int i = 0; i < 8; i++) {
      final baseAngle = (i * math.pi / 4) + (time * 2);
      final boltLength = size.x * 0.6 * (1 - progress);

      final path = Path();
      path.moveTo(center.dx, center.dy);

      // Create jagged lightning path
      Vector2 currentPos = Vector2(center.dx, center.dy);
      final segments = 5;

      for (int j = 1; j <= segments; j++) {
        final segmentProgress = j / segments;
        final targetRadius = boltLength * segmentProgress;

        // Add random jitter for lightning effect
        final jitterAngle = baseAngle + (_random.nextDouble() - 0.5) * 0.5;
        final jitterRadius = targetRadius + (_random.nextDouble() - 0.5) * 10;

        final nextPos = Vector2(
          center.dx + jitterRadius * math.cos(jitterAngle),
          center.dy + jitterRadius * math.sin(jitterAngle),
        );

        path.lineTo(nextPos.x, nextPos.y);
        currentPos = nextPos;
      }

      canvas.drawPath(path, boltPaint);

      // Draw glow for each bolt
      final glowPaint = Paint()
        ..color = Colors.cyanAccent.withOpacity(fade * 0.4)
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawPath(path, glowPaint);
    }
  }

  void _renderParticleRing(
      Canvas canvas, Offset center, double progress, double fade) {
    // Animated particle ring
    final particlePaint = Paint()
      ..color = Colors.white.withOpacity(fade * 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final ringRadius = size.x * 0.4 + (progress * size.x * 0.3);

    for (int i = 0; i < 16; i++) {
      final angle = (i * math.pi / 8) + (time * 5);
      final particleSize = 4.0 * fade * (0.5 + 0.5 * math.sin(time * 8 + i));

      final particlePos = Offset(
        center.dx + ringRadius * math.cos(angle),
        center.dy + ringRadius * math.sin(angle),
      );

      canvas.drawCircle(particlePos, particleSize, particlePaint);

      // Add particle trails
      final trailPaint = Paint()
        ..color = Colors.cyanAccent.withOpacity(fade * 0.3)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final trailStart = Offset(
        center.dx + (ringRadius - 15) * math.cos(angle),
        center.dy + (ringRadius - 15) * math.sin(angle),
      );

      canvas.drawLine(trailStart, particlePos, trailPaint);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    time += dt;

    // Update flash timer
    if (isFlashing) {
      flashTimer += dt;
      if (flashTimer >= flashDuration) {
        isFlashing = false;
        flashTimer = 0;
      }
    }

    // Update energy waves
    energyWaves.removeWhere((wave) => wave.isComplete);
    for (final wave in energyWaves) {
      wave.update(dt);
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
    // Enhanced flash trigger
    isFlashing = true;
    flashTimer = 0.0;

    // Create energy waves
    for (int i = 0; i < 3; i++) {
      energyWaves.add(EnergyWave(
        delay: i * 0.15,
        maxRadius: size.x * (1.2 + i * 0.3),
        duration: 1.0 + i * 0.2,
      ));
    }

    // Create enhanced energy flashes
    final flashCount = _random.nextInt(4) + 6; // 6-9 flashes

    for (int i = 0; i < flashCount; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final distance = _random.nextDouble() * size.x * 0.4;
      final flashPosition = Vector2(
        size.x / 2 + math.cos(angle) * distance,
        size.y / 2 + math.sin(angle) * distance,
      );
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

class EnergyWave {
  double currentRadius = 0;
  double timer = 0;
  final double delay;
  final double maxRadius;
  final double duration;
  bool started = false;
  bool isComplete = false;

  EnergyWave({
    required this.delay,
    required this.maxRadius,
    required this.duration,
  });

  void update(double dt) {
    timer += dt;

    if (!started && timer >= delay) {
      started = true;
    }

    if (started) {
      final progress = (timer - delay) / duration;
      currentRadius = maxRadius * math.min(1.0, progress);

      if (progress >= 1.0) {
        isComplete = true;
      }
    }
  }

  void render(Canvas canvas, Offset center) {
    if (!started || isComplete) return;

    final progress = (timer - delay) / duration;
    final fade = 1.0 - progress;

    final wavePaint = Paint()
      ..color = Colors.red.withOpacity(fade * 0.3) // Reduced opacity
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 // Reduced from 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4); // Reduced blur

    canvas.drawCircle(center, currentRadius, wavePaint);
  }
}
