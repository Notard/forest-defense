import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/garden.dart';
import 'package:forest_defense/game/units.dart';

void main() {
  const a = (row: 0, col: 0), b = (row: 2, col: 4);

  test('시작 도토리는 150개, 모든 카드가 바로 눌린다', () {
    final g = Garden();
    expect(g.acorns, 150);
    for (final type in UnitType.values) {
      expect(g.cooldownLeft(type), 0);
      expect(g.isReady(type), type.cost <= 150);
    }
  });

  test('놓으면 비용을 내고 칸을 차지하며 쿨다운이 시작된다', () {
    final g = Garden();
    expect(g.place(UnitType.fox, a), PlaceResult.placed);
    expect(g.acorns, 50);
    expect(g.unitAt(a), UnitType.fox);
    expect(g.cooldownLeft(UnitType.fox), UnitType.fox.cooldown);
    expect(g.isReady(UnitType.fox), isFalse);
  });

  test('이미 찬 칸에는 놓을 수 없고 도토리도 그대로다', () {
    final g = Garden();
    g.place(UnitType.squirrel, a);
    expect(g.place(UnitType.turtle, a), PlaceResult.occupied);
    expect(g.acorns, 100);
    expect(g.unitAt(a), UnitType.squirrel);
  });

  test('도토리가 모자라면 놓을 수 없다', () {
    final g = Garden(acorns: 99);
    expect(g.place(UnitType.fox, a), PlaceResult.notEnoughAcorns);
    expect(g.acorns, 99);
    expect(g.unitAt(a), isNull);
  });

  test('쿨다운 중에는 다른 칸에도 같은 유닛을 놓을 수 없고, 시간이 지나면 풀린다', () {
    final g = Garden(acorns: 1000);
    g.place(UnitType.squirrel, a);
    expect(g.place(UnitType.squirrel, b), PlaceResult.coolingDown);
    g.tick(7.4);
    expect(g.place(UnitType.squirrel, b), PlaceResult.coolingDown);
    expect(g.cooldownFraction(UnitType.squirrel), closeTo(0.1 / 7.5, 1e-9));
    g.tick(0.2);
    expect(g.cooldownLeft(UnitType.squirrel), 0);
    expect(g.place(UnitType.squirrel, b), PlaceResult.placed);
  });

  test('쿨다운은 유닛 종류마다 따로다', () {
    final g = Garden(acorns: 1000);
    g.place(UnitType.squirrel, a);
    expect(g.place(UnitType.fox, b), PlaceResult.placed);
  });

  test('삽으로 치우면 칸이 비고 도토리는 돌려주지 않는다', () {
    final g = Garden();
    g.place(UnitType.turtle, a);
    expect(g.remove(a), UnitType.turtle);
    expect(g.unitAt(a), isNull);
    expect(g.acorns, 100);
    expect(g.remove(a), isNull);
  });

  test('도토리를 주우면 25개씩 늘어난다', () {
    final g = Garden(acorns: 0);
    g.addAcorns(Garden.acornValue);
    g.addAcorns(Garden.acornValue);
    expect(g.acorns, 50);
  });
}
