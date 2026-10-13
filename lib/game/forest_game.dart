import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'art.dart';
import 'components/acorn.dart';
import 'components/field.dart';
import 'components/ghost.dart';
import 'components/lane_background.dart';
import 'components/unit.dart';
import 'config.dart';
import 'garden.dart';
import 'grid.dart';
import 'hud/hud.dart';
import 'units.dart';

/// 숲 지키기 게임 루트. 월드 좌표는 왼쪽 위 (0, 0) ~ 오른쪽 아래 (1280, 720).
///
/// 카메라는 움직이지 않으므로 HUD도 월드에 둔다. 화면 비율이 16:9가 아니면
/// 고정 해상도 카메라가 레터박스를 만들고, 입력 좌표도 알아서 맞춰 준다.
class ForestGame extends FlameGame {
  ForestGame({Random? random, this.skyAcorns = true, int? startAcorns})
      : _random = random ?? Random(),
        garden = Garden(acorns: startAcorns ?? Garden.startAcorns),
        super(
          camera: CameraComponent.withFixedResolution(
            width: GameConfig.width,
            height: GameConfig.height,
          ),
        );

  final Random _random;

  /// 하늘 도토리를 떨어뜨릴지 (테스트에서는 끈다).
  final bool skyAcorns;

  /// 도토리·쿨다운·칸 점유 규칙.
  final Garden garden;

  late final Field field;
  late final Hud hud;

  /// 칸에 놓인 유닛 컴포넌트.
  final Map<Cell, UnitComponent> unitComponents = {};

  /// 고른 카드 (없으면 null). 삽과 동시에 고를 수 없다.
  UnitType? selectedUnit;
  bool shovelMode = false;

  @override
  Color backgroundColor() => GameConfig.backgroundColor;

  @override
  Future<void> onLoad() async {
    CharacterArt.clearCache();
    camera.viewfinder.anchor = Anchor.topLeft;
    field = Field(onCellTap: onCellTapped);
    hud = Hud();
    await world.addAll([
      LaneBackground(),
      field,
      PlacementGhost(),
      hud,
      if (skyAcorns) SkyAcornSpawner(random: _random),
    ]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    garden.tick(dt);
  }

  /// 카드를 누름. 이미 고른 카드면 취소. 누를 수 없는 카드면 false (카드가 흔들린다).
  bool selectCard(UnitType type) {
    if (selectedUnit == type) {
      selectedUnit = null;
      return true;
    }
    if (!garden.isReady(type)) return false;
    selectedUnit = type;
    shovelMode = false;
    return true;
  }

  void toggleShovel() {
    shovelMode = !shovelMode;
    if (shovelMode) selectedUnit = null;
  }

  /// 칸을 누름: 삽 모드면 치우고, 카드를 골랐으면 놓는다.
  Future<void> onCellTapped(Cell cell) async {
    if (shovelMode) {
      if (garden.remove(cell) != null) unitComponents.remove(cell)?.removeFromParent();
      shovelMode = false;
      return;
    }
    final type = selectedUnit;
    if (type == null) return;
    if (garden.place(type, cell) != PlaceResult.placed) return;
    selectedUnit = null;
    final unit = UnitComponent(type: type, cell: cell, art: await CharacterArt.load(this, type.sheet));
    unitComponents[cell] = unit;
    await world.add(unit);
  }
}
