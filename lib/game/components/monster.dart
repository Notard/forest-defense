import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../art.dart';
import '../config.dart';
import '../forest_game.dart';
import '../grid.dart';
import '../monsters.dart';
import '../stages.dart';
import '../sfx.dart';
import 'actor.dart';
import 'flyers.dart';
import 'smoke.dart';
import 'unit.dart';

/// 레인을 따라 오는 몬스터. 왼쪽을 보고 걸어오다 앞에 동물이 있으면 멈춰 갉아먹는다 (plan.md 6단계).
///
/// [moving]이 false면 제자리에 선 연습 상대다 (`?practice=1`).
class Monster extends Actor {
  Monster._({
    required this.type,
    required this.row,
    required super.art,
    required this.slimeArt,
    required super.scale,
    required double x,
    required super.maxHp,
    this.moving = true,
  })  : helmetHp = type.helmetHp.toDouble(),
        groundY = UnitComponent.footOf((row: row, col: 0)).y - type.floatHeight,
        super(
          startAction: 'walk',
          position: Vector2(x, UnitComponent.footOf((row: row, col: 0)).y - type.floatHeight),
          priority: row * 10 + 5,
        );

  /// 그림을 읽어 몬스터를 만든다. 투구 슬라임은 투구가 깨질 때를 위해 슬라임 그림도 읽는다.
  static Future<Monster> create(ForestGame game, MonsterType type, {required int row, required double x, bool moving = true}) async {
    final art = await CharacterArt.load(game, type.sheet);
    final slime = await CharacterArt.load(game, MonsterType.slime.sheet);
    // 투구 슬라임 시트는 몸이 슬라임 시트와 같은 크기로 보이도록 캔버스를 맞춰 두었다 (WORKLOG 3-f).
    // 그래서 슬라임·투구 슬라임은 슬라임 배율, 나머지는 제 그림 배율.
    final sharesSlime = type == MonsterType.slime || type == MonsterType.helmetSlime;
    final scale = (sharesSlime ? slime : art).scaleForHeight(type.displayHeight);
    final hp = type.boss && game.stage.region == Region.night ? MonsterType.nightBossHp : type.hp;
    return Monster._(type: type, row: row, art: art, slimeArt: slime, scale: scale, x: x, maxHp: hp, moving: moving);
  }

  final MonsterType type;
  final int row;
  final CharacterArt slimeArt;

  /// 남은 투구 HP. 0이 되면 투구가 날아가고 슬라임 시트로 바뀐다.
  double helmetHp;
  bool get hasHelmet => helmetHp > 0;

  /// 슬라임의 맞는 범위 반폭 (논리 px). 종류별 값은 [MonsterType.hitHalfWidth].
  static const double hitHalfWidth = 30;

  /// 땅(떠 있는 몬스터는 떠 있는 높이)의 y. 박쥐가 뛰어넘을 때 여기서 위로 호를 그린다.
  final double groundY;

  /// 걷는지 (false면 연습 상대).
  final bool moving;

  /// 걷는 속도 (논리 px/초).
  double get speed => GameConfig.cellWidth / type.secondsPerCell;

  /// 슬라임이 멈춰 갉아먹는 거리 (동물 발 x에서 오른쪽으로). 종류별 값은 [MonsterType.biteReach].
  static const double biteReach = 52;

  // ── 박쥐 뛰어넘기 (11단계) ──
  /// 이미 한 번 뛰어넘었는지 (한 마리만 넘는다).
  bool jumped = false;
  double? _jumpFrom, _jumpTo;
  double _jumpT = 0;
  static const double jumpTime = 0.6, jumpHeight = 70;
  bool get jumping => _jumpTo != null;

  // ── 보스 소환 (11단계) ──
  /// 지금까지 소환한 횟수 (HP 75%·50%·25%에서 한 번씩).
  int summons = 0;

  /// 지금 갉아먹는 동물 (없으면 null).
  UnitComponent? eating;

  /// 부엉이 감속이 남은 시간 (10단계). 그동안 걸음과 갉아먹기(애니메이션 시계)가 [slowFactor]배로 느려진다.
  double slowTime = 0;
  static const double slowFactor = 0.5;
  bool get slowed => slowTime > 0;

  void slow(double seconds) {
    if (seconds > slowTime) slowTime = seconds;
  }

  static final _slowTint = ColorFilter.mode(const Color(0x664FA8FF), BlendMode.srcATop);

  @override
  ColorFilter? get standingTint => slowed ? _slowTint : null;

  @override
  String get restAction => 'walk';

  @override
  bool get canFlinch => eating == null;

