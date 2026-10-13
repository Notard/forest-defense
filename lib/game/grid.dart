import 'package:flame/components.dart';

import 'config.dart';

/// 필드의 한 칸. `row` 0이 맨 위 레인, `col` 0이 맨 왼쪽(둥지 쪽) 칸이다.
typedef Cell = ({int row, int col});

/// 칸 좌표와 화면(월드) 좌표 사이의 변환.
///
/// 클릭·탭 위치를 칸으로 바꾸거나, 유닛·몬스터를 칸 가운데에 놓을 때 쓴다.
abstract final class Grid {
  /// 월드 좌표 [p]가 가리키는 칸. 필드 밖이면 `null`.
  ///
  /// 칸의 왼쪽·위쪽 경계는 그 칸에 속하고, 오른쪽·아래쪽 경계는 다음 칸에 속한다.
  static Cell? cellAt(Vector2 p) {
    final x = p.x - GameConfig.fieldX;
    final y = p.y - GameConfig.fieldY;
    if (x < 0 || y < 0) return null;
    final col = (x / GameConfig.cellWidth).floor();
    final row = (y / GameConfig.cellHeight).floor();
    if (col >= GameConfig.cols || row >= GameConfig.rows) return null;
    return (row: row, col: col);
  }

  /// 칸의 왼쪽 위 모서리 (월드 좌표).
  static Vector2 topLeft(Cell cell) => Vector2(
        GameConfig.fieldX + cell.col * GameConfig.cellWidth,
        GameConfig.fieldY + cell.row * GameConfig.cellHeight,
      );

  /// 칸의 가운데 (월드 좌표). 유닛을 놓는 기준점이다.
  static Vector2 center(Cell cell) =>
      topLeft(cell) +
      Vector2(GameConfig.cellWidth / 2, GameConfig.cellHeight / 2);

  /// 레인 [row]의 가운데 y. 몬스터와 투사체가 이 높이로 움직인다.
  static double laneCenterY(int row) =>
      GameConfig.fieldY + (row + 0.5) * GameConfig.cellHeight;

  /// 필드 안의 모든 칸 (위 레인부터, 왼쪽 칸부터).
  static Iterable<Cell> get allCells sync* {
    for (var row = 0; row < GameConfig.rows; row++) {
      for (var col = 0; col < GameConfig.cols; col++) {
        yield (row: row, col: col);
      }
    }
  }
}
