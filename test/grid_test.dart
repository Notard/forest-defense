import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/config.dart';
import 'package:forest_defense/game/grid.dart';

void main() {
  group('Grid.cellAt', () {
    test('필드 왼쪽 위 모서리는 (0, 0) 칸', () {
      expect(Grid.cellAt(Vector2(140, 110)), (row: 0, col: 0));
    });

    test('필드 오른쪽 아래 끝 바로 안쪽은 (4, 8) 칸', () {
      expect(Grid.cellAt(Vector2(1039.9, 659.9)), (row: 4, col: 8));
    });

    test('칸 경계는 오른쪽·아래쪽 칸에 속한다', () {
      expect(Grid.cellAt(Vector2(240, 110)), (row: 0, col: 1));
      expect(Grid.cellAt(Vector2(140, 220)), (row: 1, col: 0));
    });

    test('필드 밖은 null', () {
      expect(Grid.cellAt(Vector2(139.9, 300)), isNull, reason: '둥지');
      expect(Grid.cellAt(Vector2(500, 109.9)), isNull, reason: 'HUD');
      expect(Grid.cellAt(Vector2(1040, 300)), isNull, reason: '등장 구역');
      expect(Grid.cellAt(Vector2(500, 660)), isNull, reason: '진행 바');
      expect(Grid.cellAt(Vector2(-5, -5)), isNull);
    });
  });

  group('Grid 좌표', () {
    test('칸 가운데', () {
      expect(Grid.center((row: 0, col: 0)), Vector2(190, 165));
      expect(Grid.center((row: 4, col: 8)), Vector2(990, 605));
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
