import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'config.dart';

/// 숲 지키기 게임 루트. 월드 좌표는 왼쪽 위 (0, 0) ~ 오른쪽 아래 (1280, 720).
class ForestGame extends FlameGame {
  ForestGame()
      : super(
          camera: CameraComponent.withFixedResolution(
            width: GameConfig.width,
            height: GameConfig.height,
          ),
        );

  @override
  Color backgroundColor() => GameConfig.backgroundColor;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    // 2단계에서 레인 배경으로 바꿀 임시 필드.
    world.add(
      RectangleComponent(
        size: Vector2(GameConfig.width, GameConfig.height),
        paint: Paint()..color = const Color(0xFF7BB661),
      ),
    );
  }
}
