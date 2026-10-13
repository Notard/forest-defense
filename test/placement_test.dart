import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/components/acorn.dart';
import 'package:forest_defense/game/components/unit.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/garden.dart';
import 'package:forest_defense/game/grid.dart';
import 'package:forest_defense/game/hud/layout.dart';
import 'package:forest_defense/game/units.dart';

import 'support.dart';

/// 실제 입력 경로로 카드 고르기 → 칸에 놓기 → 삽으로 치우기 → 도토리 줍기를 확인한다.
void main() {
  Vector2 card(UnitType type) {
    final r = HudLayout.card(type.index);
    return Vector2(r.center.dx, r.center.dy);
  }

  final shovelRect = HudLayout.shovel(UnitType.values.length);
  final shovel = Vector2(shovelRect.center.dx, shovelRect.center.dy);
  const cell = (row: 2, col: 3);

  Future<void> settle(ForestGame game, WidgetTester tester) async {
    // 유닛 그림을 읽고 붙는 동안 실제 시간을 흘린다
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
    }
  }

  GameTester(testGame).testGameWidget(
    '카드를 고르고 칸을 누르면 유닛이 놓이고 도토리가 줄며 쿨다운이 시작된다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      await tapWorld(tester, card(UnitType.fox));
      expect(game.selectedUnit, UnitType.fox);
      await tester.runAsync(() async {
        await tapWorld(tester, Grid.center(cell));
        await settle(game, tester);
      });
      expect(game.garden.unitAt(cell), UnitType.fox);
      expect(game.garden.acorns, Garden.startAcorns - UnitType.fox.cost);
      expect(game.selectedUnit, isNull);
      expect(game.garden.isReady(UnitType.fox), isFalse);
      final unit = game.unitComponents[cell]!;
      expect(unit.isMounted, isTrue);
      expect(unit.position, UnitComponent.footOf(cell));
    },
  );

  GameTester(testGame).testGameWidget(
    '찬 칸에는 놓이지 않고, 같은 카드를 다시 누르면 고르기가 취소된다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      await tester.runAsync(() async {
        await tapWorld(tester, card(UnitType.squirrel));
        await tapWorld(tester, Grid.center(cell));
        await settle(game, tester);
      });
      await tapWorld(tester, card(UnitType.turtle));
      await tapWorld(tester, Grid.center(cell));
      expect(game.garden.unitAt(cell), UnitType.squirrel);
      expect(game.garden.acorns, Garden.startAcorns - UnitType.squirrel.cost);
      expect(game.selectedUnit, UnitType.turtle, reason: '실패하면 고른 카드는 그대로');
      await tapWorld(tester, card(UnitType.turtle));
      expect(game.selectedUnit, isNull);
    },
  );

  GameTester(testGame).testGameWidget(
    '삽을 누르고 유닛이 있는 칸을 누르면 치워진다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      await tester.runAsync(() async {
        await tapWorld(tester, card(UnitType.turtle));
        await tapWorld(tester, Grid.center(cell));
        await settle(game, tester);
      });
      await tapWorld(tester, shovel);
      expect(game.shovelMode, isTrue);
      await tapWorld(tester, Grid.center(cell));
      await tester.pump();
      expect(game.garden.unitAt(cell), isNull);
      expect(game.unitComponents.containsKey(cell), isFalse);
      expect(game.shovelMode, isFalse);
      expect(game.garden.acorns, Garden.startAcorns - UnitType.turtle.cost, reason: '치워도 도토리는 돌려주지 않는다');
    },
  );

  GameTester(testGame).testGameWidget(
    '도토리가 모자라면 카드가 고르기 되지 않는다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      game.garden.acorns = 40;
      await tapWorld(tester, card(UnitType.squirrel));
      expect(game.selectedUnit, isNull);
    },
  );

  GameTester(testGame).testGameWidget(
    '내려앉은 도토리를 누르면 HUD로 날아가 25개가 더해진다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final at = Grid.center((row: 1, col: 5));
      final acorn = Acorn(from: at, landY: at.y);
      await tester.runAsync(() async {
        await game.world.add(acorn);
        await settle(game, tester);
      });
      await tapWorld(tester, at);
      for (var i = 0; i < 40; i++) {
        game.update(1 / 60); // 실제 화면처럼 한 프레임씩 (날아가는 효과 0.45초)
      }
      await tester.pump();
      expect(game.garden.acorns, Garden.startAcorns + Garden.acornValue);
      expect(acorn.isMounted, isFalse);
    },
  );
}
