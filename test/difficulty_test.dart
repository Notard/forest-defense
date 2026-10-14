import 'dart:convert';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/difficulty.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/hud/layout.dart';
import 'package:forest_defense/game/hud/title.dart';
import 'package:forest_defense/game/monsters.dart';
import 'package:forest_defense/game/progress.dart';
import 'package:forest_defense/game/stages.dart';
import 'package:forest_defense/menu/menu_game.dart';

import 'support.dart';

/// 14-4단계: 난이도 쉬움·보통·어려움.
void main() {
  test('보통은 지금 게임 그대로, 쉬움은 약하고 하트 다섯, 어려움은 세다', () {
    expect(Difficulty.normal.hp, 1);
    expect(Difficulty.normal.speed, 1);
    expect(Difficulty.normal.extraAcorns, 0);
    expect(Difficulty.normal.hearts, ForestGame.startHearts);
    expect(Difficulty.easy.hp, lessThan(1));
    expect(Difficulty.easy.hearts, greaterThan(3));
    expect(Difficulty.hard.hp, greaterThan(1));
    expect(Difficulty.hard.speed, greaterThan(1));
  });

  test('난이도는 저장되고, 예전 저장(난이도 없음)은 보통', () {
    final p = Progress(difficulty: Difficulty.hard);
    final back = Progress.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
    expect(back.difficulty, Difficulty.hard);
    expect(Progress.fromJson({'stars': {}}).difficulty, Difficulty.normal);
    expect(Progress().difficulty, Difficulty.normal);
  });

  for (final d in Difficulty.values) {
    GameTester(() => ForestGame(stage: stageById('1-2'), nestAcorns: false, waves: false, sound: false, intro: false, difficulty: d))
        .testGameWidget(
      '${d.name}: 몬스터 HP·투구·빠르기, 시작 도토리, 하트가 난이도대로',
      setUp: waitForLoad,
      verify: (game, tester) async {
        expect(game.garden.acorns, stageById('1-2').startAcorns + d.extraAcorns);
        expect(game.hearts, d.hearts);
        expect(game.maxHearts, d.hearts);
        expect(game.lostHeart, isFalse);
        final helmet = (await tester.runAsync(() => game.addMonster(MonsterType.helmetSlime, row: 2, x: 1000)))!;
        expect(helmet.maxHp, (MonsterType.helmetSlime.hp * d.hp).round());
        expect(helmet.helmetHp, (MonsterType.helmetSlime.helmetHp * d.hp).roundToDouble());
        expect(helmet.speed, closeTo(108 / MonsterType.helmetSlime.secondsPerCell * d.speed, 1e-9));

        // 하트가 아래 띠 웨이브 이름과 "몬스터가 오기까지" 사이에 들어간다
        final hearts = game.hud.hearts;
        expect(hearts.toRect().right, lessThanOrEqualTo(HudLayout.firstWave.left));
        expect(hearts.toRect().left, greaterThanOrEqualTo(HudLayout.hearts.left - 1));
      },
    );
  }

  GameTester(() => ForestGame(nestAcorns: false, waves: false, sound: false, intro: false, difficulty: Difficulty.easy)).testGameWidget(
    '쉬움: 하트 다섯 중 하나를 잃어도 ★★는 안 된다 (하트를 안 잃어야)',
    setUp: waitForLoad,
    verify: (game, tester) async {
      await tester.runAsync(() => game.addMonster(MonsterType.slime, row: 2, x: 140));
      await tester.runAsync(() async {
        for (var i = 0; i < 120; i++) {
          game.update(1 / 60);
          await Future<void>.delayed(Duration.zero);
        }
      });
      expect(game.hearts, 4);
      expect(game.lostHeart, isTrue);
      expect(game.state, GameState.playing);
    },
  );

  GameTester(() => MenuGame(progress: Progress(), onPlay: (_) {}, sound: false)).testGameWidget(
    '메인 화면에서 난이도를 누르면 바뀌고 진행에 남는다',
    setUp: (game, tester) async {
      for (var i = 0; i < 300 && !game.world.children.whereType<TitleScreen>().any((t) => t.isMounted); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    },
    verify: (game, tester) async {
      final picker = game.world.descendants().whereType<DifficultyPicker>().single;
      expect(picker.selected, Difficulty.normal);
      final pills = picker.children.whereType<PositionComponent>().toList();
      expect(pills, hasLength(3));
      // 부제(y 278)와 게임 시작 버튼(위 끝 390) 사이
      expect(picker.toRect().top, greaterThan(300));
      expect(picker.toRect().bottom, lessThan(385));
      await tapWorld(tester, pills[0].absoluteCenter);
      expect(picker.selected, Difficulty.easy);
      expect(game.progress.difficulty, Difficulty.easy);
      await tapWorld(tester, pills[2].absoluteCenter);
      expect(game.progress.difficulty, Difficulty.hard);
    },
  );
}
