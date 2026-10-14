/// 난이도별 자동 플레이 (14-4단계). 도착 상태는 [arrivingAt]과 같다 (앞 스테이지 별 1개씩 + 처음 강화).
/// 기준:
/// - 쉬움: "서툼"도 보통 스테이지를 깬다, 보스는 "처음"이 깬다
/// - 어려움: "익숙함"이 보통 스테이지를 깬다 (보스는 결과만 본다)
@Tags(['balance'])
library;

import 'dart:math';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/difficulty.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/stages.dart';

import 'bot.dart';
import 'stage_balance_test.dart' show arrivingAt;

void main() {
  final runs = <(Difficulty, String Function(StageDef))>[
    (Difficulty.easy, (s) => s.boss ? '처음' : '서툼'),
    (Difficulty.hard, (s) => '익숙함'),
  ];
  for (final (i, stage) in stages.indexed) {
    final before = arrivingAt(i);
    for (final (difficulty, levelFor) in runs) {
      final level = levelFor(stage);
      final spec = botLevels[level]!;
      for (final seed in [1, 2, 3]) {
        GameTester(() => ForestGame(
              stage: stage,
              units: before.unlockedUnits,
              boosts: before.boosts,
              waves: true,
              sound: false,
              intro: false,
              random: Random(seed),
              difficulty: difficulty,
            )).testGameWidget(
          '${stage.id} ${difficulty.name} 자동 플레이 ($level, 시드 $seed)',
          verify: (game, tester) async {
            late String result;
            await tester.runAsync(() async => result = await playOut(game, spec.make(game, seed), spec.actEvery, limit: 600));
            // ignore: avoid_print
            print('[난이도 ${difficulty.name} ${stage.id}] $level 시드 $seed: $result');
            if (difficulty == Difficulty.easy || !stage.boss) expect(game.state, GameState.won);
          },
          timeout: const Timeout(Duration(minutes: 3)),
        );
      }
    }
  }
}
