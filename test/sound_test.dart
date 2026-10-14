import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/components/acorn.dart';
import 'package:forest_defense/game/components/monster.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/grid.dart';
import 'package:forest_defense/game/hud/layout.dart';
import 'package:forest_defense/game/monsters.dart';
import 'package:forest_defense/game/sfx.dart';
import 'package:forest_defense/game/units.dart';
import 'package:flame/components.dart';

import 'support.dart';

/// 사건마다 맞는 효과음을 내는지 (plan.md 8단계). 테스트에는 오디오가 없어 소리 기록만 본다.
void main() {
  Future<void> real(ForestGame game, WidgetTester tester, double seconds) => tester.runAsync(() async {
        for (var t = 0.0; t < seconds; t += 1 / 60) {
          game.update(1 / 60);
          await Future<void>.delayed(Duration.zero);
        }
      });

  GameTester(testGame).testGameWidget(
    '놓기 · 줍기 · 발사 · 명중 · 쓰러짐 · 투구 · 폭발 · 통나무 소리',
    setUp: waitForLoad,
    verify: (game, tester) async {
      game.garden.acorns = 10000;
      await tester.runAsync(() async {
        game.selectedUnit = UnitType.fox;
        await game.onCellTapped((row: 1, col: 1));
        await game.addMonster(MonsterType.helmetSlime, row: 1, x: 700, moving: false);
        final at = Grid.center((row: 3, col: 4));
        await game.world.add(Acorn(from: at, landY: at.y));
        game.update(0);
      });
      expect(game.sfx.played, [Sfx.place]);

      await tapWorld(tester, Grid.center((row: 3, col: 4)));
      expect(game.sfx.played.last, Sfx.pickup);

      await real(game, tester, 1.2); // 여우가 쏘고 맞힌다
      expect(game.sfx.played, containsAll([Sfx.shot, Sfx.hit]));

      game.monsters.single.takeDamage(400); // 투구 370을 넘겨 깬다
      expect(game.sfx.played.last, Sfx.helmet);
      game.monsters.single.takeDamage(1000);
      expect(game.sfx.played.last, Sfx.slimeDie);

      await tester.runAsync(() async {
        game.selectedUnit = UnitType.skunk;
        await game.onCellTapped((row: 4, col: 6));
      });
      await real(game, tester, 1.6);
      expect(game.sfx.played, contains(Sfx.boom));

      await tester.runAsync(() async {
        await game.addMonster(MonsterType.slime, row: 0, x: Monster.reachedHomeX - 1); // 둥지 바로 안쪽
        game.update(1 / 60);
        game.update(1 / 60);
      });
      expect(game.sfx.played.last, Sfx.nest);
    },
  );

  GameTester(testGame).testGameWidget(
    '소리 버튼을 누르면 꺼지고, 꺼진 동안은 소리를 내지 않는다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final sound = HudLayout.sound.center;
      await tapWorld(tester, Vector2(sound.dx, sound.dy));
      expect(game.sfx.muted, isTrue);
      game.sfx.play(Sfx.pickup);
      expect(game.sfx.played, isEmpty);
      await tapWorld(tester, Vector2(sound.dx, sound.dy));
      game.sfx.play(Sfx.pickup);
      expect(game.sfx.played, [Sfx.pickup]);
    },
  );

  test('같은 소리는 최소 간격 안에 다시 나지 않는다 (여러 마리가 한꺼번에 맞을 때)', () {
    final board = SoundBoard(enabled: false);
    for (var i = 0; i < 5; i++) {
      board.play(Sfx.hit);
    }
    board.play(Sfx.pickup);
    expect(board.played, [Sfx.hit, Sfx.pickup]);
  });
}
