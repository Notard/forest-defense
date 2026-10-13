import 'dart:math';

import 'monsters.dart';

/// 웨이브 하나: 몬스터를 [gap]초 간격으로 순서대로 내보낸다. 레인은 무작위.
class Wave {
  const Wave(this.monsters, {required this.gap, this.big = false});

  final List<MonsterType> monsters;

  /// 몬스터 사이 간격 (초).
  final double gap;

  /// 마지막 "큰 무리" 웨이브 (시작 전에 경고를 띄운다).
  final bool big;
}

const _s = MonsterType.slime, _h = MonsterType.helmetSlime, _w = MonsterType.wisp;

/// 데모 스테이지의 웨이브 5개 (plan.md 6단계). 약 3~4분 분량.
/// 7-1단계에서 쉽게: 41마리 → 33마리, 초반을 가볍게, 간격을 넓게.
const List<Wave> stageWaves = [
  Wave([_s, _s], gap: 12),
  Wave([_s, _s, _s, _s], gap: 9),
  Wave([_s, _s, _h, _s, _w, _s], gap: 7),
  Wave([_s, _h, _s, _w, _s, _h, _s, _w, _s], gap: 6),
  Wave([_s, _s, _h, _w, _s, _h, _s, _w, _s, _h, _s, _s], gap: 1.2, big: true),
];

/// 웨이브 진행에서 일어나는 일.
sealed class WaveEvent {}

/// 몬스터를 [row] 레인에 내보낸다.
class SpawnMonster extends WaveEvent {
  SpawnMonster(this.type, this.row);
  final MonsterType type;
  final int row;
}

/// 웨이브 [number](1부터)가 시작됐다.
class WaveStarted extends WaveEvent {
  WaveStarted(this.number, {required this.big});
  final int number;
  final bool big;
}

/// "큰 무리가 몰려와요!" 경고 (마지막 웨이브 [warningTime]초 전).
class BigWaveWarning extends WaveEvent {}

/// 웨이브 진행 규칙 (화면과 분리해 단위 테스트한다).
///
/// - 첫 웨이브는 [firstDelay]초 뒤에 시작한다 (동물을 놓을 시간)
/// - 다음 웨이브는 앞 웨이브의 몬스터가 모두 쓰러지면 [clearDelay]초 뒤,
///   아니어도 앞 웨이브 마지막 몬스터가 나오고 [maxWait]초 뒤에 시작한다
/// - 큰 무리 웨이브는 시작 [warningTime]초 전에 경고를 낸다
class WaveDirector {
  /// [startWave](1부터)를 주면 그 웨이브부터 시작한다 (확인용 `?wave=5`). 앞 웨이브는 다 지나간 것으로 친다.
  WaveDirector({this.waves = stageWaves, Random? random, int startWave = 1, this.lanes = const [0, 1, 2, 3, 4]})
      : _random = random ?? Random() {
    _next = (startWave - 1).clamp(0, waves.length - 1);
    _spawnedTotal = waves.take(_next).fold(0, (sum, w) => sum + w.monsters.length);
  }

  // 7-1단계: 첫 웨이브 20 → 30초, 다 잡은 뒤 5 → 7초, 최대 14 → 18초
  static const double firstDelay = 30, clearDelay = 7, maxWait = 18, warningTime = 3;

  final List<Wave> waves;

  /// 몬스터가 나오는 레인 (스테이지가 쓰는 레인).
  final List<int> lanes;
  final Random _random;

  /// 다음에 시작할 웨이브 번호 (0부터). waves.length면 모두 시작했다.
  int _next = 0;

  /// 지금 내보내는 중인 웨이브와 그 안에서 다음 몬스터 번호.
  int _current = -1;
  int _spawnIndex = 0;
  double _spawnTimer = 0;

  /// 다음 웨이브까지 남은 시간.
  double _untilNext = firstDelay;
  bool _warned = false;

  int _spawnedTotal = 0;
  late final int total = waves.fold(0, (sum, w) => sum + w.monsters.length);

  /// 지금 웨이브 번호 (1부터, 시작 전이면 0).
  int get waveNumber => _current + 1;

  /// HUD에 보일 웨이브 번호: 마지막으로 시작한 웨이브. 아직 하나도 시작 전이면 다가오는 웨이브.
  int get displayWave => _current >= 0 ? _current + 1 : _next + 1;

  /// 진행 바: 내보낸 몬스터 수 / 전체.
  double get progress => _spawnedTotal / total;

  /// 모든 웨이브의 몬스터를 다 내보냈는지.
  bool get allSpawned => _spawnedTotal == total;

  bool get _spawning => _current >= 0 && _spawnIndex < waves[_current].monsters.length;

  /// [dt]초 진행. [aliveMonsters]는 지금 살아 있는 몬스터 수 (앞 웨이브를 다 잡았는지 판단).
  List<WaveEvent> update(double dt, {required int aliveMonsters}) {
    final events = <WaveEvent>[];
    if (_spawning) {
      _spawnTimer -= dt;
      while (_spawning && _spawnTimer <= 0) {
        final wave = waves[_current];
        events.add(SpawnMonster(wave.monsters[_spawnIndex], lanes[_random.nextInt(lanes.length)]));
        _spawnIndex++;
        _spawnedTotal++;
        _spawnTimer += wave.gap;
      }
      return events;
    }
    if (_next >= waves.length) return events;

    // 앞 웨이브를 다 잡았으면 기다림을 clearDelay로 줄인다
    if (_current >= 0 && aliveMonsters == 0 && _untilNext > clearDelay) _untilNext = clearDelay;
    _untilNext -= dt;
    if (waves[_next].big && !_warned && _untilNext <= warningTime) {
      _warned = true;
      events.add(BigWaveWarning());
    }
    if (_untilNext <= 0) {
      _current = _next++;
      _spawnIndex = 0;
      _spawnTimer = 0;
      _untilNext = maxWait;
      events.add(WaveStarted(_current + 1, big: waves[_current].big));
      events.addAll(update(0, aliveMonsters: aliveMonsters));
    }
    return events;
  }
}
