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

/// 주울 수 있는 도토리 (14-1단계): 다람쥐가 만들고, 쓰러진 몬스터가 떨어뜨리고, 둥지 문에서 가끔 굴러 나온다
/// (모두 [Acorn.popped]). 하늘에서 떨어지지 않는다.
///
/// 내려앉은 뒤 [lifetime]초가 지나면 사라진다. 마지막 [blinkTime]초는 깜빡인다.
/// 누르거나 까치가 물어 오면 HUD 도토리 칸으로 날아가 [value]만큼 더한다.
class Acorn extends SpriteComponent with TapCallbacks, HasGameReference<ForestGame> {
  Acorn({required Vector2 from, required this.landY, this.fallSpeed = 60, this.value = Garden.acornValue})
      : super(position: from, size: Vector2.all(sizeFor(value)), anchor: Anchor.center, priority: 500);

  /// 다람쥐가 만든 도토리: [from]에서 위로 튀었다가 포물선을 그리며 [toX], [landY]에 떨어진다.
  Acorn.popped({required Vector2 from, required double toX, required this.landY, this.value = Garden.acornValue})
      : fallSpeed = 0,
        super(position: from, size: Vector2.all(sizeFor(value)), anchor: Anchor.center, priority: 500) {
    // 출발점과 떨어질 곳 중 높은 쪽보다 [hop]만큼 위를 꼭대기로 하는 포물선.
    // (떨어질 곳이 출발점보다 위여도 된다: 둥지 문에서 위쪽 레인으로 굴러갈 때. 예전 식은 이때 NaN이 났다, 14-1단계)
    final apex = min(from.y, landY) - hop;
    final upTime = sqrt(2 * (from.y - apex) / gravity);
    final fallTime = sqrt(2 * (landY - apex) / gravity);
    _velocity = Vector2((toX - from.x) / (upTime + fallTime), -gravity * upTime);
  }

  static const double gravity = 1400;

  /// 튀어 오르는 높이 (출발점·떨어질 곳 중 높은 쪽 위로, 논리 px).
  static const double hop = 86;
  Vector2? _velocity;

  static const double displaySize = 46;

  /// 25보다 적은 도토리(몬스터가 떨어뜨린 작은 것)는 작게 그린다.
  static double sizeFor(int value) => value < Garden.acornValue ? 34 : displaySize;

  /// 주우면 더해지는 도토리 수.
  final int value;

  /// 내려앉은 레인 (까치가 자기 근처 레인만 줍는다).
  int get lane => ((landY - GameConfig.fieldY) / GameConfig.cellHeight).floor().clamp(0, GameConfig.rows - 1);

  /// 날아가는 중인지 (두 번 줍지 않게).
  bool get collecting => _collecting;
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
      RemoveEffect(delay: 0.45, onComplete: () => game.garden.addAcorns(value)),
    ]);
  }
}

/// 둥지 문에서 [every]초쯤마다 도토리가 하나 굴러 나와 첫 칸 근처에 떨어진다 (14-1단계, 하늘 도토리 대신).
class NestAcorns extends Component with HasGameReference<ForestGame> {
  NestAcorns({Random? random, required this.every, this.lanes = const [0, 1, 2, 3, 4], this.firstDelay = 4}) : _random = random ?? Random();

  /// 굴러 나오는 간격 (초, ±15% 흔들림). 낮 7, 밤 12 ([StageDef.nestEvery]).
  final double every;

  /// 도토리가 떨어지는 레인 (스테이지가 쓰는 레인).
  final List<int> lanes;

  final Random _random;
  final double firstDelay;
  late double _next = firstDelay;

  @override
  void update(double dt) {
    _next -= dt;
    if (_next > 0) return;
    _next = every * (0.85 + _random.nextDouble() * 0.3);
    final row = lanes[_random.nextInt(lanes.length)];
    final land = Grid.center((row: row, col: 0));
    game.world.add(Acorn.popped(
      from: Vector2(GameConfig.nestDoorX, GameConfig.nestDoorY),
      toX: land.x - 20 + _random.nextDouble() * 40,
      landY: Grid.laneCenterY(row) + 18,
    ));
  }
}
