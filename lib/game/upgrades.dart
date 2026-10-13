import 'units.dart';

/// 강화 상점에서 솔방울로 사는 영구 강화 (plan.md 확장 "영구 강화"). 하나에 3단계까지.
enum Upgrade {
  squirrel(UnitType.squirrel),
  fox(UnitType.fox),
  turtle(UnitType.turtle),
  hedgehog(UnitType.hedgehog),
  skunk(UnitType.skunk),
  owl(UnitType.owl),
  bear(UnitType.bear),
  startAcorns(null, costs: [20, 40, 60]);

  const Upgrade(this.unit, {this.costs = const [15, 30, 50]});

  /// 강화하는 유닛 (시작 도토리는 null). 그 유닛이 열려야 살 수 있다.
  final UnitType? unit;

  /// 1·2·3단계 값 (솔방울).
  final List<int> costs;

  static const int maxLevel = 3;

  /// [level]단계에서 다음 단계로 가는 값 (이미 최고면 null).
  int? costAt(int level) => level >= maxLevel ? null : costs[level];
}

/// 강화 단계를 판 안 수치로 바꾼다. 판(ForestGame)은 이것만 보고 유닛 능력을 고친다.
class Boosts {
  const Boosts([this.levels = const {}]);

  /// 강화 → 단계 (0~3). 없으면 0.
  final Map<Upgrade, int> levels;

  static const none = Boosts();

  int level(Upgrade u) => levels[u] ?? 0;

  /// 다람쥐 생산 간격 배수: 단계마다 −10%.
  double get squirrelInterval => 1 - 0.10 * level(Upgrade.squirrel);

  /// 여우불 피해 배수: 단계마다 +15%.
  double get foxDamage => 1 + 0.15 * level(Upgrade.fox);

  /// 거북이 HP 배수: 단계마다 +25%.
  double get turtleHp => 1 + 0.25 * level(Upgrade.turtle);

  /// 고슴도치 가시 피해 배수: 단계마다 +30%.
  double get spineDamage => 1 + 0.30 * level(Upgrade.hedgehog);

  /// 스컨크 쿨다운 배수: 단계마다 −15%.
  double get skunkCooldown => 1 - 0.15 * level(Upgrade.skunk);

  /// 부엉이 감속에 더하는 초: 단계마다 +1초.
  double get owlSlowExtra => 1.0 * level(Upgrade.owl);

  /// 곰 피해 배수: 단계마다 +20%.
  double get bearDamage => 1 + 0.20 * level(Upgrade.bear);

  /// 시작 도토리에 더하는 수: 단계마다 +25.
  int get extraAcorns => 25 * level(Upgrade.startAcorns);

  /// 유닛을 놓은 뒤 다시 놓을 수 있을 때까지 (초).
  double cooldownOf(UnitType t) => t == UnitType.skunk ? t.cooldown * skunkCooldown : t.cooldown;

  /// 유닛 최대 HP.
  int maxHpOf(UnitType t) => t == UnitType.turtle ? (t.maxHp * turtleHp).round() : t.maxHp;
}
