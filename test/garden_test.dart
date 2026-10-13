import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/garden.dart';
import 'package:forest_defense/game/units.dart';

void main() {
  const a = (row: 0, col: 0), b = (row: 2, col: 4);
  const start = Garden.startAcorns;

  test('시작 도토리만큼 가지고 시작하고, 살 수 있는 카드는 바로 눌린다', () {
    final g = Garden();
    expect(g.acorns, start);
    for (final type in UnitType.values) {
      expect(g.cooldownLeft(type), 0);
      expect(g.isReady(type), type.cost <= start);
    }
  });

  test('놓으면 비용을 내고 칸을 차지하며 쿨다운이 시작된다', () {
    final g = Garden();
    expect(g.place(UnitType.fox, a), PlaceResult.placed);
    expect(g.acorns, start - UnitType.fox.cost);
    expect(g.unitAt(a), UnitType.fox);
    expect(g.cooldownLeft(UnitType.fox), UnitType.fox.cooldown);
    expect(g.isReady(UnitType.fox), isFalse);
  });

  test('이미 찬 칸에는 놓을 수 없고 도토리도 그대로다', () {
    final g = Garden();
    g.place(UnitType.squirrel, a);
    expect(g.place(UnitType.turtle, a), PlaceResult.occupied);
    expect(g.acorns, start - UnitType.squirrel.cost);
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
    g.tick(UnitType.squirrel.cooldown - 0.1);
    expect(g.place(UnitType.squirrel, b), PlaceResult.coolingDown);
    expect(g.cooldownFraction(UnitType.squirrel), closeTo(0.1 / UnitType.squirrel.cooldown, 1e-9));
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
    expect(g.acorns, start - UnitType.turtle.cost);
    expect(g.remove(a), isNull);
  });

  test('도토리를 주우면 25개씩 늘어난다', () {
    final g = Garden(acorns: 0);
    g.addAcorns(Garden.acornValue);
    g.addAcorns(Garden.acornValue);
    expect(g.acorns, 50);
  });
}
