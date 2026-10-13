import 'dart:ui';

import 'package:flame/components.dart';

import '../config.dart';
import '../grid.dart';

/// 임시 배경: 왼쪽 둥지, 잔디 체크무늬 필드, 오른쪽 몬스터 등장 흙길.
///
/// 3단계에서 Codex로 만든 `bg_forest.png`로 바꾼다. 그때도 칸 위치는
/// [GameConfig] 값을 그대로 쓰므로 그림이 칸에 맞아야 한다.
class LaneBackground extends PositionComponent {
  LaneBackground()
      : super(size: Vector2(GameConfig.width, GameConfig.height), priority: -10);

  final _nest = Paint()..color = GameConfig.nestColor;
  final _path = Paint()..color = GameConfig.pathColor;
  final _light = Paint()..color = GameConfig.grassLight;
  final _dark = Paint()..color = GameConfig.grassDark;
  final _lane = Paint()
    ..color = const Color(0x22000000)
    ..strokeWidth = 2;

  @override
  void render(Canvas canvas) {
    const fieldBottom = GameConfig.fieldY + GameConfig.fieldHeight;
    const fieldRight = GameConfig.fieldX + GameConfig.fieldWidth;

    // 둥지 + 통나무 열 (필드 왼쪽).
    canvas.drawRect(
      const Rect.fromLTRB(0, GameConfig.fieldY, GameConfig.fieldX, fieldBottom),
      _nest,
    );
    // 몬스터 등장 흙길 (필드 오른쪽).
    canvas.drawRect(
      const Rect.fromLTRB(
          fieldRight, GameConfig.fieldY, GameConfig.width, fieldBottom),
      _path,
    );
    // 잔디 체크무늬. 원작처럼 칸마다 밝기를 번갈아 칸 경계가 보이게 한다.
    for (final cell in Grid.allCells) {
      final tl = Grid.topLeft(cell);
      canvas.drawRect(
        Rect.fromLTWH(
            tl.x, tl.y, GameConfig.cellWidth, GameConfig.cellHeight),
        (cell.row + cell.col).isEven ? _light : _dark,
      );
    }
    // 레인 구분선.
    for (var row = 1; row < GameConfig.rows; row++) {
      final y = GameConfig.fieldY + row * GameConfig.cellHeight;
      canvas.drawLine(Offset(0, y), Offset(GameConfig.width, y), _lane);
    }
  }
}
