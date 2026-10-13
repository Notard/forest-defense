import 'monsters.dart';
import 'units.dart';
import 'waves.dart';

/// 지역: 낮 숲(하늘 도토리 있음) · 밤 숲(없음, 배경이 다르다).
enum Region { day, night }

/// 스테이지 하나 (plan.md 확장 "스테이지 10개").
class StageDef {
  const StageDef({
    required this.id,
    required this.region,
    required this.waves,
    this.lanes = const [0, 1, 2, 3, 4],
    this.startAcorns = 200,
    this.boss = false,
    this.unlocks,
  });

  /// "1-1" … "2-5".
  final String id;
  final Region region;
  final List<Wave> waves;

  /// 쓰는 레인 (0이 맨 위). 1-1은 가운데 세 줄만.
  final List<int> lanes;
  final int startAcorns;
  final bool boss;

  /// 처음 깨면 해금하는 유닛.
  final UnitType? unlocks;

  bool get skyAcorns => region == Region.day;

  /// 별을 처음 얻을 때 별 하나당 솔방울.
  int get pineconesPerStar => boss ? 20 : 10;
}

const _s = MonsterType.slime, _h = MonsterType.helmetSlime, _w = MonsterType.wisp;

/// 스테이지 10개. 9단계에서는 지금 있는 적으로 틀만 잡고, 새 적이 생기면 13단계에서 웨이브를 다시 짠다.
const List<StageDef> stages = [
  StageDef(id: '1-1', region: Region.day, lanes: [1, 2, 3], unlocks: UnitType.turtle, waves: [
    Wave([_s], gap: 10),
    Wave([_s, _s], gap: 10),
    Wave([_s, _s, _s], gap: 6, big: true),
  ]),
  StageDef(id: '1-2', region: Region.day, unlocks: UnitType.hedgehog, waves: [
    Wave([_s, _s], gap: 12),
    Wave([_s, _s, _h], gap: 9),
    Wave([_s, _h, _s, _s], gap: 7),
    Wave([_s, _s, _h, _s, _h, _s], gap: 2, big: true),
  ]),
  StageDef(id: '1-3', region: Region.day, unlocks: UnitType.skunk, waves: [
    Wave([_s, _s], gap: 12),
    Wave([_s, _w, _s], gap: 9),
    Wave([_s, _h, _w, _s], gap: 7),
    Wave([_s, _w, _h, _s, _w, _s, _h], gap: 1.6, big: true),
  ]),
  StageDef(id: '1-4', region: Region.day, unlocks: UnitType.owl, waves: stageWaves),
  StageDef(id: '1-5', region: Region.day, boss: true, unlocks: UnitType.bear, waves: stageWaves),
  StageDef(id: '2-1', region: Region.night, startAcorns: 250, waves: stageWaves),
  StageDef(id: '2-2', region: Region.night, startAcorns: 250, waves: stageWaves),
  StageDef(id: '2-3', region: Region.night, startAcorns: 250, waves: stageWaves),
  StageDef(id: '2-4', region: Region.night, startAcorns: 250, waves: stageWaves),
  StageDef(id: '2-5', region: Region.night, startAcorns: 250, boss: true, waves: stageWaves),
];

/// 지도 없이 바로 하는 한 판 (예전 데모, 테스트와 `?intro=0` 확인용).
const StageDef demoStage = StageDef(id: 'demo', region: Region.day, waves: stageWaves);

StageDef stageById(String id) => stages.firstWhere((s) => s.id == id, orElse: () => demoStage);

/// 다음 스테이지 (마지막이면 null).
StageDef? nextStage(StageDef s) {
  final i = stages.indexOf(s);
  return i < 0 || i + 1 >= stages.length ? null : stages[i + 1];
}
