import 'dart:convert';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/hud/panel.dart';
import 'package:forest_defense/game/monsters.dart';
import 'package:forest_defense/game/progress.dart';
import 'package:forest_defense/game/stages.dart';
import 'package:forest_defense/game/strings.dart';
import 'package:forest_defense/game/units.dart';

import 'support.dart';

/// 14단계: 처음 보는 몬스터 소개, 새 친구 안내.
void main() {
  Future<void> run(ForestGame game, WidgetTester tester, double seconds) => tester.runAsync(() async {
        for (var t = 0.0; t < seconds; t += 1 / 60) {
          game.update(1 / 60);
          await Future<void>.delayed(Duration.zero);
        }
      });

  CenterPanel? panelOf(ForestGame game) => game.world.children.whereType<CenterPanel>().lastOrNull;

  group('진행 저장', () {
    test('처음 하는 사람: 본 몬스터 없음, 놓아 본 친구는 처음 친구 둘', () {
      final p = Progress();
      expect(p.seenMonsters, isEmpty);
      expect(p.usedUnits, Progress.startUnits.toSet());
      expect(p.isNew(UnitType.turtle), isTrue);
    });

    test('본 몬스터·놓아 본 친구가 저장되고 다시 읽힌다', () {
      final p = Progress(stars: {'1-1': 2})
        ..seenMonsters.addAll([MonsterType.slime, MonsterType.wisp])
        ..usedUnits.add(UnitType.turtle);
      final back = Progress.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(back.seenMonsters, {MonsterType.slime, MonsterType.wisp});
      expect(back.usedUnits, {...Progress.startUnits, UnitType.turtle});
    });

    test('14단계 전 저장: 깬 스테이지의 몬스터는 본 것, 열린 친구는 써 본 것으로 (소개 창이 쏟아지지 않게)', () {
      final old = {'stars': {'1-1': 3, '1-2': 1, '1-3': 1}, 'pinecones': 5};
      final p = Progress.fromJson(jsonDecode(jsonEncode(old)) as Map<String, dynamic>);
      final met = {
        for (final s in stages.take(3))
          for (final w in s.waves) ...w.monsters,
      };
      expect(p.seenMonsters, containsAll(met));
      expect(p.seenMonsters, isNot(contains(MonsterType.bossSlime)), reason: '1-5는 아직');
      expect(p.usedUnits, p.unlockedUnits.toSet());
      expect(p.unlockedUnits.any(p.isNew), isFalse);
    });
  });

  var learned = 0;
  ForestGame fresh({List<UnitType>? units}) => ForestGame(
        nestAcorns: false,
        waves: false,
        sound: false,
        intro: false,
        units: units,
        seenMonsters: {},
        usedUnits: {...Progress.startUnits},
        onLearned: () => learned++,
      );

  GameTester(fresh).testGameWidget(
    '처음 보는 몬스터가 나오면 멈추고 소개 창, "알겠어요!"를 누르면 이어 한다. 두 번째부터는 그냥 나온다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      learned = 0;
      await tester.runAsync(() => game.addMonster(MonsterType.slime, row: 2, x: 1000));
      await run(game, tester, 0.2);
      expect(game.state, GameState.notice);
      final panel = panelOf(game)!;
      expect(panel.title, Strings.meetTitle);
      expect(panel.picture, isNotNull);
      expect(panel.lines, [Strings.meetLine(MonsterType.slime), Strings.monsterTip(MonsterType.slime)]);
      expect(game.seenMonsters, {MonsterType.slime});
      expect(learned, 1, reason: '바로 저장');

      final slime = game.monsters.single;
      final x = slime.position.x;
      await run(game, tester, 1);
      expect(slime.position.x, x, reason: '소개 창이 떠 있는 동안 멈춤');
      game.togglePause();
      expect(game.state, GameState.notice, reason: '일시정지 버튼은 소개 중엔 듣지 않는다');

      panel.buttons.single.onPressed();
      await run(game, tester, 0.5);
      expect(game.state, GameState.playing);
      expect(panel.isMounted, isFalse);
      expect(slime.position.x, lessThan(x));

      await tester.runAsync(() => game.addMonster(MonsterType.slime, row: 1, x: 1000));
      await run(game, tester, 0.2);
      expect(game.state, GameState.playing, reason: '이미 본 몬스터');
    },
  );

  GameTester(fresh).testGameWidget(
    '처음 보는 몬스터 둘이 한꺼번에 나오면 차례로 소개하고, 버섯 포자는 작은 버섯까지 함께 소개한다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      await tester.runAsync(() async {
        await game.addMonster(MonsterType.mushroom, row: 1, x: 1000);
        await game.addMonster(MonsterType.wisp, row: 3, x: 1000);
      });
      await run(game, tester, 0.2);
      expect(panelOf(game)!.lines.first, Strings.meetLine(MonsterType.mushroom));
      expect(game.seenMonsters, containsAll([MonsterType.mushroom, MonsterType.miniMushroom, MonsterType.wisp]));
      panelOf(game)!.buttons.single.onPressed();
      await run(game, tester, 0.2);
      expect(game.state, GameState.notice);
      expect(panelOf(game)!.lines.first, Strings.meetLine(MonsterType.wisp));
      panelOf(game)!.buttons.single.onPressed();
      await run(game, tester, 0.2);
      expect(game.state, GameState.playing);
    },
  );

  GameTester(() => ForestGame(nestAcorns: false, sound: false, intro: false, seenMonsters: {}, usedUnits: {...Progress.startUnits}))
      .testGameWidget(
    '첫 웨이브의 첫 몬스터가 처음 보는 몬스터면, 소개 창 뒤에 "몬스터가 오기까지" 막대가 남지 않는다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final bar = game.hud.firstWave!;
      await run(game, tester, 31);
      expect(game.state, GameState.notice);
      expect(bar.isMounted, isFalse);
    },
  );

  GameTester(() => fresh(units: [UnitType.squirrel, UnitType.fox, UnitType.turtle])).testGameWidget(
    '새로 열린 친구 카드에 "새로!" + 아래 말풍선. 처음 놓으면 기억하고 말풍선이 사라진다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      learned = 0;
      expect(game.isNewUnit(UnitType.turtle), isTrue);
      expect(game.isNewUnit(UnitType.fox), isFalse);
      final hint = game.hud.newFriendHint!;
      expect(hint.card.type, UnitType.turtle);
      expect(hint.head, Strings.newFriendHint(UnitType.turtle));
      expect(hint.isMounted, isTrue);
      expect(hint.toRect().left, greaterThanOrEqualTo(0));

      game.garden.acorns = 500;
      await tester.runAsync(() async {
        game.selectCard(UnitType.turtle);
        await game.onCellTapped((row: 2, col: 3));
      });
      expect(game.usedUnits, contains(UnitType.turtle));
      expect(learned, 1);
      await run(game, tester, 0.2);
      expect(hint.isMounted, isFalse);
      expect(game.isNewUnit(UnitType.turtle), isFalse);
    },
  );

  GameTester(() => fresh(units: [UnitType.squirrel, UnitType.fox, UnitType.magpie])).testGameWidget(
    '말풍선은 판이 시작되고 몇 초 뒤 저절로 사라진다 ("새로!"는 놓을 때까지 남는다)',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final hint = game.hud.newFriendHint!;
      await run(game, tester, 10);
      expect(hint.isMounted, isFalse);
      expect(game.isNewUnit(UnitType.magpie), isTrue);
    },
  );

  GameTester(testGame).testGameWidget(
    '기록을 넘기지 않은 판(테스트·확인용)에는 소개 창도 "새로!"도 없다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      expect(game.hud.newFriendHint, isNull);
      expect(game.isNewUnit(UnitType.bear), isFalse);
      await tester.runAsync(() => game.addMonster(MonsterType.golem, row: 2, x: 1000));
      await run(game, tester, 0.2);
      expect(game.state, GameState.playing);
    },
  );
}
