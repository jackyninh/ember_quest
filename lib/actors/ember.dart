import 'dart:async' as async;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/services.dart';

import '../ember_quest.dart';
import '../objects/ground_block.dart';
import '../objects/platform_block.dart';
import '../objects/power_up.dart';
import '../objects/star.dart';
import 'water_enemy.dart';

class EmberPlayer extends SpriteAnimationComponent
    with KeyboardHandler, CollisionCallbacks, HasGameReference<EmberQuestGame> {
  EmberPlayer({
    required super.position,
  }) : super(
    size: Vector2.all(64),
    anchor: Anchor.center,
  );

  final Vector2 velocity = Vector2.zero();
  final Vector2 fromAbove = Vector2(0, -1);

  final double gravity = 15;
  final double jumpSpeed = 950;
  final double moveSpeed = 200;
  final double terminalVelocity = 150;

  int horizontalDirection = 0;

  bool hasJumped = false;
  bool isOnGround = false;
  bool hitByEnemy = false;

  @override
  Future<void> onLoad() async {
    // Normal Ember animation.
    animation = SpriteAnimation.fromFrameData(
      game.images.fromCache('ember.png'),
      SpriteAnimationData.sequenced(
        amount: 4,
        textureSize: Vector2.all(16),
        stepTime: 0.12,
      ),
    );

    add(
      CircleHitbox(),
    );
  }

  @override
  bool onKeyEvent(
      KeyEvent event,
      Set<LogicalKeyboardKey> keysPressed,
      ) {
    horizontalDirection = 0;

    horizontalDirection +=
    (keysPressed.contains(LogicalKeyboardKey.keyA) ||
        keysPressed.contains(LogicalKeyboardKey.arrowLeft))
        ? -1
        : 0;

    horizontalDirection +=
    (keysPressed.contains(LogicalKeyboardKey.keyD) ||
        keysPressed.contains(LogicalKeyboardKey.arrowRight))
        ? 1
        : 0;

    hasJumped = keysPressed.contains(
      LogicalKeyboardKey.space,
    );

    return true;
  }

  @override
  void update(double dt) {
    velocity.x = horizontalDirection * moveSpeed;
    game.objectSpeed = 0;

    // Stop Ember from moving past the left side.
    if (position.x - 36 <= 0 &&
        horizontalDirection < 0) {
      velocity.x = 0;
    }

    // Scroll the level when Ember reaches
    // the middle of the screen.
    if (position.x + 64 >= game.size.x / 2 &&
        horizontalDirection > 0) {
      velocity.x = 0;
      game.objectSpeed = -moveSpeed;
    }

    // Gravity.
    velocity.y += gravity;

    // Jump.
    if (hasJumped) {
      if (isOnGround) {
        velocity.y = -jumpSpeed;
        isOnGround = false;
      }

      hasJumped = false;
    }

    // Limit falling speed.
    velocity.y = velocity.y.clamp(
      -jumpSpeed,
      terminalVelocity,
    );

    // Move Ember.
    position += velocity * dt;

    // Game over if Ember falls off the map.
    if (position.y > game.size.y + size.y) {
      game.health = 0;
    }

    if (game.health <= 0) {
      removeFromParent();
    }

    // Flip Ember based on direction.
    if (horizontalDirection < 0 &&
        scale.x > 0) {
      flipHorizontally();
    } else if (horizontalDirection > 0 &&
        scale.x < 0) {
      flipHorizontally();
    }

    super.update(dt);
  }

  @override
  void onCollision(
      Set<Vector2> intersectionPoints,
      PositionComponent other,
      ) {
    // Ground and platform collisions.
    if (other is GroundBlock ||
        other is PlatformBlock) {
      if (intersectionPoints.length == 2) {
        final mid =
            (intersectionPoints.elementAt(0) +
                intersectionPoints.elementAt(1)) /
                2;

        final collisionNormal =
            absoluteCenter - mid;

        final separationDistance =
            (size.x / 2) -
                collisionNormal.length;

        collisionNormal.normalize();

        // Ember landed on top of the block.
        if (fromAbove.dot(collisionNormal) > 0.9) {
          isOnGround = true;
        }

        position += collisionNormal.scaled(
          separationDistance,
        );
      }
    }

    // Collect a normal star.
    if (other is Star) {
      other.removeFromParent();
      game.starsCollected++;
    }

    // Collect the gas canister power-up.
    if (other is PowerUp) {
      other.removeFromParent();
      activatePowerUp();
    }

    // Water enemy collision.
    if (other is WaterEnemy) {
      if (game.isPoweredUp) {
        // Create smoke where the enemy was destroyed.
        spawnSmoke(
          other.position.clone(),
        );

        // Destroy the water enemy.
        other.removeFromParent();

        // Reward Ember with one star.
        game.starsCollected++;
      } else {
        // Normal Ember takes damage.
        hit();
      }
    }

    super.onCollision(
      intersectionPoints,
      other,
    );
  }

  // Activate power-up for 15 seconds.
  void activatePowerUp() {
    game.isPoweredUp = true;

    // Change Ember to purple flame animation.
    animation = SpriteAnimation.fromFrameData(
      game.images.fromCache(
        'ember_powerup.png',
      ),
      SpriteAnimationData.sequenced(
        amount: 4,
        textureSize: Vector2.all(16),
        stepTime: 0.12,
      ),
    );

    // Start flickering after 12 seconds.
    async.Timer(
      const Duration(seconds: 12),
          () {
        if (game.isPoweredUp) {
          flickerPowerUp();
        }
      },
    );

    // End power-up after 15 seconds.
    async.Timer(
      const Duration(seconds: 15),
          () {
        game.isPoweredUp = false;

        // Change Ember back to normal.
        animation = SpriteAnimation.fromFrameData(
          game.images.fromCache(
            'ember.png',
          ),
          SpriteAnimationData.sequenced(
            amount: 4,
            textureSize: Vector2.all(16),
            stepTime: 0.12,
          ),
        );

        opacity = 1.0;
      },
    );
  }

  // Flicker during the final 3 seconds.
  void flickerPowerUp() {
    var flickers = 0;

    async.Timer.periodic(
      const Duration(
        milliseconds: 250,
      ),
          (timer) {
        if (!game.isPoweredUp) {
          opacity = 1.0;
          timer.cancel();
          return;
        }

        if (opacity == 1.0) {
          opacity = 0.5;
        } else {
          opacity = 1.0;
        }

        flickers++;

        // 12 flickers = 3 seconds.
        if (flickers >= 12) {
          opacity = 1.0;
          timer.cancel();
        }
      },
    );
  }

  // Create smoke when an enemy is destroyed.
  void spawnSmoke(
      Vector2 position,
      ) {
    final smokeOffsets = [
      Vector2(-16, 0),
      Vector2(0, -8),
      Vector2(16, 0),
      Vector2(-8, 10),
      Vector2(10, 10),
    ];

    for (var i = 0;
    i < smokeOffsets.length;
    i++) {
      final smoke = SmokePuff(
        position:
        position + smokeOffsets[i],
        drift: Vector2(
          (i - 2) * 8,
          -35 - (i * 5),
        ),

        // Larger smoke puffs.
        radius:
        9 + (i % 3).toDouble(),
      );

      game.world.add(smoke);
    }
  }

  // Ember takes damage.
  void hit() {
    if (!hitByEnemy) {
      game.health--;
      hitByEnemy = true;
    }

    // Blink when hit.
    add(
      OpacityEffect.fadeOut(
        EffectController(
          alternate: true,
          duration: 0.1,
          repeatCount: 5,
        ),
      )..onComplete = () {
        hitByEnemy = false;
      },
    );
  }
}

// Individual smoke particle.
class SmokePuff extends CircleComponent {
  SmokePuff({
    required super.position,
    required this.drift,
    required super.radius,
  }) : super(
    anchor: Anchor.center,
    paint: Paint()
      ..color = const Color.fromARGB(
        190,
        190,
        190,
        190,
      ),
  );

  final Vector2 drift;

  double lifetime = 0;
  final double maxLifetime = 0.7;

  @override
  void update(double dt) {
    super.update(dt);

    lifetime += dt;

    // Smoke floats upward.
    position += drift * dt;

    // Fade smoke out.
    final fade =
    (1 - (lifetime / maxLifetime)).clamp(
      0.0,
      1.0,
    );

    paint.color = Color.fromARGB(
      (190 * fade).round(),
      190,
      190,
      190,
    );

    // Remove smoke after fading.
    if (lifetime >= maxLifetime) {
      removeFromParent();
    }
  }
}