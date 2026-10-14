import 'dart:math';

import 'package:forest_defense/game/components/acorn.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/monsters.dart';
import 'package:forest_defense/game/units.dart';

/// 난이도 확인용 자동 플레이 봇 (7-1단계, 13단계에서 새 친구까지).
///
/// 보통 사람처럼 두는 봇: 도토리는 내려앉으면 바로 줍고, 다람쥐를 첫 칸에 놓고,
/// 몬스터가 들어온 레인에 여우를 세우고, 도토리가 남으면 여우·벽을 더 놓는다.
/// 판에서 쓸 수 있는 친구(카드)만 쓴다: 까치는 첫 칸에, 고슴도치가 있으면 벽으로, 부엉이는 박쥐·골렘이 온 레인에,
/// 곰은 골렘·보스가 온 레인 앞쪽에. 스컨크와 레벨업은 쓰지 않는다 (처음 하는 사람처럼).
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

  bool has(UnitType t) => game.units.contains(t);

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
      if (!has(type) || !game.laneOpen(row) || g.unitAt(cell) != null || !g.isReady(type)) return false;
      game.selectedUnit = type;
      await game.onCellTapped(cell);
      return g.unitAt(cell) == type;
    }

    int count(UnitType t, {int? row}) =>
        g.units.entries.where((e) => e.value == t && (row == null || e.key.row == row)).length;
    final seen = [
      for (final m in game.monsters)
        if (!waitForLawn || m.position.x < 1064) m,
    ];
    final threatened = {for (final m in seen) m.row};
    final lanes = [2, 1, 3, 0, 4].where(game.laneOpen).toList();

    // 2) 몬스터가 들어온 레인인데 여우가 없으면 여우부터
    for (final row in threatened) {
      if (count(UnitType.fox, row: row) == 0 && await put(UnitType.fox, row, 1)) return;
    }
    // 3) 다람쥐 (가운데 레인부터)
    if (count(UnitType.squirrel) < maxSquirrels) {
      for (final row in lanes) {
        if (await put(UnitType.squirrel, row, 0)) return;
      }
    }
    // 3-1) 까치 (14-1단계): 다람쥐 옆 첫 칸에 하나(익숙하면 둘)
    if (count(UnitType.magpie) < (maxSquirrels >= 4 ? 2 : 1)) {
      for (final row in [3, 1, 0, 4, 2].where(game.laneOpen)) {
        if (await put(UnitType.magpie, row, 0)) return;
      }
    }
    // 4) 박쥐·골렘이 온 레인에 부엉이, 골렘·보스가 온 레인에 곰
    for (final m in seen) {
      if ((m.type == MonsterType.bat || m.type == MonsterType.golem) && count(UnitType.owl, row: m.row) == 0 && await put(UnitType.owl, m.row, 3)) return;
      if ((m.type == MonsterType.golem || m.type.boss) && count(UnitType.bear, row: m.row) == 0 && await put(UnitType.bear, m.row, 4)) return;
    }
    // 5) 모든 레인에 여우 하나씩
    for (final row in lanes) {
      if (count(UnitType.fox, row: row) == 0 && await put(UnitType.fox, row, 1)) return;
    }
    // 6) 몬스터가 많은 레인에 벽(고슴도치가 있으면 고슴도치) 하나, 여우 하나 더
    final busy = List.generate(5, (r) => game.monsters.where((m) => m.row == r).length);
    final row = List.generate(5, (r) => r).reduce((a, b) => busy[a] >= busy[b] ? a : b);
    if (busy[row] >= 2) {
      final wall = has(UnitType.hedgehog) ? UnitType.hedgehog : UnitType.turtle;
      if (count(UnitType.turtle, row: row) + count(UnitType.hedgehog, row: row) == 0 && await put(wall, row, 5)) return;
      if (count(UnitType.fox, row: row) < 2 && await put(UnitType.fox, row, 2)) return;
    }
    // 7) 도토리가 넉넉하면 여우를 레인마다 둘째 줄까지
    if (g.acorns >= 200) {
      for (final r in lanes) {
        if (count(UnitType.fox, row: r) < 2 && await put(UnitType.fox, r, 2)) return;
      }
    }
  }
}

typedef BotLevel = ({double actEvery, Bot Function(ForestGame, int) make});

/// 봇 수준 세 가지. 익숙함: 0.5초마다, 다 줍고 다람쥐 넷 / 처음: 1.5초마다, 60%만 줍고 다람쥐 둘, 늦게 반응 / 서툼: 더 느리고 덜 줍는다.
final Map<String, BotLevel> botLevels = {
  '익숙함': (actEvery: 0.5, make: (ForestGame g, int s) => Bot(g, seed: s)),
  '처음': (actEvery: 1.5, make: (ForestGame g, int s) => Bot(g, pickRate: 0.6, maxSquirrels: 2, waitForLawn: true, seed: s)),
  '서툼': (actEvery: 2.5, make: (ForestGame g, int s) => Bot(g, pickRate: 0.4, maxSquirrels: 1, waitForLawn: true, seed: s)),
};

/// 봇으로 한 판을 끝까지 (또는 [limit]초까지) 둔다. 결과 한 줄을 돌려준다.
Future<String> playOut(ForestGame game, Bot bot, double actEvery, {double limit = 420}) async {
  var t = 0.0;
  var lastWave = 0;
  final waveTimes = <String>[];
  while (!game.isLoaded) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  final steps = (actEvery * 30).round();
  while (t < limit && game.state == GameState.playing) {
    for (var i = 0; i < steps; i++) {
      game.update(1 / 30);
      t += 1 / 30;
    }
    await bot.act();
    await Future<void>.delayed(Duration.zero);
    final runner = game.waveRunner!;
    final w = runner.director.displayWave;
    if (w != lastWave && runner.director.waveNumber > 0) {
      lastWave = w;
      waveTimes.add('웨이브$w@${t.round()}s');
    }
  }
  final units = game.garden.units.values.fold(<UnitType, int>{}, (m, u) => m..update(u, (v) => v + 1, ifAbsent: () => 1));
  return '${game.state.name} ${t.round()}초, 쓰러뜨림 ${game.defeated}, 남은 하트 ${game.hearts}, '
      '도토리 ${game.garden.acorns}, 유닛 ${units.map((k, v) => MapEntry(k.name, v))}, ${waveTimes.join(' ')}';
}
