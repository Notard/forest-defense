import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/config.dart';
import 'package:forest_defense/game/forest_game.dart';

void main() {
  testWithGame<ForestGame>(
    '카메라가 1280x720 고정 해상도로 왼쪽 위를 원점으로 본다',
    ForestGame.new,
    (game) async {
      expect(
        game.camera.viewport.virtualSize,
        Vector2(GameConfig.width, GameConfig.height),
      );
      expect(game.camera.viewfinder.anchor, Anchor.topLeft);
    },
  );
}
