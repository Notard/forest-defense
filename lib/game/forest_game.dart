import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'art.dart';
import 'components/acorn.dart';
import 'components/field.dart';
import 'components/ghost.dart';
import 'components/lane_background.dart';
import 'components/monster.dart';
import 'components/unit.dart';
import 'components/wave_runner.dart';
import 'config.dart';
import 'garden.dart';
import 'grid.dart';
import 'hud/hud.dart';
import 'monsters.dart';
import 'units.dart';

/// 숲 지키기 게임 루트. 월드 좌표는 왼쪽 위 (0, 0) ~ 오른쪽 아래 (1280, 720).
///
/// 카메라는 움직이지 않으므로 HUD도 월드에 둔다. 화면 비율이 16:9가 아니면
/// 고정 해상도 카메라가 레터박스를 만들고, 입력 좌표도 알아서 맞춰 준다.
class ForestGame extends FlameGame {
  ForestGame({
    Random? random,
    this.skyAcorns = true,
    int? startAcorns,
    this.practice = false,
    bool? waves,
    this.startWave = 1,
    this.timeScale = 1,
  })
      : _random = random ?? Random(),
        garden = Garden(acorns: startAcorns ?? Garden.startAcorns),
        wavesOn = waves ?? !practice,
        super(
          camera: CameraComponent.withFixedResolution(
            width: GameConfig.width,
            height: GameConfig.height,
          ),
        );

  final Random _random;

  /// 하늘 도토리를 떨어뜨릴지 (테스트에서는 끈다).
  final bool skyAcorns;

  /// 확인용: 레인마다 움직이지 않는 연습 상대 몬스터를 세운다 (`?practice=1`, 5단계).
  final bool practice;

  /// 살아 있는 몬스터. 여우가 겨누고 여우불·스컨크가 맞힌다.
  final List<Monster> monsters = [];

  /// 웨이브를 돌릴지 (연습 모드와 테스트에서는 끈다).
  final bool wavesOn;

  /// 확인용: 이 웨이브부터 시작 (`?wave=5`).
  final int startWave;

  /// 확인용: 게임 시계 배속 (`?speed=2`). 애니메이션·이동·쿨다운이 모두 빨라진다.
  final double timeScale;
  WaveRunner? waveRunner;

  /// 둥지에 닿은 몬스터 수 (7단계에서 통나무·게임오버로 바꾼다).
  int reachedHome = 0;

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
    // 효과 그림은 미리 읽어 둔다. 첫 여우불·첫 연기에서 그림을 읽느라 한 박자 늦지 않게.
    await images.loadAll(const ['fx/acorn.webp', 'fx/fireball.webp', 'fx/smoke.webp', 'fx/helmet.webp', 'fx/log.webp']);
    await world.addAll([
      LaneBackground(),
      field,
      PlacementGhost(),
      hud,
      if (skyAcorns) SkyAcornSpawner(random: _random),
    ]);
    if (practice) await _addPracticeTargets();
    if (wavesOn) await world.add(waveRunner = WaveRunner(random: _random, startWave: startWave));
  }

  /// 몬스터가 둥지 앞에 닿았다. 7단계에서 레인 통나무와 게임오버를 붙인다.
  void onMonsterReachedHome(Monster m) {
    reachedHome++;
    monsters.remove(m);
    m.removeFromParent();
  }

  Future<void> _addPracticeTargets() async {
    const kinds = [MonsterType.slime, MonsterType.helmetSlime, MonsterType.wisp, MonsterType.slime, MonsterType.helmetSlime];
    for (var row = 0; row < GameConfig.rows; row++) {
      await addMonster(kinds[row], row: row, x: Grid.center((row: row, col: 7)).x, moving: false);
    }
  }

  /// 몬스터를 레인 [row]의 x 위치에 세운다.
  Future<Monster> addMonster(MonsterType type, {required int row, required double x, bool moving = true}) async {
    final m = await Monster.create(this, type, row: row, x: x, moving: moving);
    monsters.add(m);
    await world.add(m);
    return m;
  }

  @override
  void update(double dt) {
    final scaled = dt * timeScale;
    super.update(scaled);
    garden.tick(scaled);
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
