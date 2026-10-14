import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/components/fireball.dart';
import 'package:forest_defense/game/components/level_bubble.dart';
import 'package:forest_defense/game/components/unit.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/grid.dart';
import 'package:forest_defense/game/monsters.dart';
import 'package:forest_defense/game/sfx.dart';
import 'package:forest_defense/game/units.dart';

import 'support.dart';

/// 12-2단계 판 안 레벨업: 친구를 누르면 말풍선, 말풍선을 누르면 도토리를 내고 Lv2·Lv3.
void main() {
  Future<UnitComponent> place(ForestGame game, WidgetTester tester, UnitType type, Cell cell) async {
    await tester.runAsync(() async {
      game.selectedUnit = type;
      await game.onCellTapped(cell);
      game.update(0);
    });
    return game.unitComponents[cell]!;
  }

  /// 칸을 누르고(말풍선 붙이기) 그림을 읽을 실제 시간을 준다.
  Future<void> tapCell(ForestGame game, WidgetTester tester, Cell cell) async {
    await tapWorld(tester, Grid.center(cell));
    await tester.runAsync(() async {
      for (var i = 0; i < 5; i++) {
        game.update(1 / 60);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
  }

  test('레벨 값: Lv2는 친구 값, Lv3는 1.5배를 5 단위로 반올림', () {
    expect({for (final t in UnitType.values) t.name: ForestGame.costToLevel(t, 1)},
        {for (final t in UnitType.values) t.name: t.cost});
    expect({for (final t in UnitType.values) t.name: ForestGame.costToLevel(t, 2)},
        {'squirrel': 75, 'fox': 150, 'turtle': 75, 'skunk': 225, 'hedgehog': 115, 'owl': 190, 'bear': 265, 'magpie': 75});
  });

  GameTester(testGame).testGameWidget(
    '친구를 누르면 말풍선, 말풍선을 누르면 도토리를 내고 Lv2 (여우불 1.4배), 다시 Lv3 (1.8배)',
    setUp: waitForLoad,
    verify: (game, tester) async {
      game.garden.acorns = 1000;
      final fox = await place(game, tester, UnitType.fox, (row: 2, col: 2));
      final acornsAfterPlace = game.garden.acorns;
      await tapCell(game, tester, fox.cell);
      final bubble = game.bubble!;
      expect(bubble.unit, fox);
      expect(bubble.cost, 100);

      await tapWorld(tester, bubble.absoluteCenter);
      expect(fox.level, 2);
      expect(game.garden.acorns, acornsAfterPlace - 100);
      expect(game.bubble, isNull, reason: '올리면 닫힌다');
      expect(game.sfx.played.last, Sfx.levelUp);

      await tapCell(game, tester, fox.cell);
      expect(game.bubble!.cost, 150);
      await tapWorld(tester, game.bubble!.absoluteCenter);
      expect(fox.level, 3);
      expect(fox.power, closeTo(1.8, 1e-9));

      await tapCell(game, tester, fox.cell);
      expect(game.bubble, isNull, reason: 'Lv3이면 말풍선이 뜨지 않는다');

      // 진짜 여우불이 1.8배
      await tester.runAsync(() async {
        await game.addMonster(MonsterType.golem, row: 2, x: Grid.center((row: 2, col: 6)).x, moving: false);
        for (var t = 0.0; t < 1.6; t += 1 / 60) {
          game.update(1 / 60);
          await Future<void>.delayed(Duration.zero);
        }
      });
      final golem = game.monsters.single;
      expect(golem.hp, closeTo(golem.maxHp - Fireball.damage * 1.8, 1e-6));
    },
  );

  GameTester(testGame).testGameWidget(
    '같은 친구를 다시 누르거나 카드를 고르면 닫힌다, 도토리가 모자라면 오르지 않는다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      game.garden.acorns = 1000;
      final fox = await place(game, tester, UnitType.fox, (row: 3, col: 4));
      await tapCell(game, tester, fox.cell);
      expect(game.bubble, isNotNull);
      await tapCell(game, tester, fox.cell);
      expect(game.bubble, isNull);

      await tapCell(game, tester, fox.cell);
      game.selectCard(UnitType.squirrel);
      expect(game.bubble, isNull);
      game.selectCard(UnitType.squirrel); // 고르기 취소

      game.garden.acorns = 99;
      await tapCell(game, tester, fox.cell);
      expect(game.levelUp(fox), isFalse);
      expect(fox.level, 1);
      expect(game.garden.acorns, 99);
    },
  );

  GameTester(testGame).testGameWidget(
    '거북이는 Lv마다 체력이 늘고 받은 피해는 그대로, 스컨크는 레벨이 없다, 맨 윗줄은 말풍선이 발 아래',
    setUp: waitForLoad,
    verify: (game, tester) async {
      game.garden.acorns = 10000;
      final turtle = await place(game, tester, UnitType.turtle, (row: 0, col: 1));
      turtle.takeDamage(1000);
      expect(game.levelUp(turtle), isTrue);
      expect(turtle.maxHp, (UnitType.turtle.maxHp * 1.4).round());
      expect(turtle.hp, turtle.maxHp - 1000);

      await tapCell(game, tester, turtle.cell);
      final bubble = game.bubble!;
      expect(bubble.below, isTrue);
      expect(bubble.absoluteTopLeftPosition.y, greaterThan(LevelBubble.hudBottom));

      final skunk = await place(game, tester, UnitType.skunk, (row: 4, col: 8));
      expect(skunk.canLevel, isFalse);
      expect(game.levelUp(skunk), isFalse);
      expect(game.unitComponents.values.whereType<Turtle>().single.level, 2);
    },
  );

  test('레벨업 별은 시간이 지난 프레임에 그려도 곡선 계산이 0~1을 넘지 않는다 (웹에서 페이지가 멈춘 버그)', () {
    final sparkle = LevelSparkle(position: Vector2.zero());
    sparkle.update(LevelSparkle.duration + 0.05); // 지울 차례지만 이번 프레임에는 아직 그려진다
    final recorder = PictureRecorder();
    sparkle.render(Canvas(recorder)); // 고치기 전: Curves.easeOut.transform(1.09) → 디버그는 assert, 릴리스는 무한 반복
    recorder.endRecording();
  });
}
