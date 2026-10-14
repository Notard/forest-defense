import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/components/hoot_wave.dart';
import 'package:forest_defense/game/components/monster.dart';
import 'package:forest_defense/game/components/unit.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/grid.dart';
import 'package:forest_defense/game/monsters.dart';
import 'package:forest_defense/game/progress.dart';
import 'package:forest_defense/game/sfx.dart';
import 'package:forest_defense/game/stages.dart';
import 'package:forest_defense/game/units.dart';

import 'support.dart';

/// 10단계 새 친구: 고슴도치(가시), 부엉이(감속), 곰(내려치기).
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

  Future<Monster> addMonster(ForestGame game, WidgetTester tester, MonsterType type, int row, double x, {bool moving = false}) async {
    await tester.runAsync(() async {
      await game.addMonster(type, row: row, x: x, moving: moving);
      game.update(0);
    });
    return game.monsters.last;
  }

  /// 새로 붙는 컴포넌트(물결·연기)의 onLoad가 끝나도록 실제 시간을 조금씩 흘린다.
  Future<void> run(ForestGame game, WidgetTester tester, double seconds) => tester.runAsync(() async {
        for (var t = 0.0; t < seconds; t += 1 / 60) {
          game.update(1 / 60);
          await Future<void>.delayed(Duration.zero);
        }
      });

  GameTester(testGame).testGameWidget(
    '고슴도치를 깨문 몬스터는 한 입마다 가시 피해를 받는다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final hedgehog = await place(game, tester, UnitType.hedgehog, (row: 2, col: 2));
      final slime = await addMonster(game, tester, MonsterType.slime, 2, hedgehog.position.x + 40, moving: true);
      await run(game, tester, 3);
      expect(slime.eating, hedgehog);
      final bites = ((hedgehog.maxHp - hedgehog.hp) / slime.biteDamage).round();
      expect(bites, greaterThan(0));
      expect(slime.hp, MonsterType.slime.hp - bites * Hedgehog.spineDamage);
      expect(game.sfx.played, contains(Sfx.spine));
    },
  );

  GameTester(testGame).testGameWidget(
    '부엉이는 같은 레인 앞 몬스터를 모두 slowSeconds초 동안 반 속도로 만든다 (다른 레인·뒤쪽은 그대로)',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final owl = await place(game, tester, UnitType.owl, (row: 1, col: 1));
      final near = await addMonster(game, tester, MonsterType.slime, 1, Grid.center((row: 1, col: 4)).x);
      final far = await addMonster(game, tester, MonsterType.wisp, 1, Grid.center((row: 1, col: 8)).x);
      final behind = await addMonster(game, tester, MonsterType.slime, 1, owl.position.x - 80);
      final other = await addMonster(game, tester, MonsterType.slime, 3, Grid.center((row: 3, col: 4)).x);
      await run(game, tester, 1.2); // 0.5초 뒤 부엉, 4번째 프레임(0.33초)에 물결
      expect(near.slowed && far.slowed, isTrue);
      expect(behind.slowed, isFalse);
      expect(other.slowed, isFalse);
      expect(game.world.children.whereType<HootWave>(), isNotEmpty);
      expect(game.sfx.played, contains(Sfx.hoot));

      // 감속된 몬스터는 반 속도로 걷는다
      near.slowTime = Owl.slowSeconds;
      final walking = await addMonster(game, tester, MonsterType.slime, 4, 900, moving: true);
      walking.slow(10);
      final x0 = walking.position.x;
      await run(game, tester, 1);
      expect(x0 - walking.position.x, closeTo(walking.speed * Monster.slowFactor, 2));
    },
  );

  GameTester(testGame).testGameWidget(
    '곰은 바로 앞 reachCells칸 안 몬스터 모두에게 damage, 그보다 먼 몬스터는 치지 않는다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final bear = await place(game, tester, UnitType.bear, (row: 3, col: 2));
      final far = await addMonster(game, tester, MonsterType.slime, 3, bear.position.x + 96 * 3);
      await run(game, tester, 1);
      expect(far.hp, MonsterType.slime.hp, reason: '멀면 휘두르지 않는다');

      final a = await addMonster(game, tester, MonsterType.slime, 3, bear.position.x + 40);
      final b = await addMonster(game, tester, MonsterType.slime, 3, bear.position.x + 100);
      await run(game, tester, 0.6); // 5번째 프레임(0.42초)
      expect(a.hp, MonsterType.slime.hp - Bear.damage);
      expect(b.hp, MonsterType.slime.hp - Bear.damage);
      expect(far.hp, MonsterType.slime.hp);
      expect(game.sfx.played, contains(Sfx.swipe));
      await run(game, tester, Bear.interval);
      expect(a.hp, MonsterType.slime.hp - 2 * Bear.damage, reason: 'interval마다 다시 친다');
    },
  );

  test('새 친구는 1-2 고슴도치, 1-3 까치, 1-4 부엉이, 1-5 곰, 2-1 스컨크 (14-1단계 순서)', () {
    final p = Progress();
    for (final id in ['1-1', '1-2', '1-3', '1-4', '1-5', '2-1']) {
      p.record(stageById(id), won: true, lostHeart: false, lostUnit: false);
    }
    expect(p.unlockedUnits, UnitType.values);
    expect(stageById('1-2').unlocks, UnitType.hedgehog);
    expect(stageById('1-4').unlocks, UnitType.owl);
    expect(stageById('1-5').unlocks, UnitType.bear);
    expect(stageById('1-3').unlocks, UnitType.magpie);
    expect(stageById('2-1').unlocks, UnitType.skunk);
  });
}
