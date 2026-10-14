import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/components/monster.dart';
import 'package:forest_defense/game/config.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/grid.dart';
import 'package:forest_defense/game/hud/panel.dart';
import 'package:forest_defense/game/monsters.dart';
import 'package:forest_defense/game/progress.dart';
import 'package:forest_defense/game/stages.dart';
import 'package:forest_defense/game/strings.dart';
import 'package:forest_defense/game/units.dart';

import 'support.dart';

/// 스테이지 정의로 시작하는 판 (9단계): 레인, 카드, 별 판정, 결과.
void main() {
  Future<void> real(ForestGame game, WidgetTester tester, double seconds) => tester.runAsync(() async {
        for (var t = 0.0; t < seconds; t += 1 / 60) {
          game.update(1 / 60);
          await Future<void>.delayed(Duration.zero);
        }
      });

  final s11 = stageById('1-1');

  GameTester(() => ForestGame(stage: s11, units: Progress().unlockedUnits, nestAcorns: false, waves: false, sound: false, intro: false))
      .testGameWidget(
    '1-1은 가운데 세 레인만: 바깥 레인에는 놓을 수 없다, 카드는 다람쥐·여우뿐',
    setUp: waitForLoad,
    verify: (game, tester) async {
      expect(game.hud.cards.map((c) => c.type), [UnitType.squirrel, UnitType.fox]);
      await tester.runAsync(() async {
        game.selectedUnit = UnitType.squirrel;
        await game.onCellTapped((row: 0, col: 0));
      });
      expect(game.garden.unitAt((row: 0, col: 0)), isNull);
      await tester.runAsync(() async {
        await game.onCellTapped((row: 1, col: 0));
      });
      expect(game.garden.unitAt((row: 1, col: 0)), UnitType.squirrel);
    },
  );

  GameTester(testGame).testGameWidget(
    '몬스터에게 동물을 잃으면 lostUnit, 둥지에 닿으면 lostHeart (삽은 잃은 것이 아니다)',
    setUp: waitForLoad,
    verify: (game, tester) async {
      game.garden.acorns = 1000;
      await tester.runAsync(() async {
        game.selectedUnit = UnitType.squirrel;
        await game.onCellTapped((row: 0, col: 3));
        game.toggleShovel();
        await game.onCellTapped((row: 0, col: 3));
      });
      expect(game.lostUnit, isFalse, reason: '삽으로 치운 것은 괜찮다');
      expect(game.lostHeart, isFalse);

      await tester.runAsync(() async {
        game.selectedUnit = UnitType.fox; // 다람쥐는 쿨다운 중
        await game.onCellTapped((row: 2, col: 3));
        game.update(0);
      });
      game.unitComponents[(row: 2, col: 3)]!.takeDamage(10000);
      expect(game.lostUnit, isTrue);

      expect(game.lostHeart, isFalse);
      await tester.runAsync(() async {
        await game.addMonster(MonsterType.slime, row: 4, x: Monster.reachedHomeX - 1); // 둥지 바로 안쪽
        game.update(1 / 60);
        game.update(1 / 60);
      });
      expect(game.lostHeart, isTrue);
    },
  );

  GameTester(() => ForestGame(
        stage: s11,
        nestAcorns: false,
        sound: false,
        intro: false,
        onFinish: ({required won, required lostHeart, required lostUnit}) =>
            Progress().record(s11, won: won, lostHeart: lostHeart, lostUnit: lostUnit),
      )).testGameWidget(
    '1-1을 깨면 결과 판에 별 3개, 솔방울, 새 친구(거북이)가 나온다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      // 나오는 대로 쓰러뜨린다 (둥지에 닿기 전에)
      await tester.runAsync(() async {
        for (var t = 0.0; t < 200 && game.state == GameState.playing; t += 1 / 30) {
          game.update(1 / 30);
          for (final m in game.monsters.toList()) {
            if (m.position.x < Monster.reachedHomeX + 200) m.takeDamage(10000);
          }
          await Future<void>.delayed(Duration.zero);
        }
      });
      expect(game.state, GameState.won);
      expect(game.reward!.stars, 3);
      await real(game, tester, 0.2);
      final panel = game.world.children.whereType<CenterPanel>().single;
      expect(panel.stars, 3);
      expect(panel.lines, contains(Strings.pineconesGained(30)));
      expect(panel.lines, contains(Strings.newFriend(UnitType.turtle)));
      expect(panel.buttons.map((b) => b.label), [Strings.toMap, Strings.retry, Strings.next]);
    },
  );

  test('1-1 웨이브는 가운데 세 레인에서만 나온다', () {
    // WaveDirector는 스테이지 레인에서만 고른다
    expect(s11.waves.expand((w) => w.monsters).toSet(), {MonsterType.slime});
    expect(Grid.allCells.where((c) => s11.lanes.contains(c.row)), hasLength(3 * GameConfig.cols));
  });
}
