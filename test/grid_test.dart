import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/config.dart';
import 'package:forest_defense/game/grid.dart';

void main() {
  const x0 = GameConfig.fieldX, y0 = GameConfig.fieldY;
  const w = GameConfig.cellWidth, h = GameConfig.cellHeight;
  const right = x0 + GameConfig.fieldWidth, bottom = y0 + GameConfig.fieldHeight;

  group('Grid.cellAt', () {
    test('필드 왼쪽 위 모서리는 (0, 0) 칸', () {
      expect(Grid.cellAt(Vector2(x0, y0)), (row: 0, col: 0));
    });

    test('필드 오른쪽 아래 끝 바로 안쪽은 마지막 칸 (4, 7) — 5 × 8 판 (14-1단계)', () {
      expect(Grid.cellAt(Vector2(right - 0.1, bottom - 0.1)), (row: 4, col: GameConfig.cols - 1));
      expect(GameConfig.cols, 8);
      expect(GameConfig.cellWidth, GameConfig.cellHeight, reason: '정사각 칸');
    });

    test('칸 경계는 오른쪽·아래쪽 칸에 속한다', () {
      expect(Grid.cellAt(Vector2(x0 + w, y0)), (row: 0, col: 1));
      expect(Grid.cellAt(Vector2(x0, y0 + h)), (row: 1, col: 0));
    });

    test('필드 밖은 null', () {
      expect(Grid.cellAt(Vector2(x0 - 0.1, 300)), isNull, reason: '둥지');
      expect(Grid.cellAt(Vector2(500, y0 - 0.1)), isNull, reason: 'HUD');
      expect(Grid.cellAt(Vector2(right, 300)), isNull, reason: '등장 구역');
      expect(Grid.cellAt(Vector2(500, bottom)), isNull, reason: '진행 바');
      expect(Grid.cellAt(Vector2(-5, -5)), isNull);
    });
  });

  group('Grid 좌표', () {
    test('칸 가운데', () {
      expect(Grid.center((row: 0, col: 0)), Vector2(x0 + w / 2, y0 + h / 2));
      expect(Grid.center((row: 4, col: 7)), Vector2(x0 + 7.5 * w, y0 + 4.5 * h));
    });

    test('필드가 배경 잔디밭(x 207~1055, y 110~646)과 거의 겹친다', () {
      // 배경 그림을 바꾸면 이 값도 다시 잰다 (WORKLOG 3-g)
      expect(x0, closeTo(207, 10));
      expect(right, closeTo(1055, 10));
      expect(y0, closeTo(110, 4));
      expect(bottom, closeTo(646, 4));
    });

    test('레인 가운데 y는 칸 가운데 y와 같다', () {
      for (var row = 0; row < GameConfig.rows; row++) {
        expect(Grid.laneCenterY(row), Grid.center((row: row, col: 3)).y);
      }
    });

    test('모든 칸에서 center → cellAt 왕복이 같은 칸을 돌려준다', () {
      final cells = Grid.allCells.toList();
      expect(cells, hasLength(GameConfig.rows * GameConfig.cols));
      for (final cell in cells) {
        expect(Grid.cellAt(Grid.center(cell)), cell);
      }
    });
  });
}
