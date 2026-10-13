import 'dart:math';

import 'package:flame/components.dart';

import '../art.dart';
import '../config.dart';
import '../grid.dart';
import '../sfx.dart';
import '../units.dart';
import 'acorn.dart';
import 'actor.dart';
import 'fireball.dart';
import 'smoke.dart';

/// 칸에 놓인 동물. 발이 칸 바닥에 오도록 세운다. 능력은 동물별 하위 클래스에 있다 (plan.md 5단계).
abstract class UnitComponent extends Actor {
  UnitComponent._({required this.type, required this.cell, required super.art})
      : super(
          maxHp: type.maxHp,
          scale: art.scaleForHeight(type.displayHeight),
          startAction: type.idleAction,
          position: footOf(cell),
          // 아래 레인일수록 앞에 그린다 (위 레인 유닛의 머리를 덮도록)
          priority: cell.row * 10 + 1,
        );

  factory UnitComponent({required UnitType type, required Cell cell, required CharacterArt art}) => switch (type) {
        UnitType.squirrel => Squirrel(cell: cell, art: art),
        UnitType.fox => Fox(cell: cell, art: art),
        UnitType.turtle => Turtle(cell: cell, art: art),
        UnitType.skunk => Skunk(cell: cell, art: art),
      };

  final UnitType type;
  final Cell cell;

  /// 칸 안에서 발이 닿는 위치: 가로 가운데, 칸 아래 끝에서 [footInset] 위.
  static Vector2 footOf(Cell cell) =>
      Grid.topLeft(cell) + Vector2(GameConfig.cellWidth / 2, GameConfig.cellHeight - footInset);

  static const double footInset = 8;

  @override
  String get restAction => 'idle';

  @override
  void onDeath() {
    game.garden.remove(cell);
    game.unitComponents.remove(cell);
  }

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
      _next = interval;
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
    game.world.add(Fireball(position: framePointToWorld(art.muzzle!), row: cell.row));
  }
}

/// 거북이: 공격 없이 HP 4000으로 막는다. 절반 아래로 떨어지면 금 간 등껍질.
class Turtle extends UnitComponent {
  Turtle({required super.cell, required super.art}) : super._(type: UnitType.turtle);

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

  void _blast() {
    game.sfx.play(Sfx.boom);
    final center = framePointToWorld(art.muzzle!);
    game.world.add(Smoke(position: center, size: GameConfig.cellWidth * 2.6, duration: 0.7));
    for (final m in game.monsters.toList()) {
      if ((m.row - cell.row).abs() <= 1 && (m.position.x - position.x).abs() <= GameConfig.cellWidth * 1.5) {
        m.takeDamage(damage);
      }
    }
  }

  void _finish() {
    hp = 0; // 반복 동작으로 돌아가지 않게
    onDeath();
    removeFromParent();
  }
}