  /// 같은 레인에서 바로 앞(왼쪽)에 붙은 살아 있는 동물.
  UnitComponent? _blocker() {
    UnitComponent? found;
    for (final u in game.unitComponents.values) {
      if (u.cell.row != row || !u.alive) continue;
      final gap = position.x - u.position.x;
      if (gap >= -10 && gap <= type.biteReach && (found == null || u.position.x > found.position.x)) found = u;
    }
    return found;
  }

  /// 갉아먹기 한 번(시트 이벤트 프레임)의 피해 = 초당 피해 × 한 바퀴 시간.
  double get biteDamage {
    final cycle = art.frameCount('eat') / art.fps('eat');
    return type.biteDps * cycle;
  }

  @override
  void update(double dt) {
    if (slowed) {
      slowTime -= dt;
      dt *= slowFactor;
    }
    super.update(dt);
    if (!alive || !moving) return;
    if (jumping) {
      _flyOver(dt);
      return;
    }
    final target = _blocker();
    if (target != null && type.jumpsOver && !jumped && !slowed) {
      _startJump(target);
      return;
    }
    if (target != null) {
      if (eating != target || current != 'eat') {
        eating = target;
        play('eat', onEvent: () {
          if (eating?.alive ?? false) {
            game.sfx.play(Sfx.bite);
            final bitten = eating!;
            bitten.takeDamage(biteDamage);
            bitten.onBitten(this);
          }
        });
      }
      return;
    }
    if (eating != null) {
      eating = null;
      play('walk');
    }
    position.x -= speed * dt;
    if (position.x < reachedHomeX) game.onMonsterReachedHome(this);
  }

  /// 박쥐: 앞 동물 너머(왼쪽 0.75칸)로 호를 그리며 날아간다. 부엉이로 느려졌으면 못 넘는다.
  void _startJump(UnitComponent over) {
    jumped = true;
    eating = null;
    _jumpFrom = position.x;
    _jumpTo = over.position.x - GameConfig.cellWidth * 0.75;
    _jumpT = 0;
    play('walk');
  }

  void _flyOver(double dt) {
    _jumpT = (_jumpT + dt / jumpTime).clamp(0.0, 1.0);
    position.x = _jumpFrom! + (_jumpTo! - _jumpFrom!) * _jumpT;
    position.y = groundY - math.sin(math.pi * _jumpT) * jumpHeight;
    if (_jumpT >= 1) {
      position.y = groundY;
      _jumpFrom = _jumpTo = null;
    }
    if (position.x < reachedHomeX) game.onMonsterReachedHome(this);
  }

  /// 보스: HP가 25%씩 줄 때마다 슬라임 둘을 위아래 레인(없으면 같은 레인 뒤)에 불러낸다.
  void _summonIfNeeded() {
    while (alive && summons < 3 && hp <= maxHp * (1 - 0.25 * (summons + 1))) {
      summons++;
      game.sfx.play(Sfx.warning);
      final rows = [row - 1, row + 1].where(game.laneOpen).toList();
      final spots = rows.length == 2 ? [(rows[0], 0.0), (rows[1], 0.0)] : [(row, 70.0), (row, 140.0)];
      for (final (r, back) in spots) {
        final x = position.x + 40 + back;
        game.world.add(Smoke(position: Vector2(x, UnitComponent.footOf((row: r, col: 0)).y - 30), size: 80, duration: 0.4));
        game.addMonster(MonsterType.slime, row: r, x: x);
      }
    }
  }

  /// 이 x보다 왼쪽에 닿으면 둥지에 닿은 것 (그 레인 통나무를 이미 썼으면 게임오버).
  static const double reachedHomeX = GameConfig.logColumnX - 60;

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
    if (type.boss) _summonIfNeeded();
  }

  void _loseHelmet() {
    game.sfx.play(Sfx.helmet);
    animations = {for (final a in slimeArt.actions) a: slimeArt.animation(a)};
    play(restAction);
    game.world.add(FlyingHelmet(position: absolutePosition - Vector2(0, size.y * 0.55)));
  }

  @override
  CharacterArt get art => hasHelmet || type != MonsterType.helmetSlime ? super.art : slimeArt;

  @override
  void onDeath() {
    game.monsters.remove(this);
    game.defeated++;
    game.sfx.play(Sfx.slimeDie);
    // 버섯 포자: 작은 버섯으로 나뉜다 (addMonster는 부르자마자 대기 수를 올려서, 이 사이에 클리어로 판정되지 않는다)
    for (var i = 0; i < type.splitsInto; i++) {
      game.addMonster(MonsterType.miniMushroom, row: row, x: position.x - 24 + i * 52);
    }
  }

  /// 이 몬스터가 있는 칸 (필드 밖이면 null).
  Cell? get cell => Grid.cellAt(Vector2(position.x, Grid.laneCenterY(row)));

  /// 화면 오른쪽 끝보다 안쪽에 들어왔는지 (여우가 쏘기 시작하는 기준).
  bool get onScreen => position.x < GameConfig.width;
}
