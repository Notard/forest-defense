import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/components/fireball.dart';
import 'package:forest_defense/game/components/log.dart';
import 'package:forest_defense/game/components/monster.dart';
import 'package:forest_defense/game/components/unit.dart';
import 'package:forest_defense/game/config.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/grid.dart';
import 'package:forest_defense/game/monsters.dart';
import 'package:forest_defense/game/stages.dart';
import 'package:forest_defense/game/units.dart';

import 'support.dart';

/// 11단계 새 적: 돌 골렘, 박쥐(뛰어넘기), 버섯 포자(나뉨), 슬라임 왕(소환·통나무에 버팀).
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

  Future<Monster> add(ForestGame game, WidgetTester tester, MonsterType type, int row, double x, {bool moving = true}) async {
    late Monster m;
    await tester.runAsync(() async {
      m = await game.addMonster(type, row: row, x: x, moving: moving);
      game.update(0);
    });
    return m;
  }

  Future<void> run(ForestGame game, WidgetTester tester, double seconds) => tester.runAsync(() async {
        for (var t = 0.0; t < seconds; t += 1 / 60) {
          game.update(1 / 60);
          await Future<void>.delayed(Duration.zero);
        }
      });

  ForestGame noLogs() => ForestGame(skyAcorns: false, waves: false, sound: false, intro: false, logsOn: false);

  GameTester(noLogs).testGameWidget(
    '돌 골렘은 칸당 8초로 느리고 HP 900',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final g = await add(game, tester, MonsterType.golem, 2, 900);
      expect(g.maxHp, 900);
      await run(game, tester, 2);
      expect(900 - g.position.x, closeTo(2 * GameConfig.cellWidth / 8, 3));
    },
  );

  GameTester(noLogs).testGameWidget(
    '박쥐는 처음 만난 동물 하나를 뛰어넘고, 다음 동물은 깨문다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final first = await place(game, tester, UnitType.turtle, (row: 1, col: 5));
      final bat = await add(game, tester, MonsterType.bat, 1, first.position.x + 70);
      await run(game, tester, 1.2);
      expect(bat.jumped, isTrue);
      expect(bat.position.x, lessThan(first.position.x));
      expect(first.hp, first.maxHp, reason: '넘은 동물은 깨물지 않는다');
      expect(bat.position.y, closeTo(bat.groundY, 0.01), reason: '내려앉았다');

      final second = await place(game, tester, UnitType.fox, (row: 1, col: 3));
      await run(game, tester, 3);
      expect(bat.eating, second);
      expect(second.hp, lessThan(second.maxHp));
    },
  );

  GameTester(noLogs).testGameWidget(
    '부엉이로 느려진 박쥐는 뛰어넘지 못하고 깨문다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final turtle = await place(game, tester, UnitType.turtle, (row: 3, col: 5));
      final bat = await add(game, tester, MonsterType.bat, 3, turtle.position.x + 70);
      bat.slow(10);
      await run(game, tester, 3);
      expect(bat.jumped, isFalse);
      expect(bat.eating, turtle);
    },
  );

  GameTester(noLogs).testGameWidget(
    '버섯 포자는 쓰러지면 작은 버섯 둘로 나뉜다 (HP 60, 조금 떨어져서)',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final m = await add(game, tester, MonsterType.mushroom, 0, 800, moving: false);
      await tester.runAsync(() async => m.takeDamage(1000));
      await run(game, tester, 0.3);
      final minis = game.monsters.where((x) => x.type == MonsterType.miniMushroom).toList();
      expect(minis, hasLength(2));
      expect(minis.every((x) => x.row == 0 && x.maxHp == 60), isTrue);
      expect(minis.map((x) => x.position.x).toSet(), hasLength(2), reason: '겹치지 않게 조금 떨어져 나온다');
    },
  );

  GameTester(noLogs).testGameWidget(
    '슬라임 왕은 HP 25%마다 슬라임 둘을 위아래 레인에 불러낸다 (세 번까지)',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final boss = await add(game, tester, MonsterType.bossSlime, 2, 900, moving: false);
      expect(boss.maxHp, 3000);
      boss.takeDamage(700); // 77%: 아직
      await run(game, tester, 0.2);
      expect(game.monsters, hasLength(1));
      boss.takeDamage(100); // 73%
      await run(game, tester, 0.3);
      final slimes = game.monsters.where((m) => m.type == MonsterType.slime).toList();
      expect(slimes.map((m) => m.row).toSet(), {1, 3});
      boss.takeDamage(2000); // 6%: 50%·25% 두 번 더
      await run(game, tester, 0.3);
      expect(boss.summons, 3);
      expect(game.monsters.where((m) => m.type == MonsterType.slime), hasLength(6));
    },
  );

  GameTester(() => ForestGame(stage: stageById('2-5'), skyAcorns: false, waves: false, sound: false, intro: false)).testGameWidget(
    '밤 숲 슬라임 왕은 HP 4500, 통나무는 1000만 주고 부서진다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final boss = await add(game, tester, MonsterType.bossSlime, 0, RollingLog.triggerX + 300);
      expect(boss.maxHp, 4500);
      final log = game.logs[0]!;
      await tester.runAsync(() async {
        boss.position.x = RollingLog.triggerX + 40; // 몸 앞쪽이 통나무에 닿는 자리
        for (var i = 0; i < 30; i++) {
          game.update(1 / 60);
          await Future<void>.delayed(Duration.zero);
        }
      });
      expect(log.isMounted, isFalse, reason: '통나무가 부서졌다');
      expect(boss.alive, isTrue);
      expect(boss.hp, 4500 - MonsterType.logDamageToBoss);
      expect(boss.summons, 0, reason: '4500 중 1000은 25% 미만');
    },
  );

  GameTester(noLogs).testGameWidget(
    '여우불은 큰 적의 몸 앞쪽에서 맞는다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final boss = await add(game, tester, MonsterType.bossSlime, 4, 900, moving: false);
      late Fireball ball;
      await tester.runAsync(() async {
        await game.world.add(ball = Fireball(position: Grid.center((row: 4, col: 2)), row: 4));
        game.update(0);
      });
      double? hitAt;
      await tester.runAsync(() async {
        for (var i = 0; i < 120 && ball.isMounted; i++) {
          final x = ball.position.x;
          game.update(1 / 60);
          if (!ball.isMounted || ball.isRemoving) hitAt = x;
          await Future<void>.delayed(Duration.zero);
        }
      });
      expect(boss.hp, boss.maxHp - Fireball.damage);
      expect(hitAt, isNotNull);
      expect(hitAt!, lessThan(900 - 50), reason: '발에서 72px 앞(몸 앞쪽)에서 맞는다');
    },
  );
}
