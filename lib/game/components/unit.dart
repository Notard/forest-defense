import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

import '../art.dart';
import '../config.dart';
import '../grid.dart';
import '../sfx.dart';
import '../units.dart';
import '../upgrades.dart';
import 'acorn.dart';
import 'actor.dart';
import 'fireball.dart';
import 'level_bubble.dart';
import 'hoot_wave.dart';
import 'monster.dart';
import 'smoke.dart';

/// 칸에 놓인 동물. 발이 칸 바닥에 오도록 세운다. 능력은 동물별 하위 클래스에 있다 (plan.md 5단계).
abstract class UnitComponent extends Actor {
  UnitComponent._({required this.type, required this.cell, required super.art, int? maxHp})
      : baseMaxHp = maxHp ?? type.maxHp,
        super(
          maxHp: maxHp ?? type.maxHp,
          scale: art.scaleForHeight(type.displayHeight),
          startAction: type.idleAction,
          position: footOf(cell),
          // 아래 레인일수록 앞에 그린다 (위 레인 유닛의 머리를 덮도록)
          priority: cell.row * 10 + 1,
        );

  factory UnitComponent({required UnitType type, required Cell cell, required CharacterArt art, Boosts boosts = Boosts.none}) =>
      switch (type) {
        UnitType.squirrel => Squirrel(cell: cell, art: art),
        UnitType.fox => Fox(cell: cell, art: art),
        UnitType.turtle => Turtle(cell: cell, art: art, maxHp: boosts.maxHpOf(type)),
        UnitType.skunk => Skunk(cell: cell, art: art),
        UnitType.hedgehog => Hedgehog(cell: cell, art: art),
        UnitType.owl => Owl(cell: cell, art: art),
        UnitType.bear => Bear(cell: cell, art: art),
        UnitType.magpie => Magpie(cell: cell, art: art),
      };

  final UnitType type;
  final Cell cell;

  // ── 판 안 레벨업 (12-2단계) ──
  static const int maxLevel = 3;

  /// 1~3. 놓은 친구를 누르면 도토리를 내고 올린다.
  int level = 1;

  /// 주 능력 배율: Lv1 1.0, Lv2 1.4, Lv3 1.8.
  double get power => 1 + 0.4 * (level - 1);

  /// 레벨을 올릴 수 있는지 (스컨크는 놓자마자 터지니 없음).
  bool get canLevel => alive && type != UnitType.skunk && level < maxLevel;

  /// Lv1 최대 HP (강화 상점 반영). 거북이·고슴도치는 레벨마다 이것의 [power]배가 된다.
  final int baseMaxHp;

  void levelUp() {
    if (!canLevel) return;
    level++;
    if (type == UnitType.turtle || type == UnitType.hedgehog) {
      final grown = (baseMaxHp * power).round();
      hp += grown - maxHp;
      maxHp = grown;
    }
    onLevelUp();
    game.world.add(LevelSparkle(position: position - Vector2(0, type.displayHeight * 0.5)));
    add(SequenceEffect([
      ScaleEffect.to(Vector2.all(1.18), EffectController(duration: 0.1)),
      ScaleEffect.to(Vector2.all(1), EffectController(duration: 0.22, curve: Curves.easeOutBack)),
    ]));
  }

  /// 레벨이 오른 뒤 친구별 처리 (기본은 없음).
  void onLevelUp() {}

  static final _starFill = Paint()..color = const Color(0xFFFFD34D);
  static final _starRim = Paint()
    ..color = const Color(0xFF4A3220)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  /// 발밑에 레벨 별 (Lv2 하나, Lv3 둘).
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (level < 2) return;
    final foot = Offset(size.x * anchor.x, size.y * anchor.y);
    final n = level - 1;
    final s = 1 / scale.x; // 통 튀는 동안에도 별 크기는 그대로
    for (var i = 0; i < n; i++) {
      final c = foot + Offset((i - (n - 1) / 2) * 20 * s, 2);
      final p = starPath(c, 9 * s);
      canvas.drawPath(p, _starFill);
      canvas.drawPath(p, _starRim);
    }
  }

  /// 칸 안에서 발이 닿는 위치: 가로 가운데, 칸 아래 끝에서 [footInset] 위.
  static Vector2 footOf(Cell cell) =>
      Grid.topLeft(cell) + Vector2(GameConfig.cellWidth / 2, GameConfig.cellHeight - footInset);

  static const double footInset = 8;

  @override
  String get restAction => 'idle';

  @override
  Color get hpBarColor => const Color(0xFF8BD45C);

  @override
  void onDeath() {
    game.garden.remove(cell);
    game.unitComponents.remove(cell);
  }

  /// 몬스터가 한 입 깨문 뒤 (고슴도치 가시). 기본은 아무것도 안 함.
  void onBitten(Monster by) {}

  /// 몬스터에게 쓰러짐 (★★★를 잃는다). 스컨크가 스스로 터지는 것은 die를 거치지 않는다.
  @override
  void die() {
    game.lostUnit = true;
    super.die();
  }
}

