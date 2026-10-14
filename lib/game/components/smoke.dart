import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

import '../forest_game.dart';

/// 쓰러짐·폭발 연기: 커지며 흐려지고 사라진다 (plan.md 3-5).
class Smoke extends SpriteComponent with HasGameReference<ForestGame> {
  Smoke({required Vector2 position, required double size, this.duration = 0.6, this.cloudColor})
      : super(
          position: position,
          size: Vector2(size, size * 160 / 192),
          anchor: Anchor.center,
          priority: 800,
          scale: Vector2.all(0.35),
        );

  final double duration;

  /// 구름 색 (스컨크 방귀는 연두). 없으면 그림 그대로.
  final Color? cloudColor;

  @override
  Future<void> onLoad() async {
    sprite = Sprite(await game.images.load('fx/smoke.webp'));
    final t = cloudColor;
    if (t != null) paint.colorFilter = ColorFilter.mode(t, BlendMode.modulate);
    addAll([
      ScaleEffect.to(Vector2.all(1), EffectController(duration: duration, curve: Curves.easeOutCubic)),
      OpacityEffect.fadeOut(EffectController(duration: duration, startDelay: duration * 0.3)),
      RemoveEffect(delay: duration * 1.3),
    ]);
  }
}
