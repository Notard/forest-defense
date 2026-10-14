import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/components/actor.dart';
import 'package:forest_defense/game/grid.dart';
import 'package:forest_defense/game/monsters.dart';
import 'package:forest_defense/game/units.dart';

import 'support.dart';

/// 머리 위 HP 막대 (사용자: "몬스터와 우리편 hp를 위에 작게 막대로 나타나게 해 줘").
void main() {
  GameTester(testGame).testGameWidget(
    '다치면 머리 위에 막대: 남은 HP 비율만큼 채움, 꽉 찼거나 쓰러지면 없음',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final slime = (await tester.runAsync(() => game.addMonster(MonsterType.slime, row: 2, x: 1000)))!;
      expect(slime.showsHpBar, Actor.hpBarOnlyWhenHurt ? isFalse : isTrue);
      slime.takeDamage(50);
      expect(slime.showsHpBar, isTrue);
      expect(slime.hpFraction, closeTo(150 / 200, 1e-9));
      slime.takeDamage(500);
      expect(slime.showsHpBar, isFalse, reason: '쓰러지는 동안은 막대 없음');

      game.garden.acorns = 500;
      await tester.runAsync(() async {
        game.selectCard(UnitType.turtle);
        await game.onCellTapped((row: 1, col: 2));
      });
      final turtle = game.unitComponents[(row: 1, col: 2)]!;
      expect(turtle.showsHpBar, Actor.hpBarOnlyWhenHurt ? isFalse : isTrue);
      turtle.takeDamage(turtle.maxHp * 0.25);
      expect(turtle.showsHpBar, isTrue);
      expect(turtle.hpFraction, closeTo(0.75, 1e-9));
      expect(turtle.hpBarColor, isNot(slime.hpBarColor), reason: '친구와 몬스터는 색이 다르다');
    },
  );

  GameTester(testGame).testGameWidget(
    '투구 슬라임은 투구까지 합친 비율, 큰 몬스터는 막대가 길다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final helmet = (await tester.runAsync(() => game.addMonster(MonsterType.helmetSlime, row: 1, x: 1000)))!;
      final total = MonsterType.helmetSlime.hp + MonsterType.helmetSlime.helmetHp;
      helmet.takeDamage(100); // 투구가 먼저 막는다
      expect(helmet.hp, MonsterType.helmetSlime.hp);
      expect(helmet.showsHpBar, isTrue);
      expect(helmet.hpFraction, closeTo((total - 100) / total, 1e-9));

      final boss = (await tester.runAsync(() => game.addMonster(MonsterType.bossSlime, row: 3, x: 1000)))!;
      final golem = (await tester.runAsync(() => game.addMonster(MonsterType.golem, row: 2, x: 1000)))!;
      expect(boss.hpBarWidth, greaterThan(golem.hpBarWidth));
      expect(golem.hpBarWidth, greaterThan(helmet.hpBarWidth));
      expect(Grid.center((row: 3, col: 0)).y, greaterThan(0));
    },
  );
}
