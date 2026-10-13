import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/components/monster.dart';
import 'package:forest_defense/game/components/unit.dart';
import 'package:forest_defense/game/config.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/grid.dart';
import 'package:forest_defense/game/monsters.dart';
import 'package:forest_defense/game/units.dart';

import 'support.dart';

/// 몬스터 이동과 갉아먹기 (plan.md 6단계). 게임 시계를 한 프레임(1/60초)씩 흘려 확인한다.
void main() {
  Future<UnitComponent> place(ForestGame game, WidgetTester tester, UnitType type, Cell cell) async {
    game.garden.acorns = 10000;
    await tester.runAsync(() async {
      game.selectedUnit = type;
      await game.onCellTapped(cell);
      game.update(0);
    });
    return game.unitComponents[cell]!;
  }

  Future<Monster> spawn(ForestGame game, WidgetTester tester, MonsterType type, int row, double x) async {
    late Monster m;
    await tester.runAsync(() async {
      m = await game.addMonster(type, row: row, x: x);
      game.update(0);
    });
    return m;
  }

  void run(ForestGame game, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      game.update(1 / 60);
    }
  }

  GameTester(testGame).testGameWidget(
    '몬스터는 종류마다 정한 속도(초/칸)로 걷는다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final slime = await spawn(game, tester, MonsterType.slime, 1, 1000);
      final wisp = await spawn(game, tester, MonsterType.wisp, 3, 1000);
      final s = MonsterType.slime.secondsPerCell;
      run(game, s);
      expect(1000 - slime.position.x, closeTo(GameConfig.cellWidth, 2));
      expect(1000 - wisp.position.x, closeTo(GameConfig.cellWidth * s / MonsterType.wisp.secondsPerCell, 3));
      expect(slime.current, 'walk');
    },
  );

  GameTester(testGame).testGameWidget(
    '앞에 동물이 있으면 멈춰 갉아먹고, 동물이 없어지면 다시 걷는다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      const cell = (row: 2, col: 3);
      final turtle = await place(game, tester, UnitType.turtle, cell);
      final slime = await spawn(game, tester, MonsterType.slime, 2, turtle.position.x + 130);
      // 130 - 52(biteReach) = 78px 걸어 닿는 데 걸리는 시간
      final reach = (130 - Monster.biteReach) / slime.speed;
      run(game, reach - 0.3);
      expect(slime.eating, isNull);
      run(game, 0.6);
      expect(slime.eating, same(turtle));
      expect(slime.current, 'eat');
      final stoppedAt = slime.position.x;
      run(game, 2.0);
      expect(slime.position.x, stoppedAt, reason: '먹는 동안은 걷지 않는다');
      final bite = MonsterType.slime.biteDps;
      expect(UnitType.turtle.maxHp - turtle.hp, closeTo(2 * bite, bite / 2 + 1), reason: '2초 × 초당 피해 (한 입은 0.5초 몫)');

      // 삽으로 치운 것처럼 직접 치우면 다시 걷는다
      game.garden.remove(cell);
      game.unitComponents.remove(cell)!.removeFromParent();
      run(game, 1.0);
      expect(slime.eating, isNull);
      expect(slime.current, 'walk');
      expect(slime.position.x, lessThan(stoppedAt - 15));
    },
  );

  GameTester(testGame).testGameWidget(
    '먹던 동물이 쓰러지면 칸이 비고 몬스터는 다시 걷는다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      const cell = (row: 0, col: 2);
      final squirrel = await place(game, tester, UnitType.squirrel, cell);
      final wisp = await spawn(game, tester, MonsterType.wisp, 0, squirrel.position.x + 40);
      // 다람쥐 HP / 도깨비불 초당 피해 = 쓰러지기까지 걸리는 시간
      final seconds = UnitType.squirrel.maxHp / MonsterType.wisp.biteDps;
      run(game, seconds - 0.6);
      expect(squirrel.alive, isTrue);
      run(game, 1.4);
      expect(squirrel.alive, isFalse);
      expect(game.garden.unitAt(cell), isNull);
      run(game, 0.5);
      expect(wisp.current, 'walk');
    },
  );

  GameTester(testGame).testGameWidget(
    '갉아먹는 중에 맞으면 깜빡이기만 하고 먹기를 멈추지 않는다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final turtle = await place(game, tester, UnitType.turtle, (row: 4, col: 4));
      final slime = await spawn(game, tester, MonsterType.slime, 4, turtle.position.x + 30);
      run(game, 0.2);
      expect(slime.current, 'eat');
      slime.takeDamage(20);
      run(game, 0.05);
      expect(slime.current, 'eat');
      expect(slime.hp, 180);
    },
  );
}
