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

  /// 하늘 도토리는 낮·밤 모두 떨어진다. 밤에는 드물게 (13단계, [SkyAcornSpawner.nightMinGap]).
  bool get skyAcorns => true;

  /// 별을 처음 얻을 때 별 하나당 솔방울.
  int get pineconesPerStar => boss ? 20 : 10;
}

const _s = MonsterType.slime, _h = MonsterType.helmetSlime, _w = MonsterType.wisp;
const _m = MonsterType.mushroom, _g = MonsterType.golem, _b = MonsterType.bat, _k = MonsterType.bossSlime;

/// 스테이지 10개 (13단계). 스테이지마다 새 적 하나를 소개하고, 보스 스테이지는 마지막 웨이브에 슬라임 왕.
/// 수치는 test/stage_balance_test.dart의 자동 플레이 봇으로 확인한다 (WORKLOG 13단계).
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
  // 버섯 포자
  StageDef(id: '1-4', region: Region.day, unlocks: UnitType.owl, waves: [
    Wave([_s, _s], gap: 12),
    Wave([_s, _m, _s], gap: 9),
    Wave([_h, _m, _w, _s], gap: 7),
    Wave([_m, _s, _h, _m, _w], gap: 5),
    Wave([_s, _m, _h, _s, _m, _w, _h, _s], gap: 1.6, big: true),
  ]),
  // 보스: 슬라임 왕
  StageDef(id: '1-5', region: Region.day, boss: true, unlocks: UnitType.bear, waves: [
    Wave([_s, _h, _s], gap: 10),
    Wave([_m, _w, _s, _h], gap: 7),
    Wave([_h, _m, _s, _w, _m], gap: 5),
    Wave([_s, _h, _m, _s, _w, _h], gap: 3),
    Wave([_k, _s, _s, _h, _m], gap: 3, big: true),
  ]),
  // 밤 숲: 하늘 도토리가 없다 → 다람쥐가 중요. 박쥐
  StageDef(id: '2-1', region: Region.night, startAcorns: 300, waves: [
    Wave([_s, _s], gap: 12),
    Wave([_s, _b, _s], gap: 9),
    Wave([_b, _s, _b], gap: 8),
    Wave([_s, _b, _h, _s, _b, _s], gap: 2.2, big: true),
  ]),
  // 돌 골렘
  StageDef(id: '2-2', region: Region.night, startAcorns: 300, waves: [
    Wave([_s, _h], gap: 12),
    Wave([_g, _s, _s], gap: 9),
    Wave([_b, _h, _g, _s], gap: 7),
    Wave([_m, _g, _b, _h, _s], gap: 5),
    Wave([_g, _s, _b, _h, _g, _m, _s, _b], gap: 1.6, big: true),
  ]),
  // 모두 섞기
  StageDef(id: '2-3', region: Region.night, startAcorns: 300, waves: [
    Wave([_s, _b, _s], gap: 10),
    Wave([_h, _m, _b], gap: 8),
    Wave([_g, _m, _b, _s], gap: 6),
    Wave([_w, _w, _b, _b, _m, _h], gap: 4.5),
    Wave([_g, _h, _b, _m, _w, _g, _s, _b, _h], gap: 2.0, big: true),
  ]),
  // 골렘·버섯 많이
  StageDef(id: '2-4', region: Region.night, startAcorns: 300, waves: [
    Wave([_m, _s, _m], gap: 10),
    Wave([_m, _g, _s], gap: 8),
    Wave([_m, _s, _g, _b, _h], gap: 6.5),
    Wave([_m, _g, _m, _h, _b, _m], gap: 4.5),
    Wave([_g, _m, _s, _m, _b, _s, _h, _m], gap: 2.4, big: true),
  ]),
  // 보스: 밤 슬라임 왕 (HP 4500)
  StageDef(id: '2-5', region: Region.night, startAcorns: 300, boss: true, waves: [
    Wave([_s, _b, _h], gap: 10),
    Wave([_g, _m, _b, _s], gap: 7),
    Wave([_h, _g, _b, _m, _w], gap: 5),
    Wave([_g, _m, _b, _h, _g, _b], gap: 3.5),
    Wave([_m, _h, _b, _g, _w, _s, _m], gap: 2.5),
    Wave([_k, _g, _b, _m, _h, _b], gap: 3, big: true),
  ]),
];

/// 지도 없이 바로 하는 한 판 (예전 데모, 테스트와 `?intro=0` 확인용).
const StageDef demoStage = StageDef(id: 'demo', region: Region.day, waves: stageWaves);

StageDef stageById(String id) => stages.firstWhere((s) => s.id == id, orElse: () => demoStage);

/// 다음 스테이지 (마지막이면 null).
StageDef? nextStage(StageDef s) {
  final i = stages.indexOf(s);
  return i < 0 || i + 1 >= stages.length ? null : stages[i + 1];
}
