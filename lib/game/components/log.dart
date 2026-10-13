import 'package:flame/components.dart';

import '../config.dart';
import '../forest_game.dart';
import '../sfx.dart';
import '../monsters.dart';
import 'smoke.dart';
import 'unit.dart';

/// 레인마다 하나씩 둥지 앞에 놓인 통나무 (plan.md 7단계).
///
/// 몬스터가 [triggerX]까지 오면 오른쪽으로 굴러가며(회전 + 이동) 닿는 몬스터를 모두 쓰러뜨리고,
/// 화면 밖으로 나가면 사라진다. 레인당 한 번만 쓴다.
class RollingLog extends SpriteComponent with HasGameReference<ForestGame> {
  RollingLog(this.row)
      : super(
          size: Vector2.all(displaySize),
          anchor: Anchor.center,
          position: Vector2(centerX, UnitComponent.footOf((row: row, col: 0)).y - displaySize / 2 + 4),
          priority: row * 10,
        );

  static const double displaySize = 54;

  /// 통나무 열(x 120~200) 가운데보다 조금 왼쪽: 첫 칸 동물의 꼬리와 덜 겹치게.
  static const double centerX = (GameConfig.logColumnX + GameConfig.fieldX) / 2 - 8;

  /// 몬스터 발이 이 x보다 왼쪽에 오면 굴러간다 (통나무 오른쪽 끝 + 조금).
  static const double triggerX = centerX + displaySize / 2 + 16;

  static const double speed = 520;

  final int row;
  bool rolling = false;

  @override
  Future<void> onLoad() async {
    sprite = Sprite(await game.images.load('fx/log.webp'));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!rolling) {
      // 몸 앞쪽 끝 기준 (보스처럼 몸이 크면 발보다 앞이 먼저 닿는다)
      if (game.monsters.any((m) => m.row == row && m.alive && m.position.x - (m.type.hitHalfWidth - 30) <= triggerX)) roll();
      return;
    }
    position.x += speed * dt;
    angle += speed / (displaySize / 2) * dt; // 미끄러지지 않고 구르는 회전 속도
    for (final m in game.monsters.toList()) {
      if (m.row == row && m.alive && (m.position.x - position.x).abs() < displaySize * 0.8 + m.type.hitHalfWidth - 30) {
        if (m.type.boss) {
          // 보스는 버틴다: 1000만 받고 통나무가 부서진다 (11단계)
          m.takeDamage(MonsterType.logDamageToBoss);
          game.world.add(Smoke(position: position.clone(), size: displaySize * 1.6, duration: 0.5));
          removeFromParent();
          return;
        }
        m.takeDamage(m.hp + m.helmetHp);
      }
    }
    if (position.x > GameConfig.width + displaySize) removeFromParent();
  }

  void roll() {
    if (rolling) return;
    rolling = true;
    game.sfx.play(Sfx.log);
    game.logs.remove(row);
  }
}
