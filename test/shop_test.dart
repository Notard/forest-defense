import 'package:flame/extensions.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/components/fireball.dart';
import 'package:forest_defense/game/components/unit.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/garden.dart';
import 'package:forest_defense/game/grid.dart';
import 'package:forest_defense/game/monsters.dart';
import 'package:forest_defense/game/progress.dart';
import 'package:forest_defense/game/stages.dart';
import 'package:forest_defense/game/units.dart';
import 'package:forest_defense/game/upgrades.dart';
import 'package:forest_defense/menu/menu_game.dart';
import 'package:forest_defense/menu/shop_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

/// 12단계 강화 상점: 사기 규칙, 판 안 수치, 상점 화면.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('사기 규칙', () {
    test('값은 15·30·50 (시작 도토리 20·40·60), 3단계가 끝', () {
      final p = Progress(pinecones: 1000);
      expect([for (var i = 0; i < 3; i++) Upgrade.fox.costAt(i)], [15, 30, 50]);
      expect(Upgrade.startAcorns.costs, [20, 40, 60]);
      for (var i = 0; i < 3; i++) {
        expect(p.buy(Upgrade.fox), isTrue);
      }
      expect(p.levelOf(Upgrade.fox), 3);
      expect(p.pinecones, 1000 - 95);
      expect(p.buy(Upgrade.fox), isFalse, reason: '최고 단계');
      expect(p.pinecones, 1000 - 95);
    });

    test('솔방울이 모자라거나 아직 못 만난 유닛은 살 수 없다', () {
      final p = Progress(pinecones: 14);
      expect(p.buy(Upgrade.fox), isFalse);
      p.pinecones = 100;
      expect(p.isAvailable(Upgrade.turtle), isFalse, reason: '거북이는 1-1을 깨야');
      expect(p.buy(Upgrade.turtle), isFalse);
      expect(p.buy(Upgrade.startAcorns), isTrue, reason: '시작 도토리는 처음부터');
      p.record(stageById('1-1'), won: true, lostHeart: false, lostUnit: false);
      expect(p.buy(Upgrade.turtle), isTrue);
    });

    test('전부 사려면 785개 (다 살 수는 없다, 별 30개로 약 340개)', () {
      final total = Upgrade.values.fold<int>(0, (a, u) => a + u.costs.fold(0, (b, c) => b + c));
      expect(total, 785);
    });

    test('산 단계는 저장되고 다시 읽힌다', () async {
      final p = Progress(pinecones: 100);
      p.buy(Upgrade.squirrel);
      p.buy(Upgrade.startAcorns);
      await p.save();
      final q = await Progress.load();
      expect(q.levelOf(Upgrade.squirrel), 1);
      expect(q.levelOf(Upgrade.startAcorns), 1);
      expect(q.pinecones, 100 - 15 - 20);
    });

    test('강화 단계가 수치로 바뀐다', () {
      const b = Boosts({Upgrade.squirrel: 2, Upgrade.fox: 3, Upgrade.turtle: 1, Upgrade.hedgehog: 1,
          Upgrade.skunk: 2, Upgrade.owl: 3, Upgrade.bear: 1, Upgrade.startAcorns: 2});
      expect(b.squirrelInterval, closeTo(0.8, 1e-9));
      expect(b.foxDamage, closeTo(1.45, 1e-9));
      expect(b.maxHpOf(UnitType.turtle), 5000);
      expect(b.maxHpOf(UnitType.fox), UnitType.fox.maxHp);
      expect(b.spineDamage, closeTo(1.3, 1e-9));
      expect(b.cooldownOf(UnitType.skunk), closeTo(UnitType.skunk.cooldown * 0.7, 1e-9));
      expect(b.cooldownOf(UnitType.fox), UnitType.fox.cooldown);
      expect(b.owlSlowExtra, 3);
      expect(b.bearDamage, closeTo(1.2, 1e-9));
      expect(b.extraAcorns, 50);
      expect(Boosts.none.foxDamage, 1);
    });
  });

  const boosts = Boosts({Upgrade.fox: 2, Upgrade.turtle: 2, Upgrade.skunk: 1, Upgrade.startAcorns: 3});
  GameTester(() => ForestGame(nestAcorns: false, waves: false, sound: false, intro: false, boosts: boosts)).testGameWidget(
    '판 안: 시작 도토리 +75, 거북이 HP +50%, 스컨크 쿨다운 -15%, 여우불 +30%',
    setUp: waitForLoad,
    verify: (game, tester) async {
      expect(game.garden.acorns, Garden.startAcorns + 75);
      game.garden.acorns = 10000;
      await tester.runAsync(() async {
        game.selectedUnit = UnitType.turtle;
        await game.onCellTapped((row: 0, col: 1));
        game.selectedUnit = UnitType.skunk;
        await game.onCellTapped((row: 4, col: 8));
        game.update(0);
      });
      final turtle = game.unitComponents[(row: 0, col: 1)]!;
      expect(turtle.maxHp, 6000);
      expect(turtle.hp, 6000);
      expect(game.garden.cooldownLeft(UnitType.skunk), closeTo(UnitType.skunk.cooldown * 0.85, 1e-9));
      expect(turtle, isA<Turtle>());

      // 진짜 여우가 쏜 여우불이 1.3배로 맞는다
      await tester.runAsync(() async {
        game.selectedUnit = UnitType.fox;
        await game.onCellTapped((row: 2, col: 1));
        await game.addMonster(MonsterType.slime, row: 2, x: Grid.center((row: 2, col: 5)).x, moving: false);
        for (var t = 0.0; t < 1.6; t += 1 / 60) {
          game.update(1 / 60);
          await Future<void>.delayed(Duration.zero);
        }
      });
      expect(game.monsters.single.hp, closeTo(MonsterType.slime.hp - Fireball.damage * 1.3, 1e-6));
    },
  );

  GameTester(() => MenuGame(
        progress: Progress(pinecones: 40, stars: {'1-1': 3}),
        onPlay: (_) {},
        startPage: MenuPage.shop,
        sound: false,
      )).testGameWidget(
    '상점에서 여우 카드를 누르면 솔방울 15를 내고 1단계, 잠긴 고슴도치는 그대로',
    setUp: (game, tester) async {
      for (var i = 0; i < 300 && !game.world.children.whereType<ShopScreen>().any((s) => s.isMounted && s.children.whereType<UpgradeCard>().length == 8); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    },
    verify: (game, tester) async {
      Vector2 card(Upgrade u) => ShopScreen.cardRect(u.index).center.toVector2();
      await tapWorld(tester, card(Upgrade.fox));
      expect(game.progress.levelOf(Upgrade.fox), 1);
      expect(game.progress.pinecones, 25);
      await tapWorld(tester, card(Upgrade.hedgehog));
      expect(game.progress.levelOf(Upgrade.hedgehog), 0);
      expect(game.progress.pinecones, 25);
      await tapWorld(tester, card(Upgrade.turtle)); // 1-1을 깨서 열림
      expect(game.progress.levelOf(Upgrade.turtle), 1);
      expect(game.progress.pinecones, 10);
      await tapWorld(tester, card(Upgrade.fox)); // 30 모자람
      expect(game.progress.levelOf(Upgrade.fox), 1);
    },
  );
}
