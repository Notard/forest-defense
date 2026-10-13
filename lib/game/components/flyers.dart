import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

import '../forest_game.dart';

/// 깨진 투구: 위로 튀어 돌며 떨어지고 흐려진다 (plan.md 3-5).
class FlyingHelmet extends SpriteComponent with HasGameReference<ForestGame> {
  FlyingHelmet({required Vector2 position})
      : super(position: position, size: Vector2(64, 56), anchor: Anchor.center, priority: 850);

  @override
  Future<void> onLoad() async {
    sprite = Sprite(await game.images.load('fx/helmet.webp'));
    const t = 0.7;
    addAll([
      // 몬스터 뒤쪽(오른쪽)으로 포물선
      MoveByEffect(Vector2(40, 0), EffectController(duration: t)),
      SequenceEffect([
        MoveByEffect(Vector2(0, -50), EffectController(duration: t * 0.4, curve: Curves.easeOut)),
        MoveByEffect(Vector2(0, 80), EffectController(duration: t * 0.6, curve: Curves.easeIn)),
      ]),
      RotateEffect.by(pi * 1.5, EffectController(duration: t)),
      OpacityEffect.fadeOut(EffectController(duration: t * 0.5, startDelay: t * 0.5)),
      RemoveEffect(delay: t),
    ]);
  }
}
