import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/monsters.dart';
import 'package:forest_defense/game/waves.dart';

void main() {
  /// [seconds]초를 1/60초씩 흘리며 생긴 일을 [log]에 (시각, 일) 순서로 모은다.
  void run(WaveDirector d, double seconds, List<(double, WaveEvent)> log, {required int Function() alive, double start = 0}) {
    var t = start;
    for (var i = 0; i < (seconds * 60).round(); i++) {
      t += 1 / 60;
      for (final e in d.update(1 / 60, aliveMonsters: alive())) {
        log.add((t, e));
      }
    }
  }

  final total = stageWaves.fold(0, (s, w) => s + w.monsters.length);
  double lastSpawnOf(int i) => stageWaves[i].gap * (stageWaves[i].monsters.length - 1);

  test('웨이브는 5개, 마지막만 큰 무리, 세 종류가 모두 나온다', () {
    expect(stageWaves, hasLength(5));
    expect(stageWaves.where((w) => w.big), [stageWaves.last]);
    expect(WaveDirector().total, total);
    expect(stageWaves.expand((w) => w.monsters).toSet(), MonsterType.values.toSet());
  });

  test('첫 웨이브는 firstDelay초 뒤 시작하고 정한 간격으로 내보낸다', () {
    final d = WaveDirector(random: Random(1));
    final log = <(double, WaveEvent)>[];
    const first = WaveDirector.firstDelay;
    final w = stageWaves.first;
    run(d, first - 0.1, log, alive: () => 1);
    expect(log, isEmpty);
    run(d, lastSpawnOf(0) + 1, log, alive: () => 1, start: first - 0.1);
    final started = log.where((e) => e.$2 is WaveStarted).toList();
    expect(started.single.$1, closeTo(first, 0.05));
    final spawns = log.where((e) => e.$2 is SpawnMonster).map((e) => e.$1).toList();
    expect(spawns, hasLength(w.monsters.length));
    for (var i = 1; i < spawns.length; i++) {
      expect(spawns[i] - spawns[i - 1], closeTo(w.gap, 0.05));
    }
    expect(d.waveNumber, 1);
    expect(d.displayWave, 1);
    expect(d.progress, closeTo(w.monsters.length / total, 1e-9));
  });

  test('앞 웨이브를 다 잡으면 clearDelay초 뒤, 아니면 마지막 몬스터 뒤 maxWait초에 다음 웨이브', () {
    final quick = WaveDirector(random: Random(2));
    final slow = WaveDirector(random: Random(2));
    final a = <(double, WaveEvent)>[], b = <(double, WaveEvent)>[];
    run(quick, 100, a, alive: () => 0);
    run(slow, 100, b, alive: () => 3);
    double secondWave(List<(double, WaveEvent)> log) =>
        log.firstWhere((e) => e.$2 is WaveStarted && (e.$2 as WaveStarted).number == 2).$1;
    final lastOfFirst = WaveDirector.firstDelay + lastSpawnOf(0);
    expect(secondWave(a), closeTo(lastOfFirst + WaveDirector.clearDelay, 0.05));
    expect(secondWave(b), closeTo(lastOfFirst + WaveDirector.maxWait, 0.05));
  });

  test('모든 웨이브를 내보내면 진행 바가 가득 차고, 큰 무리 경고는 마지막 웨이브 3초 전에 한 번', () {
    final d = WaveDirector(random: Random(3));
    final log = <(double, WaveEvent)>[];
    run(d, 400, log, alive: () => 0);
    expect(d.allSpawned, isTrue);
    expect(d.progress, 1);
    final warnings = log.where((e) => e.$2 is BigWaveWarning).toList();
    expect(warnings, hasLength(1));
    final big = log.firstWhere((e) => e.$2 is WaveStarted && (e.$2 as WaveStarted).big);
    expect(big.$1 - warnings.single.$1, closeTo(WaveDirector.warningTime, 0.05));
    final spawned = log.map((e) => e.$2).whereType<SpawnMonster>().toList();
    expect(spawned, hasLength(total));
    expect(spawned.every((s) => s.row >= 0 && s.row < 5), isTrue);
    expect(spawned.map((s) => s.type).toSet(), MonsterType.values.toSet());
  });

  test('전체 길이는 다 잡을 때 약 3분, 못 잡을 때 약 4분 (데모 한 판 분량)', () {
    double length(int alive) {
      final d = WaveDirector(random: Random(4));
      final log = <(double, WaveEvent)>[];
      run(d, 600, log, alive: () => alive);
      return log.where((e) => e.$2 is SpawnMonster).last.$1;
    }

    // ignore: avoid_print
    print('[길이] 다 잡을 때 ${length(0).round()}초, 못 잡을 때 ${length(5).round()}초');
    expect(length(0), inInclusiveRange(150, 220));
    expect(length(5), inInclusiveRange(200, 280));
  });

  test('startWave를 주면 그 웨이브부터 시작하고 진행 바는 앞 웨이브만큼 차 있다', () {
    final d = WaveDirector(random: Random(5), startWave: 5);
    final before = stageWaves.take(4).fold(0, (s, w) => s + w.monsters.length);
    expect(d.progress, closeTo(before / total, 1e-9));
    expect(d.displayWave, 5, reason: '시작 전에도 다가오는 웨이브 번호를 보인다');
    final log = <(double, WaveEvent)>[];
    run(d, WaveDirector.firstDelay + lastSpawnOf(4) + 2, log, alive: () => 0);
    final started = log.map((e) => e.$2).whereType<WaveStarted>().single;
    expect(started.number, 5);
    expect(started.big, isTrue);
    expect(log.map((e) => e.$2).whereType<BigWaveWarning>(), hasLength(1));
    expect(d.allSpawned, isTrue);
  });
}
