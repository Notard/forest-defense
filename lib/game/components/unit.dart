import 'package:flame/components.dart';

import '../art.dart';
import '../config.dart';
import '../grid.dart';
import '../units.dart';

/// 칸에 놓인 동물. 발이 칸 바닥에 오도록 세운다.
///
/// 4단계에서는 기본 동작만 재생한다. 능력(생산·공격·폭발)과 HP는 5단계에서 붙인다.
class UnitComponent extends SpriteAnimationComponent {
  UnitComponent({required this.type, required this.cell, required this.art})
      : super(
          animation: art.animation(type.idleAction),
          size: art.frameSize * art.scaleForHeight(type.displayHeight),
          anchor: Anchor(art.anchor.x / art.frameSize.x, art.anchor.y / art.frameSize.y),
          position: footOf(cell),
          // 아래 레인일수록 앞에 그린다 (위 레인 유닛의 머리를 덮도록)
          priority: cell.row * 10 + 1,
        );

  final UnitType type;
  final Cell cell;
  final CharacterArt art;

  /// 칸 안에서 발이 닿는 위치: 가로 가운데, 칸 아래 끝에서 [footInset] 위.
  static Vector2 footOf(Cell cell) =>
      Grid.topLeft(cell) + Vector2(GameConfig.cellWidth / 2, GameConfig.cellHeight - footInset);

  static const double footInset = 8;
}
