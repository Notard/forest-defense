import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/grid.dart';

/// 실제 입력 경로(화면 탭 → 고정 해상도 카메라 → 필드)로 칸 판정을 확인한다.
void main() {
  // 위젯 테스트 화면은 800 × 600 (4:3)이라 위아래 레터박스가 생긴다.
  // 1280 × 720 → 배율 0.625, 그려지는 높이 450, 위쪽 여백 75.
  Offset toScreen(Vector2 world) =>
      Offset(world.x * 0.625, 75 + world.y * 0.625);

  GameTester(ForestGame.new).testGameWidget(
    '레터박스가 있어도 탭한 화면 위치가 올바른 칸으로 바뀐다',
    verify: (game, tester) async {
      expect(game.canvasSize, Vector2(800, 600));
      for (final cell in [
        (row: 0, col: 0),
        (row: 2, col: 4),
        (row: 4, col: 8),
      ]) {
        await tester.tapAt(toScreen(Grid.center(cell)));
        await tester.pump(const Duration(milliseconds: 100));
        expect(game.field.selectedCell, cell);
      }
    },
  );

  GameTester(ForestGame.new).testGameWidget(
    '필드 밖(HUD·둥지·레터박스)을 탭하면 선택이 바뀌지 않는다',
    verify: (game, tester) async {
      await tester.tapAt(toScreen(Grid.center((row: 1, col: 1))));
      await tester.pump(const Duration(milliseconds: 100));
      for (final world in [
        Vector2(500, 50), // HUD
        Vector2(70, 300), // 둥지
        Vector2(1150, 300), // 등장 구역
      ]) {
        await tester.tapAt(toScreen(world));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tapAt(const Offset(400, 20)); // 위쪽 레터박스
      await tester.pump(const Duration(milliseconds: 100));
      expect(game.field.selectedCell, (row: 1, col: 1));
    },
  );
}
