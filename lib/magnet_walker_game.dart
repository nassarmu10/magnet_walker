import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async' as async;

import 'components/player.dart';
import 'components/game_object.dart';
import 'components/game_particle.dart';
import 'components/background.dart';
import 'components/game_ui.dart';

class MagnetWalkerGame extends FlameGame 
    with HasCollisionDetection {
  
  late Player player;
  late GameUI gameUI;
  late Background background;
  
  // Game state
  int score = 0;
  int level = 1;
  int levelProgress = 0;
  int targetScore = 10;
  bool gameRunning = true;
  
  // Spawning
  async.Timer? spawnTimer;
  final List<GameObject> gameObjects = [];
  final List<GameParticle> particles = [];

  @override
  Future<void> onLoad() async {
    // Set up camera
    camera.viewfinder.visibleGameSize = Vector2(375, 667);
    
    // Add background
    background = Background();
    add(background);
    
    // Add player
    player = Player(position: Vector2(187.5, 550));
    add(player);
    
    // Add UI
    gameUI = GameUI();
    add(gameUI);
    
    // Start spawning objects
    startSpawning();
  }

  void startSpawning() {
    spawnTimer?.cancel();  // Cancel existing timer if any
    final spawnRate = math.max(2.0 - (level * 0.1), 0.8);
    spawnTimer = async.Timer.periodic(
      Duration(milliseconds: (spawnRate * 1000).round()), 
      (timer) {  // ← The timer parameter here
        if (gameRunning) {
          spawnObject();
        }
      }
    );
  }


  void spawnObject() {
    final x = math.Random().nextDouble() * (size.x - 60) + 30;
    final type = math.Random().nextDouble() < 0.7 ? ObjectType.coin : ObjectType.bomb;
    final obj = GameObject(
      position: Vector2(x, -20),
      type: type,
      level: level,
    );
    add(obj);
    gameObjects.add(obj);
  }

  void collectObject(GameObject obj) {
    if (obj.type == ObjectType.coin) {
      score += 10;
      levelProgress++;
      createParticles(obj.position, Colors.yellow);
      
      if (levelProgress >= targetScore) {
        nextLevel();
      }
    } else {
      gameOver();
      createParticles(obj.position, Colors.red);
    }
    
    obj.removeFromParent();
    gameObjects.remove(obj);
  }

  void createParticles(Vector2 position, Color color) {
    for (int i = 0; i < 8; i++) {
      final particle = GameParticle(
        position: Vector2.copy(position),
        velocity: Vector2(
          (math.Random().nextDouble() - 0.5) * 200,
          (math.Random().nextDouble() - 0.5) * 200,
        ),
        color: color,
      );
      add(particle);
      particles.add(particle);
    }
  }

  void nextLevel() {
    level++;
    levelProgress = 0;
    targetScore = level * 8 + 5;
    player.upgradeMagnet(level);
    startSpawning(); // Restart timer with new spawn rate
  }

  void gameOver() {
    gameRunning = false;
    spawnTimer?.cancel();
    
    // Show game over dialog
    gameUI.showGameOver(score, level);
  }

  void restartGame() {
    // Reset game state
    score = 0;
    level = 1;
    levelProgress = 0;
    targetScore = 10;
    gameRunning = true;
    
    // Clear objects and particles
    for (final obj in gameObjects) {
      obj.removeFromParent();
    }
    gameObjects.clear();
    
    for (final particle in particles) {
      particle.removeFromParent();
    }
    particles.clear();
    
    // Reset player
    player.reset();
    
    // Restart spawning
    startSpawning();
    
    // Hide game over UI
    gameUI.hideGameOver();
  }

  @override
  bool onDragUpdate(DragUpdateEvent event) {
    if (gameRunning) {
      player.moveHorizontally(event.localDelta.x * 0.5);
    }
    return true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (gameRunning) {
      // Update magnetic effects
      for (final obj in List.from(gameObjects)) {
        if (obj.isMounted) {
          player.applyMagneticForce(obj, dt);
        }
      }
      
      // Clean up particles
      particles.removeWhere((particle) => !particle.isMounted);
      gameObjects.removeWhere((obj) => !obj.isMounted);
    }
  }
}
