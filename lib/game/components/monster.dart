import 'package:flame/components.dart';

import '../art.dart';
import '../config.dart';
import '../forest_game.dart';
import '../grid.dart';
import '../monsters.dart';
import 'actor.dart';
import 'flyers.dart';
import 'unit.dart';

/// 레인을 따라 오는 몬스터. 왼쪽을 본다.
///
/// 5단계에서는 제자리에 선 연습 상대로만 쓴다(`?practice=1`). 이동·갉아먹기·웨이브는 6단계.
class Monster extends Actor {
  Monster._({
    required this.type,
    required this.row,
    required super.art,
    required this.slimeArt,
    required super.scale,
    required double x,
  })  : helmetHp = type.helmetHp.toDouble(),
        super(
          maxHp: type.hp,
          startAction: 'walk',
          position: Vector2(x, UnitComponent.footOf((row: row, col: 0)).y - type.floatHeight),
          priority: row * 10 + 5,
        );

  /// 그림을 읽어 몬스터를 만든다. 투구 슬라임은 투구가 깨질 때를 위해 슬라임 그림도 읽는다.
  static Future<Monster> create(ForestGame game, MonsterType type, {required int row, required double x}) async {
    final art = await CharacterArt.load(game, type.sheet);
    final slime = await CharacterArt.load(game, MonsterType.slime.sheet);
    // 투구 슬라임 시트는 몸이 슬라임 시트와 같은 크기로 보이도록 캔버스를 맞춰 두었다 (WORKLOG 3-f).
    // 그래서 같은 배율을 쓴다.
    final scale = type == MonsterType.wisp ? art.scaleForHeight(type.displayHeight) : slime.scaleForHeight(type.displayHeight);
    return Monster._(type: type, row: row, art: art, slimeArt: slime, scale: scale, x: x);
  }

  final MonsterType type;
  final int row;
  final CharacterArt slimeArt;

  /// 남은 투구 HP. 0이 되면 투구가 날아가고 슬라임 시트로 바뀐다.
  double helmetHp;
  bool get hasHelmet => helmetHp > 0;

  /// 맞는 범위의 반폭 (논리 px). 여우불이 x - hitHalfWidth에 닿으면 맞는다.
  static const double hitHalfWidth = 30;

  @override
  String get restAction => 'walk';

  @override
  void takeDamage(double amount) {
    if (!alive) return;
    if (hasHelmet) {
      final absorbed = amount < helmetHp ? amount : helmetHp;
      helmetHp -= absorbed;
      amount -= absorbed;
      if (!hasHelmet) _loseHelmet();
      if (amount <= 0) {
        // 투구가 막았어도 맞은 티는 낸다
        super.takeDamage(0);
        return;
      }
    }
    super.takeDamage(amount);
  }

  void _loseHelmet() {
    animations = {for (final a in slimeArt.actions) a: slimeArt.animation(a)};
    play(restAction);
    game.world.add(FlyingHelmet(position: absolutePosition - Vector2(0, size.y * 0.55)));
  }

  @override
  CharacterArt get art => hasHelmet || type != MonsterType.helmetSlime ? super.art : slimeArt;

  @override
  void onDeath() => game.monsters.remove(this);

  /// 이 몬스터가 있는 칸 (필드 밖이면 null).
  Cell? get cell => Grid.cellAt(Vector2(position.x, Grid.laneCenterY(row)));

  /// 화면 오른쪽 끝보다 안쪽에 들어왔는지 (여우가 쏘기 시작하는 기준).
  bool get onScreen => position.x < GameConfig.width;
}