/// 다람쥐: 놓고 7초 뒤, 그 뒤로 24초마다 도토리를 만든다. 만들기 5번째 프레임에 도토리가 튀어나온다.
class Squirrel extends UnitComponent {
  Squirrel({required super.cell, required super.art}) : super._(type: UnitType.squirrel);

  static const double firstDelay = 5, interval = 18; // 7·24 → 5·18 (7-1단계)
  double _next = firstDelay;
  final _random = Random();

  @override
  void update(double dt) {
    super.update(dt);
    if (!alive) return;
    _next -= dt;
    if (_next <= 0 && !busy) {
      _next = interval * game.boosts.squirrelInterval / power;
      play('produce', onEvent: _popAcorn);
    }
  }

  void _popAcorn() {
    final from = framePointToWorld(art.muzzle!);
    final land = position.x + 34 + _random.nextDouble() * 30;
    game.world.add(Acorn.popped(from: from, toX: land, landY: position.y - 12));
  }
}

/// 여우: 같은 레인 앞(오른쪽)에 몬스터가 있으면 1.5초마다 여우불. 공격 5번째 프레임에 발사.
class Fox extends UnitComponent {
  Fox({required super.cell, required super.art}) : super._(type: UnitType.fox);

  static const double interval = 1.5;
  double _reload = 0;

  /// 같은 레인, 여우보다 오른쪽, 화면 안에 살아 있는 몬스터가 있는지.
  bool get hasTarget => game.monsters.any((m) => m.alive && m.row == cell.row && m.position.x > position.x && m.onScreen);

  @override
  void update(double dt) {
    super.update(dt);
    if (!alive) return;
    _reload -= dt;
    if (_reload <= 0 && !busy && hasTarget) {
      _reload = interval;
      play('attack', onEvent: _shoot);
    }
  }

  void _shoot() {
    game.sfx.play(Sfx.shot);
    game.world.add(Fireball(position: framePointToWorld(art.muzzle!), row: cell.row, power: Fireball.damage * game.boosts.foxDamage * power));
  }
}

/// 거북이: 공격 없이 HP 4000으로 막는다. 절반 아래로 떨어지면 금 간 등껍질.
class Turtle extends UnitComponent {
  Turtle({required super.cell, required super.art, super.maxHp}) : super._(type: UnitType.turtle);

  bool get cracked => hp < maxHp / 2;

  @override
  String get restAction => cracked ? 'idle_cracked' : 'idle';

  @override
  void onHurt() {
    if (cracked && current == 'idle') play('idle_cracked');
  }
}

/// 스컨크: 놓으면 1.2초 동안 부풀다(arm) 폭발한다. 폭발 3번째 프레임에 주변 3 × 3칸 몬스터에게 큰 피해.
class Skunk extends UnitComponent {
  Skunk({required super.cell, required super.art}) : super._(type: UnitType.skunk);

  static const double damage = 1800;

  @override
  String get restAction => 'arm';

  @override
  void onMount() {
    super.onMount();
    play('arm', onDone: () => play('explode', onEvent: _blast, onDone: _finish));
  }

  /// 방귀 구름이 닿는 거리 (자기 칸 반 칸 뒤 ~ 앞 [reachCells]칸), 밀어내는 거리 (14-1단계: 3 × 3 폭발 대신).
  static const double reachCells = 3, pushCells = 1;
  static const _stink = Color(0xFFB8E07A);

  bool inCloud(Monster m) {
    final dx = m.position.x - position.x;
    return m.alive && m.row == cell.row && dx >= -GameConfig.cellWidth * 0.5 && dx <= GameConfig.cellWidth * (reachCells + 0.2);
  }

  void _blast() {
    game.sfx.play(Sfx.boom);
    for (var i = 0; i < reachCells; i++) {
      game.world.add(Smoke(
        position: Vector2(position.x + GameConfig.cellWidth * (i + 0.6), position.y - type.displayHeight * 0.45),
        size: GameConfig.cellWidth * 1.5,
        duration: 0.8,
        cloudColor: _stink,
      ));
    }
    for (final m in game.monsters.where(inCloud).toList()) {
      m.takeDamage(damage);
      if (m.alive) m.knockBack(GameConfig.cellWidth * pushCells);
    }
  }

