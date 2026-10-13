import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'components/field.dart';
import 'components/lane_background.dart';
import 'config.dart';
import 'hud/hud_placeholder.dart';

/// 숲 지키기 게임 루트. 월드 좌표는 왼쪽 위 (0, 0) ~ 오른쪽 아래 (1280, 720).
///
/// 카메라는 움직이지 않으므로 HUD도 월드에 둔다. 화면 비율이 16:9가 아니면
/// 고정 해상도 카메라가 레터박스를 만들고, 입력 좌표도 알아서 맞춰 준다.
class ForestGame extends FlameGame {
  ForestGame()
      : super(
          camera: CameraComponent.withFixedResolution(
            width: GameConfig.width,
            height: GameConfig.height,
          ),
        );

  late final Field field;

  @override
  Color backgroundColor() => GameConfig.backgroundColor;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    field = Field();
    world.addAll([LaneBackground(), field, HudPlaceholder()]);
  }
}
