import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'stages.dart';
import 'units.dart';
import 'upgrades.dart';

/// 한 판의 결과로 얻은 것 (결과 화면에 보인다).
class Reward {
  const Reward({required this.stars, required this.newStars, required this.pinecones, this.unlocked});

  /// 이번 판에서 얻은 별 (0~3, 졌으면 0).
  final int stars;

  /// 처음 얻은 별 수 (솔방울은 이것만큼).
  final int newStars;
  final int pinecones;

  /// 처음 깨서 새로 열린 유닛.
  final UnitType? unlocked;
}

/// 진행: 스테이지별 최고 별, 솔방울, 강화 단계. 기기에 저장한다 (plan.md 확장).
class Progress {
  Progress({Map<String, int>? stars, this.pinecones = 0, Map<String, int>? upgrades})
      : stars = stars ?? {},
        upgrades = upgrades ?? {};

  static const _key = 'forest_progress_v1';

  /// 스테이지 id → 최고 별 (0~3). 1 이상이면 깬 스테이지.
  final Map<String, int> stars;
  int pinecones;

  /// 강화 이름(`Upgrade.name`) → 단계 0~3 (12단계).
  final Map<String, int> upgrades;

  int levelOf(Upgrade u) => upgrades[u.name] ?? 0;

  /// 판에 넘길 강화 수치.
  Boosts get boosts => Boosts({for (final u in Upgrade.values) u: levelOf(u)});

  /// 상점에서 고를 수 있는지: 유닛 강화는 그 유닛이 열려야 한다.
  bool isAvailable(Upgrade u) => u.unit == null || unlockedUnits.contains(u.unit);

  /// 지금 살 수 있는지: 열려 있고, 최고 단계가 아니고, 솔방울이 충분.
  bool canBuy(Upgrade u) {
    final cost = u.costAt(levelOf(u));
    return isAvailable(u) && cost != null && pinecones >= cost;
  }

  /// 산다. 살 수 없으면 아무것도 하지 않고 false.
  bool buy(Upgrade u) {
    if (!canBuy(u)) return false;
    pinecones -= u.costAt(levelOf(u))!;
    upgrades[u.name] = levelOf(u) + 1;
    return true;
  }

  /// 상점에 무엇이든 살 수 있는 것이 있는지 (지도의 상점 버튼이 빛난다).
  bool get canBuyAny => Upgrade.values.any(canBuy);

  /// 처음부터 가진 유닛.
  static const startUnits = [UnitType.squirrel, UnitType.fox];

  int starsOf(StageDef s) => stars[s.id] ?? 0;
  bool cleared(StageDef s) => starsOf(s) > 0;
  int get totalStars => stars.values.fold(0, (a, b) => a + b);

  /// 고를 수 있는 스테이지: 첫 스테이지, 또는 바로 앞 스테이지를 깼을 때.
  bool isOpen(StageDef s) {
    final i = stages.indexOf(s);
    return i <= 0 || cleared(stages[i - 1]);
  }

  /// 쓸 수 있는 유닛: 처음 유닛 + 깬 스테이지가 연 유닛 (카드 바 순서는 UnitType 순서).
  List<UnitType> get unlockedUnits {
    final opened = {...startUnits, for (final s in stages) if (cleared(s) && s.unlocks != null) s.unlocks!};
    return UnitType.values.where(opened.contains).toList();
  }

  /// 판이 끝났을 때 기록한다. 별은 최고 기록만 남고, 처음 얻은 별만큼 솔방울을 준다.
  Reward record(StageDef s, {required bool won, required bool usedLog, required bool lostUnit}) {
    final earned = !won ? 0 : 1 + (usedLog ? 0 : 1) + (lostUnit ? 0 : 1);
    final before = starsOf(s);
    final firstClear = won && before == 0;
    final newStars = earned > before ? earned - before : 0;
    if (earned > before) stars[s.id] = earned;
    final gained = newStars * s.pineconesPerStar;
    pinecones += gained;
    return Reward(stars: earned, newStars: newStars, pinecones: gained, unlocked: firstClear ? s.unlocks : null);
  }

  Map<String, Object> toJson() => {'stars': stars, 'pinecones': pinecones, 'upgrades': upgrades};

  factory Progress.fromJson(Map<String, dynamic> j) => Progress(
        stars: (j['stars'] as Map? ?? {}).map((k, v) => MapEntry(k as String, (v as num).toInt())),
        pinecones: (j['pinecones'] as num? ?? 0).toInt(),
        upgrades: (j['upgrades'] as Map? ?? {}).map((k, v) => MapEntry(k as String, (v as num).toInt())),
      );

  /// 저장된 진행을 읽는다. 없거나 깨졌으면 새로 시작.
  static Future<Progress> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      return raw == null ? Progress() : Progress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return Progress();
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(toJson()));
    } catch (_) {
      // 저장이 안 돼도 게임은 계속한다 (예: 브라우저 저장소가 막힌 경우)
    }
  }
}
