import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/config.dart';

import 'support.dart';

void main() {
  // 배경 그림을 에셋에서 읽으므로 위젯 테스트(GameWidget)로 띄운다. 위젯 없이 띄우면 에셋 번들이 없다.
  GameTester(testGame).testGameWidget(
    '카메라가 1280x720 고정 해상도로 왼쪽 위를 원점으로 본다',
    verify: (game, tester) async {
      expect(
        game.camera.viewport.virtualSize,
        Vector2(GameConfig.width, GameConfig.height),
      );
      expect(game.camera.viewfinder.anchor, Anchor.topLeft);
    },
  );
}
