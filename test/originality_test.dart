import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/components/acorn.dart';
import 'package:forest_defense/game/components/monster.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/garden.dart';
import 'package:forest_defense/game/grid.dart';
import 'package:forest_defense/game/monsters.dart';
import 'package:forest_defense/game/stages.dart';
import 'package:forest_defense/game/units.dart';

import 'support.dart';

/// 14-1단계 우리 게임만의 규칙: 몬스터가 떨어뜨리는 도토리, 둥지 문 도토리, 까치.
void main() {
  Future<void> run(ForestGame game, WidgetTester tester, double seconds) => tester.runAsync(() async {
        for (var t = 0.0; t < seconds; t += 1 / 60) {
          game.update(1 / 60);
          await Future<void>.delayed(Duration.zero);
        }
      });

  List<Acorn> acorns(ForestGame game) => game.world.children.whereType<Acorn>().toList();

  GameTester(testGame).testGameWidget(
    '쓰러진 몬스터는 종류만큼 도토리를 떨어뜨리고, 눌러 주우면 그만큼 더해진다 (둥지에 닿은 몬스터는 안 떨어뜨림)',
    setUp: waitForLoad,
    verify: (game, tester) async {
      late Monster golem;
      await tester.runAsync(() async {
        golem = await game.addMonster(MonsterType.golem, row: 2, x: Grid.center((row: 2, col: 5)).x, moving: false);
        await game.addMonster(MonsterType.slime, row: 3, x: Monster.reachedHomeX - 1);
      });
      golem.takeDamage(10000);
      await run(game, tester, 1.0);
      final drops = acorns(game);
      expect(drops, hasLength(1), reason: '둥지에 닿은 슬라임은 떨어뜨리지 않는다');
      final drop = drops.single;
      expect(drop.value, MonsterType.golem.acornDrop);
      expect(drop.landed, isTrue);
      expect(drop.lane, 2);
      final before = game.garden.acorns;
      drop.collect();
      await run(game, tester, 0.6);
      expect(game.garden.acorns, before + MonsterType.golem.acornDrop);
    },
  );

  GameTester(() => ForestGame(waves: false, sound: false, intro: false)).testGameWidget(
    '둥지 문에서 도토리가 굴러 나와 첫 칸 근처에 떨어진다 (하늘에서 떨어지지 않는다)',
    setUp: waitForLoad,
    verify: (game, tester) async {
      await run(game, tester, demoStage.nestEvery * 1.2 + 4.5);
      final found = acorns(game);
      expect(found, isNotEmpty);
      for (final a in found) {
        expect(a.value, Garden.acornValue);
        expect(a.position.x, lessThan(Grid.center((row: 0, col: 1)).x), reason: '첫 칸 근처');
      }
    },
  );

  GameTester(testGame).testGameWidget(
    '까치는 자기 레인과 위아래 한 레인의 도토리만 물어 온다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      game.garden.acorns = 1000;
      await tester.runAsync(() async {
        game.selectedUnit = UnitType.magpie;
        await game.onCellTapped((row: 2, col: 1));
        game.update(0);
      });
      final near = Acorn.popped(from: Grid.center((row: 3, col: 4)), toX: Grid.center((row: 3, col: 4)).x, landY: Grid.laneCenterY(3) + 18);
      final far = Acorn.popped(from: Grid.center((row: 0, col: 4)), toX: Grid.center((row: 0, col: 4)).x, landY: Grid.laneCenterY(0) + 18);
      await tester.runAsync(() async {
        await game.world.addAll([near, far]);
      });
      final before = game.garden.acorns;
      await run(game, tester, 3);
      expect(near.isMounted, isFalse, reason: '물어 왔다');
      expect(far.isMounted, isTrue, reason: '두 레인 위는 못 줍는다');
      expect(game.garden.acorns, before + Garden.acornValue);
    },
  );
}