  void _finish() {
    hp = 0; // 반복 동작으로 돌아가지 않게
    onDeath();
    removeFromParent();
  }
}

/// 고슴도치: HP 2500으로 막고, 깨물 때마다 가시로 그 몬스터에게 [spineDamage]를 돌려준다 (10단계).
class Hedgehog extends UnitComponent {
  Hedgehog({required super.cell, required super.art}) : super._(type: UnitType.hedgehog);

  static const double spineDamage = 20;

  @override
  void onBitten(Monster by) {
    game.sfx.play(Sfx.spine);
    by.takeDamage(spineDamage * game.boosts.spineDamage * power);
  }
}

/// 부엉이: 같은 레인 앞에 몬스터가 있으면 [interval]초마다 부엉! 레인 앞쪽 몬스터 모두를 [slowSeconds]초 동안 반 속도로 (10단계).
/// 부엉 4번째 프레임(날개를 펼칠 때)에 소리 물결이 퍼진다.
class Owl extends UnitComponent {
  Owl({required super.cell, required super.art}) : super._(type: UnitType.owl);

  static const double interval = 4, slowSeconds = 3;
  double _reload = 0.5;

  Iterable<Monster> get _ahead => game.monsters.where((m) => m.alive && m.row == cell.row && m.position.x > position.x - 20 && m.onScreen);

  @override
  void update(double dt) {
    super.update(dt);
    if (!alive) return;
    _reload -= dt;
    if (_reload <= 0 && !busy && _ahead.isNotEmpty) {
      _reload = interval;
      play('hoot', onEvent: _hoot);
    }
  }

  void _hoot() {
    game.sfx.play(Sfx.hoot);
    game.world.add(HootWave(from: framePointToWorld(art.muzzle!), row: cell.row));
    for (final m in _ahead.toList()) {
      m.slow((slowSeconds + game.boosts.owlSlowExtra) * power);
    }
  }
}

/// 곰: 바로 앞 [reachCells]칸 안에 몬스터가 오면 [interval]초마다 앞발로 내려쳐 그 안의 몬스터 모두에게 [damage] (10단계).
/// 내려치기 5번째 프레임에 맞는다.
class Bear extends UnitComponent {
  Bear({required super.cell, required super.art}) : super._(type: UnitType.bear);

  static const double interval = 1.8, damage = 90, reachCells = 1.2;
  double _reload = 0;

  bool _inReach(Monster m) {
    final dx = m.position.x - position.x;
    return m.alive && m.row == cell.row && dx >= -GameConfig.cellWidth * 0.3 && dx <= GameConfig.cellWidth * reachCells;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!alive) return;
    _reload -= dt;
    if (_reload <= 0 && !busy && game.monsters.any(_inReach)) {
      _reload = interval;
      play('attack', onEvent: _swipe);
    }
  }

  void _swipe() {
    game.sfx.play(Sfx.swipe);
    final paw = framePointToWorld(art.muzzle!);
    game.world.add(Smoke(position: Vector2(paw.x, position.y - 14), size: GameConfig.cellWidth * 0.8, duration: 0.35));
    for (final m in game.monsters.where(_inReach).toList()) {
      m.takeDamage(damage * game.boosts.bearDamage * power);
    }
  }
}

/// 까치 (14-1단계): 자기 레인과 위아래 한 레인(모두 3레인)에 내려앉은 도토리를 [gap]초에 하나씩 물어 온다.
/// '깍!' 4번째 프레임에 도토리가 HUD로 날아간다. 레벨이 오르면 더 빨리.
class Magpie extends UnitComponent {
  Magpie({required super.cell, required super.art}) : super._(type: UnitType.magpie);

  static const double gap = 0.9;
  static const int reachLanes = 1;
  double _next = 0.5;

  bool _reaches(Acorn a) => a.landed && !a.collecting && (a.lane - cell.row).abs() <= reachLanes;

  @override
  void update(double dt) {
    super.update(dt);
    if (!alive) return;
    _next -= dt;
    if (_next > 0 || busy) return;
    final target = game.world.children.whereType<Acorn>().where(_reaches).firstOrNull;
    if (target == null) return;
    _next = gap / power;
    play('call', onEvent: () {
      if (target.isMounted && !target.collecting) target.collect();
    });
  }
}
