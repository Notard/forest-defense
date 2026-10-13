import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';

import '../config.dart';
import '../forest_game.dart';
import '../garden.dart';
import '../grid.dart';
import '../sfx.dart';

/// 주울 수 있는 도토리. 하늘에서 떨어지거나(4단계) 다람쥐가 만든다(5단계, [Acorn.popped]).
///
/// 떨어지는 동안 살랑 흔들리고, 내려앉은 뒤 [lifetime]초가 지나면 사라진다.
/// 마지막 [blinkTime]초는 깜빡인다. 누르면 HUD 도토리 칸으로 날아가 +25.
class Acorn extends SpriteComponent with TapCallbacks, HasGameReference<ForestGame> {
  Acorn({required Vector2 from, required this.landY, this.fallSpeed = 60})
      : super(position: from, size: Vector2.all(displaySize), anchor: Anchor.center, priority: 500);

  /// 다람쥐가 만든 도토리: [from]에서 위로 튀었다가 포물선을 그리며 [toX], [landY]에 떨어진다.
  Acorn.popped({required Vector2 from, required double toX, required this.landY})
      : fallSpeed = 0,
        super(position: from, size: Vector2.all(displaySize), anchor: Anchor.center, priority: 500) {
    // 위로 0.35초 튀어 오르는 속도와, 그 뒤 landY에 닿을 때까지 걸리는 시간으로 가로 속도를 정한다
    const up = 0.35;
    final vy = -gravity * up;
    final rise = gravity * up * up / 2;
    final fallTime = sqrt(2 * (landY - from.y + rise) / gravity);
    _velocity = Vector2((toX - from.x) / (up + fallTime), vy);
  }

  static const double gravity = 1400;
  Vector2? _velocity;

  static const double displaySize = 46;
  static const double lifetime = 10; // 8 → 10 (7-1단계: 줍기 전에 사라지는 일이 잦았다)
  static const double blinkTime = 2;

  final double landY;
  final double fallSpeed;
  double _age = 0;
  double _landedFor = 0;
  bool _collecting = false;

  bool get landed => _velocity == null && position.y >= landY;

  @override
  Future<void> onLoad() async {
    sprite = Sprite(await game.images.load('fx/acorn.webp'));
  }

  /// 손가락으로 누르기 쉽게 실제 그림보다 넓게 받는다.
  @override
  bool containsLocalPoint(Vector2 point) => (point - size / 2).length < 40;

  @override
  void update(double dt) {
    super.update(dt);
    if (_collecting) return;
    _age += dt;
    final v = _velocity;
    if (v != null) {
      v.y += gravity * dt;
      position += v * dt;
      angle += dt * 8;
      if (v.y > 0 && position.y >= landY) {
        position.y = landY;
        _velocity = null;
      }
      return;
    }
    if (!landed) {
      position.y = min(landY, position.y + fallSpeed * dt);
      angle = sin(_age * 3) * 0.25;
      return;
    }
    angle = 0;
    _landedFor += dt;
    final left = lifetime - _landedFor;
    if (left <= 0) {
      removeFromParent();
    } else if (left < blinkTime) {
      opacity = (sin(_landedFor * 18) > 0) ? 1 : 0.35;
    }
  }

  @override
  void onTapDown(TapDownEvent event) => collect();

  /// HUD로 날아가 도토리를 더한다. 이미 날아가는 중이면 무시.
  void collect() {
    if (_collecting) return;
    _collecting = true;
    game.sfx.play(Sfx.pickup);
    opacity = 1;
    angle = 0;
    priority = 1100; // HUD 위로
    addAll([
      MoveEffect.to(game.hud.acornCounter.target, EffectController(duration: 0.45, curve: Curves.easeInCubic)),
      ScaleEffect.to(Vector2.all(0.7), EffectController(duration: 0.45)),
      RemoveEffect(delay: 0.45, onComplete: () => game.garden.addAcorns(Garden.acornValue)),
    ]);
  }
}

/// 7~10초마다 무작위 칸 위로 도토리를 떨어뜨린다. 첫 도토리는 [firstDelay]초 뒤.
class SkyAcornSpawner extends Component with HasGameReference<ForestGame> {
  SkyAcornSpawner({Random? random, this.firstDelay = 4}) : _random = random ?? Random();

  static const double minGap = 5, maxGap = 8; // 7~10 → 5~8 (7-1단계)

  final Random _random;
  final double firstDelay;
  late double _next = firstDelay;

  @override
  void update(double dt) {
    _next -= dt;
    if (_next > 0) return;
    _next = minGap + _random.nextDouble() * (maxGap - minGap);
    final col = _random.nextInt(GameConfig.cols);
    final row = _random.nextInt(GameConfig.rows);
    final x = Grid.center((row: row, col: col)).x;
    game.world.add(Acorn(from: Vector2(x, GameConfig.fieldY - 30), landY: Grid.laneCenterY(row) + 18));
  }
}
