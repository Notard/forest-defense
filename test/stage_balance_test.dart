/// 스테이지 10개 자동 플레이 (13단계).
///
/// 봇은 그 스테이지에 처음 왔을 때의 상태로 둔다:
/// - 친구: 앞 스테이지를 모두 깼을 때의 해금
/// - 강화: 앞 스테이지를 모두 **별 1개씩만** 따고 받은 솔방울(가장 적은 경우)로 [starterPlan] 순서대로 산 것
/// - 레벨업·스컨크는 쓰지 않는다
/// 기준: 보통 스테이지는 "처음" 수준이 시드 셋 모두 깬다, 보스 스테이지는 "익숙함" 수준이 깬다 (plan.md 확장).
/// "서툼"은 결과만 본다.
@Tags(['balance'])
library;

import 'dart:math';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/progress.dart';
import 'package:forest_defense/game/stages.dart';
import 'package:forest_defense/game/upgrades.dart';

import 'bot.dart';


/// 처음 하는 사람이 상점에서 살 법한 순서: 시작 도토리, 여우, 다람쥐를 번갈아.
const starterPlan = [Upgrade.startAcorns, Upgrade.fox, Upgrade.squirrel, Upgrade.fox, Upgrade.startAcorns, Upgrade.squirrel, Upgrade.fox];

/// [i]번째 스테이지에 처음 왔을 때의 진행 (앞 스테이지 별 1개씩, 솔방울로 [starterPlan] 구매).
Progress arrivingAt(int i) {
  final p = Progress(stars: {for (final s in stages.take(i)) s.id: 1}, pinecones: stages.take(i).fold(0, (a, s) => a + s.pineconesPerStar));
  for (final u in starterPlan) {
    p.buy(u);
  }
  return p;
}

void main() {
  test('봇이 각 스테이지에 가지고 오는 강화 (기록용)', () {
    for (final (i, s) in stages.indexed) {
      final p = arrivingAt(i);
      // ignore: avoid_print
      print('[도착] ${s.id}: 솔방울 남음 ${p.pinecones}, 강화 ${{for (final u in Upgrade.values) if (p.levelOf(u) > 0) u.name: p.levelOf(u)}}');
    }
  });

  for (final (i, stage) in stages.indexed) {
    final before = arrivingAt(i);
    final units = before.unlockedUnits;
    final boosts = before.boosts;
    final mustWin = stage.boss ? '익숙함' : '처음';
    for (final MapEntry(key: level, value: spec) in botLevels.entries) {
      for (final seed in [1, 2, 3]) {
        GameTester(() => ForestGame(stage: stage, units: units, boosts: boosts, waves: true, sound: false, intro: false, random: Random(seed))).testGameWidget(
          '${stage.id} 자동 플레이 ($level, 시드 $seed)',
          verify: (game, tester) async {
            late String result;
            await tester.runAsync(() async => result = await playOut(game, spec.make(game, seed), spec.actEvery, limit: 600));
            // ignore: avoid_print
            print('[스테이지 ${stage.id}] $level 시드 $seed: $result');
            final mustLevels = [for (final l in botLevels.keys) l];
            if (mustLevels.indexOf(level) <= mustLevels.indexOf(mustWin)) expect(game.state, GameState.won);
          },
          timeout: const Timeout(Duration(minutes: 3)),
        );
      }
    }
  }
}
