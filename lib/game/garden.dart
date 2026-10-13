import 'grid.dart';
import 'units.dart';

/// 놓기를 거절한 이유. 화면에서 알맞은 반응(카드 흔들기 등)을 고를 때 쓴다.
enum PlaceResult { placed, notEnoughAcorns, coolingDown, occupied }

/// 도토리, 카드 쿨다운, 칸 점유를 관리하는 규칙 (화면과 분리해 단위 테스트한다).
class Garden {
  Garden({this.acorns = startAcorns, this.cooldownOf = baseCooldown});

  /// 유닛별 쿨다운 (초). 강화 상점의 스컨크 강화가 줄인다 (12단계).
  final double Function(UnitType) cooldownOf;

  static double baseCooldown(UnitType t) => t.cooldown;

  /// 시작 도토리 (plan.md 4단계). 150 → 200: 처음 하는 사람에게 너무 어려웠다 (7-1단계).
  static const int startAcorns = 200;

  /// 하늘에서 떨어지는 도토리·다람쥐가 만드는 도토리 하나의 값.
  static const int acornValue = 25;

  int acorns;

  final Map<Cell, UnitType> _units = {};
  final Map<UnitType, double> _cooldownLeft = {};

  /// 칸에 놓인 유닛 (없으면 null).
  UnitType? unitAt(Cell cell) => _units[cell];

  Map<Cell, UnitType> get units => Map.unmodifiable(_units);

  /// 남은 쿨다운 (초). 0이면 바로 놓을 수 있다.
  double cooldownLeft(UnitType type) => _cooldownLeft[type] ?? 0;

  /// 남은 쿨다운 비율 0~1 (카드 위 어두운 덮개 높이).
  double cooldownFraction(UnitType type) => cooldownLeft(type) / cooldownOf(type);

  bool canAfford(UnitType type) => acorns >= type.cost;

  /// 카드가 지금 눌리는지 (도토리 충분 + 쿨다운 끝).
  bool isReady(UnitType type) => canAfford(type) && cooldownLeft(type) == 0;

  PlaceResult check(UnitType type, Cell cell) {
    if (_units.containsKey(cell)) return PlaceResult.occupied;
    if (cooldownLeft(type) > 0) return PlaceResult.coolingDown;
    if (!canAfford(type)) return PlaceResult.notEnoughAcorns;
    return PlaceResult.placed;
  }

  /// 놓을 수 있으면 도토리를 내고 쿨다운을 시작한다.
  PlaceResult place(UnitType type, Cell cell) {
    final result = check(type, cell);
    if (result != PlaceResult.placed) return result;
    acorns -= type.cost;
    _units[cell] = type;
    _cooldownLeft[type] = cooldownOf(type);
    return result;
  }

  /// 삽으로 치우거나 유닛이 쓰러졌을 때. 도토리는 돌려주지 않는다.
  UnitType? remove(Cell cell) => _units.remove(cell);

  void addAcorns(int amount) => acorns += amount;

  /// 시간을 [dt]초 흘려 쿨다운을 줄인다.
  void tick(double dt) {
    for (final type in _cooldownLeft.keys.toList()) {
      final left = _cooldownLeft[type]! - dt;
      if (left <= 0) {
        _cooldownLeft.remove(type);
      } else {
        _cooldownLeft[type] = left;
      }
    }
  }
}
