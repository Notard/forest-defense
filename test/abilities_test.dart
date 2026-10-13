import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/components/acorn.dart';
import 'package:forest_defense/game/components/fireball.dart';
import 'package:forest_defense/game/components/flyers.dart';
import 'package:forest_defense/game/components/unit.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/grid.dart';
import 'package:forest_defense/game/monsters.dart';
import 'package:forest_defense/game/units.dart';

import 'support.dart';

/// 유닛 능력 (plan.md 5단계). 그림을 실제로 읽은 뒤 게임 시계를 한 프레임(1/60초)씩 흘려 확인한다.
void main() {
  Future<UnitComponent> place(ForestGame game, WidgetTester tester, UnitType type, Cell cell) async {
    game.garden.acorns = 10000;
    await tester.runAsync(() async {
      game.selectedUnit = type;
      await game.onCellTapped(cell);
      game.update(0); // 붙이기 처리
    });
    return game.unitComponents[cell]!;
  }

  Future<void> addMonster(ForestGame game, WidgetTester tester, MonsterType type, Cell cell) async {
    await tester.runAsync(() async {
      await game.addMonster(type, row: cell.row, x: Grid.center(cell).x, moving: false);
      game.update(0);
    });
  }

  void run(ForestGame game, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      game.update(1 / 60);
    }
  }

  /// 프레임 사이에 새로 붙는 컴포넌트(여우불·도토리·연기)의 onLoad가 끝나도록 실제 시간을 조금씩 흘린다.
  Future<void> runAsync(ForestGame game, WidgetTester tester, double seconds) async {
    await tester.runAsync(() async {
      for (var t = 0.0; t < seconds; t += 1 / 60) {
        game.update(1 / 60);
        await Future<void>.delayed(Duration.zero);
      }
    });
  }

  int count<T>(ForestGame game) => game.world.children.whereType<T>().length;

  GameTester(testGame).testGameWidget(
    '여우는 같은 레인 앞에 몬스터가 있을 때만 쏘고, 여우불은 가장 가까운 몬스터에게 20 피해',
    setUp: waitForLoad,
    verify: (game, tester) async {
      await place(game, tester, UnitType.fox, (row: 2, col: 1));
      await addMonster(game, tester, MonsterType.slime, (row: 1, col: 6)); // 다른 레인
      await addMonster(game, tester, MonsterType.slime, (row: 2, col: 0)); // 여우 뒤
      run(game, 3);
      expect(count<Fireball>(game), 0, reason: '앞에 몬스터가 없으면 쏘지 않는다');

      await addMonster(game, tester, MonsterType.slime, (row: 2, col: 5));
      await addMonster(game, tester, MonsterType.slime, (row: 2, col: 8));
      await runAsync(game, tester, 0.5); // 공격 5번째 프레임(0.33초)에 발사
      expect(count<Fireball>(game), 1);
      await runAsync(game, tester, 1.0); // 날아가 맞힘
      final near = game.monsters.firstWhere((m) => m.row == 2 && m.position.x > 400 && m.position.x < 800);
      final far = game.monsters.firstWhere((m) => m.row == 2 && m.position.x > 900);
      expect(near.hp, MonsterType.slime.hp - Fireball.damage);
      expect(far.hp, MonsterType.slime.hp, reason: '여우불은 처음 닿는 몬스터 하나만 맞힌다');
      final other = game.monsters.firstWhere((m) => m.row == 1);
      expect(other.hp, MonsterType.slime.hp);
    },
  );

  GameTester(testGame).testGameWidget(
    '다람쥐는 놓고 firstDelay초 뒤 도토리를 만들어 옆에 떨어뜨린다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final squirrel = await place(game, tester, UnitType.squirrel, (row: 1, col: 2));
      await tester.runAsync(() async => game.update(0)); // 도토리 그림 읽기용
      run(game, Squirrel.firstDelay - 0.1);
      expect(count<Acorn>(game), 0);
      await tester.runAsync(() async {
        run(game, 0.6); // 만들기 5번째 프레임 = 첫 생산 + 0.33초
        await Future<void>.delayed(const Duration(milliseconds: 50));
        game.update(0);
      });
      final acorns = game.world.children.whereType<Acorn>().toList();
      expect(acorns, hasLength(1));
      run(game, 1.5);
      expect(acorns.single.landed, isTrue);
      expect(acorns.single.position.x, greaterThan(squirrel.position.x));
      expect(acorns.single.position.x, lessThan(squirrel.position.x + 70));
    },
  );

  GameTester(testGame).testGameWidget(
    '스컨크는 1.2초 부푼 뒤 터져 주변 3 × 3칸 몬스터만 쓰러뜨리고 칸을 비운다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      const at = (row: 2, col: 4);
      await place(game, tester, UnitType.skunk, at);
      await addMonster(game, tester, MonsterType.slime, (row: 2, col: 5)); // 바로 옆
      await addMonster(game, tester, MonsterType.helmetSlime, (row: 3, col: 5)); // 대각선 (투구 370 + 200)
      await addMonster(game, tester, MonsterType.slime, (row: 4, col: 5)); // 두 레인 아래
      await addMonster(game, tester, MonsterType.slime, (row: 2, col: 7)); // 세 칸 오른쪽
      await tester.runAsync(() async {
        run(game, 1.6);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        run(game, 1.0);
      });
      final alive = game.monsters.map((m) => (row: m.row, col: Grid.cellAt(m.position.clone()..y = Grid.laneCenterY(m.row))!.col)).toSet();
      expect(alive, {(row: 4, col: 5), (row: 2, col: 7)});
      expect(game.garden.unitAt(at), isNull);
      expect(game.unitComponents.containsKey(at), isFalse);
    },
  );

  GameTester(testGame).testGameWidget(
    '거북이는 HP 절반 아래에서 금 간 등껍질이 되고, 0이 되면 칸이 빈다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      const at = (row: 0, col: 3);
      final turtle = await place(game, tester, UnitType.turtle, at) as Turtle;
      turtle.takeDamage(1900);
      run(game, 0.5);
      expect(turtle.current, 'idle');
      turtle.takeDamage(200);
      run(game, 0.5);
      expect(turtle.cracked, isTrue);
      expect(turtle.current, 'idle_cracked');
      turtle.takeDamage(5000);
      expect(game.garden.unitAt(at), isNull);
      expect(turtle.current, 'death');
    },
  );

  GameTester(testGame).testGameWidget(
    '투구 슬라임은 투구가 먼저 맞고, 투구가 깨지면 투구가 날아가며 슬라임 그림으로 바뀐다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      await addMonster(game, tester, MonsterType.helmetSlime, (row: 1, col: 6));
      final m = game.monsters.single;
      final helmet = MonsterType.helmetSlime.helmetHp, body = MonsterType.helmetSlime.hp;
      m.takeDamage(helmet - 30.0);
      expect(m.hp, body);
      expect(m.hasHelmet, isTrue);
      await tester.runAsync(() async {
        m.takeDamage(100); // 투구 남은 30 + 몸 70
        await Future<void>.delayed(const Duration(milliseconds: 50));
        game.update(0);
      });
      expect(m.hasHelmet, isFalse);
      expect(m.hp, body - 70);
      expect(m.art.name, 'slime');
      expect(count<FlyingHelmet>(game), 1);
    },
  );
}
