import 'dart:math';

import 'package:flame/components.dart';

import '../config.dart';
import '../forest_game.dart';
import '../sfx.dart';
import 'monster.dart';

/// 여우불: 레인을 따라 오른쪽으로 날아가 처음 닿는 몬스터에게 피해를 준다.
class Fireball extends SpriteComponent with HasGameReference<ForestGame> {
  Fireball({required Vector2 position, required this.row, double? power})
      : power = power ?? damage,
        super(position: position, size: Vector2(36, 48), anchor: Anchor.center, priority: row * 10 + 8);

  static const double speed = 420;
  static const double damage = 25; // 20 → 25 (7-1단계): 슬라임 8발

  final int row;

  /// 이 여우불의 피해 (여우 강화가 [damage]보다 키운다, 12단계).
  final double power;
  double _t = 0;

  @override
  Future<void> onLoad() async {
    sprite = Sprite(await game.images.load('fx/fireball.webp'));
    angle = -pi / 2; // 위로 선 불꽃 끝이 뒤(왼쪽)로 날리도록 눕힌다
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    position.x += speed * dt;
    // 일렁임
    scale = Vector2(1 + sin(_t * 30) * 0.08, 1 - sin(_t * 30) * 0.08);
    final target = _firstMonsterHit();
    if (target != null) {
      target.takeDamage(power);
      game.sfx.play(Sfx.hit);
      removeFromParent();
    } else if (position.x > GameConfig.width + 40) {
      removeFromParent();
    }
  }

  Monster? _firstMonsterHit() {
    Monster? hit;
    for (final m in game.monsters) {
      if (m.row != row || !m.alive) continue;
      if (position.x >= m.position.x - m.type.hitHalfWidth && position.x <= m.position.x + m.type.hitHalfWidth * 2) {
        if (hit == null || m.position.x < hit.position.x) hit = m;
      }
    }
    return hit;
  }
}
