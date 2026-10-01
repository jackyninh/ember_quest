import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../ember_quest.dart';

class PowerUp extends SpriteComponent
    with HasGameReference<EmberQuestGame> {
  final Vector2 gridPosition;
  double xOffset;

  final Vector2 velocity = Vector2.zero();

  PowerUp({
    required this.gridPosition,
    required this.xOffset,
  }) : super(
    size: Vector2.all(48),
    anchor: Anchor.center,
  );

  @override
  Future<void> onLoad() async {
    final powerUpImage = game.images.fromCache('gas.png');
    sprite = Sprite(powerUpImage);

    position = Vector2(
      (gridPosition.x * 64) + xOffset + 32,
      game.size.y - (gridPosition.y * 64) - 32,
    );

    add(
      RectangleHitbox(
        collisionType: CollisionType.passive,
      ),
    );
  }

  @override
  void update(double dt) {
    velocity.x = game.objectSpeed;
    position += velocity * dt;

    if (position.x < -size.x || game.health <= 0) {
      removeFromParent();
    }

    super.update(dt);
  }
}