import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/components/acorn.dart';
import 'package:forest_defense/game/progress.dart';
import 'package:forest_defense/game/stages.dart';
import 'package:forest_defense/game/units.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final s11 = stageById('1-1'), s12 = stageById('1-2'), s13 = stageById('1-3');

  test('스테이지는 10개, 지역마다 마지막은 보스, 밤은 하늘 도토리 없음', () {
    expect(stages, hasLength(10));
    expect(stages.where((s) => s.boss).map((s) => s.id), ['1-5', '2-5']);
    // 13단계: 밤에도 하늘 도토리가 떨어지지만 드물다 (낮 5~8초, 밤 10~14초)
    expect(SkyAcornSpawner.nightMinGap, greaterThan(SkyAcornSpawner.dayMaxGap));
    expect(s11.lanes, [1, 2, 3]);
  });

  test('처음에는 1-1만 열려 있고 다람쥐·여우만 쓸 수 있다', () {
    final p = Progress();
    expect(stages.where(p.isOpen).map((s) => s.id), ['1-1']);
    expect(p.unlockedUnits, [UnitType.squirrel, UnitType.fox]);
  });

  test('별: 깨면 1, 통나무를 안 쓰면 +1, 동물을 안 잃으면 +1. 졌으면 0', () {
    expect(Progress().record(s11, won: true, usedLog: true, lostUnit: true).stars, 1);
    expect(Progress().record(s11, won: true, usedLog: false, lostUnit: true).stars, 2);
    expect(Progress().record(s11, won: true, usedLog: false, lostUnit: false).stars, 3);
    expect(Progress().record(s11, won: false, usedLog: false, lostUnit: false).stars, 0);
  });

  test('처음 깨면 다음 스테이지가 열리고 유닛이 해금된다. 솔방울은 처음 얻은 별만큼', () {
    final p = Progress();
    final r1 = p.record(s11, won: true, usedLog: true, lostUnit: false);
    expect(r1.stars, 2);
    expect(r1.pinecones, 20);
    expect(r1.unlocked, UnitType.turtle);
    expect(p.isOpen(s12), isTrue);
    expect(p.isOpen(s13), isFalse);
    expect(p.unlockedUnits, [UnitType.squirrel, UnitType.fox, UnitType.turtle]);

    // 다시 해서 별 3개: 새로 얻은 별 1개만큼, 해금은 다시 없다
    final r2 = p.record(s11, won: true, usedLog: false, lostUnit: false);
    expect(r2.newStars, 1);
    expect(r2.pinecones, 10);
    expect(r2.unlocked, isNull);
    // 더 못한 판은 기록을 낮추지 않는다
    final r3 = p.record(s11, won: true, usedLog: true, lostUnit: true);
    expect(r3.pinecones, 0);
    expect(p.starsOf(s11), 3);
    expect(p.pinecones, 30);
  });

  test('보스 스테이지는 별 하나에 솔방울 20개', () {
    expect(stageById('1-5').pineconesPerStar, 20);
  });

  test('저장하고 다시 읽으면 같다', () async {
    SharedPreferences.setMockInitialValues({});
    final p = Progress()..record(s11, won: true, usedLog: false, lostUnit: false);
    p.upgrades['fox'] = 2;
    await p.save();
    final q = await Progress.load();
    expect(q.starsOf(s11), 3);
    expect(q.pinecones, p.pinecones);
    expect(q.upgrades, {'fox': 2});
  });

  test('저장 내용이 깨졌으면 새로 시작한다', () async {
    SharedPreferences.setMockInitialValues({'forest_progress_v1': '{깨짐'});
    final q = await Progress.load();
    expect(q.totalStars, 0);
  });
}
