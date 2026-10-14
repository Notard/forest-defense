@Tags(['balance'])
library;

import 'dart:math';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/forest_game.dart';

import 'bot.dart';

/// 난이도 확인용 자동 플레이 — 예전 데모 한 판 (7-1단계). 스테이지별은 stage_balance_test.dart.
/// 익숙함·처음은 반드시 이겨야 하고(데모 난이도), 서툼은 결과만 본다 (난이도의 아래쪽 끝).
void main() {
  for (final MapEntry(key: level, value: spec) in botLevels.entries) {
    for (final seed in [1, 2, 3]) {
      GameTester(() => ForestGame(nestAcorns: true, waves: true, sound: false, intro: false, random: Random(seed))).testGameWidget(
        '자동 플레이 ($level, 시드 $seed): 끝까지 막는다',
        verify: (game, tester) async {
          late String result;
          await tester.runAsync(() async => result = await playOut(game, spec.make(game, seed), spec.actEvery));
          // ignore: avoid_print
          print('[밸런스] $level 시드 $seed: $result');
          if (level != '서툼') expect(game.state, GameState.won);
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }
  }
}
