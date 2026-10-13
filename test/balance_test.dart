import 'dart:math';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/components/acorn.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/units.dart';

/// 난이도 확인용 자동 플레이 (7-1단계).
///
/// 보통 사람처럼 두는 봇: 도토리는 내려앉으면 바로 줍고, 다람쥐를 첫 칸에 놓고,
/// 몬스터가 들어온 레인에 여우를 세우고, 도토리가 남으면 여우·거북이를 더 놓는다.
/// 스컨크는 쓰지 않는다 (사람도 처음엔 잘 안 쓴다). 결과를 출력하고, 이 봇이 이기는지 본다.
class Bot {
  Bot(this.game, {this.pickRate = 1, this.maxSquirrels = 4, this.waitForLawn = false, int seed = 0}) : _random = Random(seed);
  final ForestGame game;

  /// 내려앉은 도토리 중 실제로 줍는 비율 (초보는 놓친다).
  final double pickRate;

  /// 다람쥐를 몇 마리까지 놓는지 (초보는 경제를 덜 챙긴다).
  final int maxSquirrels;

  /// 몬스터가 잔디밭에 들어와야 여우를 놓는지 (초보는 늦게 반응한다).
  final bool waitForLawn;

  final Random _random;
  final Set<Acorn> _seen = {};

  /// 지금 놓을 수 있으면 놓는다. 한 번에 하나.
  Future<void> act() async {
    final g = game.garden;
    // 1) 도토리 줍기
    for (final a in game.world.children.whereType<Acorn>().toList()) {
      if (!a.landed || _seen.contains(a)) continue;
      _seen.add(a); // 도토리마다 한 번만 "주울지" 정한다
      if (_random.nextDouble() < pickRate) a.collect();
    }
    Future<bool> put(UnitType type, int row, int col) async {
      final cell = (row: row, col: col);
      if (g.unitAt(cell) != null || !g.isReady(type)) return false;
      game.selectedUnit = type;
      await game.onCellTapped(cell);
      return g.unitAt(cell) == type;
    }

    int count(UnitType t, {int? row}) =>
        g.units.entries.where((e) => e.value == t && (row == null || e.key.row == row)).length;
    final threatened = <int>{
      for (final m in game.monsters)
        if (!waitForLawn || m.position.x < 1064) m.row,
    };

    // 2) 몬스터가 들어온 레인인데 여우가 없으면 여우부터
    for (final row in threatened) {
      if (count(UnitType.fox, row: row) == 0 && await put(UnitType.fox, row, 1)) return;
    }
    // 3) 다람쥐 4마리까지 (가운데 레인부터)
    if (count(UnitType.squirrel) < maxSquirrels) {
      for (final row in [2, 1, 3, 0, 4]) {
        if (await put(UnitType.squirrel, row, 0)) return;
      }
    }
    // 4) 모든 레인에 여우 하나씩
    for (final row in [2, 1, 3, 0, 4]) {
      if (count(UnitType.fox, row: row) == 0 && await put(UnitType.fox, row, 1)) return;
    }
    // 5) 몬스터가 많은 레인에 거북이(앞쪽) 하나, 여우 하나 더
    final busy = List.generate(5, (r) => game.monsters.where((m) => m.row == r).length);
    final row = List.generate(5, (r) => r).reduce((a, b) => busy[a] >= busy[b] ? a : b);
    if (busy[row] >= 2) {
      if (count(UnitType.turtle, row: row) == 0 && await put(UnitType.turtle, row, 5)) return;
      if (count(UnitType.fox, row: row) < 2 && await put(UnitType.fox, row, 2)) return;
    }
    // 6) 도토리가 넉넉하면 여우를 레인마다 둘째 줄까지
    if (g.acorns >= 200) {
      for (final r in [2, 1, 3, 0, 4]) {
        if (count(UnitType.fox, row: r) < 2 && await put(UnitType.fox, r, 2)) return;
      }
    }
  }
}

/// 봇 수준 세 가지. 익숙함·처음은 반드시 이겨야 하고(데모 난이도), 서툼은 결과만 본다 (난이도의 아래쪽 끝).
final levels = {
  '익숙함': (actEvery: 0.5, mustWin: true, make: (ForestGame g, int s) => Bot(g, seed: s)),
  '처음': (actEvery: 1.5, mustWin: true, make: (ForestGame g, int s) => Bot(g, pickRate: 0.6, maxSquirrels: 2, waitForLawn: true, seed: s)),
  '서툼': (actEvery: 2.5, mustWin: false, make: (ForestGame g, int s) => Bot(g, pickRate: 0.4, maxSquirrels: 1, waitForLawn: true, seed: s)),
};

void main() {
  for (final MapEntry(key: level, value: spec) in levels.entries) {
    for (final seed in [1, 2, 3]) {
      GameTester(() => ForestGame(skyAcorns: true, waves: true, sound: false, intro: false, random: Random(seed))).testGameWidget(
        '자동 플레이 ($level, 시드 $seed): 끝까지 막는다',
        verify: (game, tester) async {
          final bot = spec.make(game, seed);
          var t = 0.0;
          var lastWave = 0;
          final waveTimes = <String>[];
          await tester.runAsync(() async {
            while (!game.isLoaded) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
            final steps = (spec.actEvery * 30).round();
            while (t < 420 && game.state == GameState.playing) {
              for (var i = 0; i < steps; i++) {
                game.update(1 / 30);
                t += 1 / 30;
              }
              await bot.act();
              await Future<void>.delayed(Duration.zero);
              final w = game.waveRunner!.director.displayWave;
              if (w != lastWave && game.waveRunner!.director.waveNumber > 0) {
                lastWave = w;
                waveTimes.add('웨이브$w@${t.round()}s');
              }
            }
          });
          final units = game.garden.units.values.fold(<UnitType, int>{}, (m, u) => m..update(u, (v) => v + 1, ifAbsent: () => 1));
          // ignore: avoid_print
          print('[밸런스] $level 시드 $seed: ${game.state.name} ${t.round()}초, 쓰러뜨림 ${game.defeated}, '
              '남은 통나무 ${game.logs.length}, 도토리 ${game.garden.acorns}, 유닛 ${units.map((k, v) => MapEntry(k.name, v))}, '
              '${waveTimes.join(' ')}');
          if (spec.mustWin) expect(game.state, GameState.won);
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }
  }
}
