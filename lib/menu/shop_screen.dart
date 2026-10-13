import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../game/art.dart';
import '../game/config.dart';
import '../game/hud/panel.dart';
import '../game/sfx.dart';
import '../game/stages.dart';
import '../game/strings.dart';
import '../game/upgrades.dart';
import 'menu_game.dart';

const _ink = Color(0xFF4A3220);

TextPaint _text(double size, Color color, {double shadow = 0}) => TextPaint(
      style: TextStyle(
        fontFamily: GameConfig.fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: size,
        color: color,
        shadows: shadow == 0 ? null : [Shadow(color: const Color(0xCC2E1A0A), offset: Offset(0, shadow))],
      ),
    );

/// 강화 상점 (12단계): 강화 8가지를 4 × 2 카드로. 카드를 누르면 솔방울을 내고 한 단계 올린다.
class ShopScreen extends PositionComponent with HasGameReference<MenuGame> {
  ShopScreen() : super(size: Vector2(GameConfig.width, GameConfig.height));

  static const double cardW = 280, cardH = 250, gap = 24, top = 140;

  /// [i]번째 강화 카드 자리 (논리 좌표).
  static Rect cardRect(int i) {
    const left = (GameConfig.width - 4 * cardW - 3 * gap) / 2;
    return Rect.fromLTWH(left + (i % 4) * (cardW + gap), top + (i ~/ 4) * (cardH + gap), cardW, cardH);
  }

  late final Sprite _background;
  late final Sprite pinecone;
  final _shade = Paint()..color = const Color(0x8C000000);
  late final _count = _text(40, const Color(0xFFFFF4DC), shadow: 3);

  @override
  Future<void> onLoad() async {
    _background = Sprite(await game.images.load('fx/background.webp'));
    pinecone = Sprite(await game.images.load('fx/pinecone.webp'));
    final acorn = Sprite(await game.images.load('fx/acorn.webp'));
    add(TextComponent(text: Strings.shop, textRenderer: _text(64, const Color(0xFFFFF4DC), shadow: 5), anchor: Anchor.center, position: Vector2(640, 62)));
    add(TextComponent(text: Strings.shopHint, textRenderer: _text(26, const Color(0xFFFFE6A8), shadow: 2), anchor: Anchor.center, position: Vector2(640, 694)));
    add(PanelButton(Strings.toMap, () => game.show(MenuPage.map))..position = Vector2(24, 26));
    for (final (i, u) in Upgrade.values.indexed) {
      final portrait = u.unit == null ? acorn : await _portrait(u);
      add(UpgradeCard(u, portrait, cardRect(i)));
    }
  }

  /// 유닛 초상화: 기본 동작 첫 프레임에서 그림이 있는 영역만 (HUD 카드와 같은 방법).
  Future<Sprite> _portrait(Upgrade u) async {
    final art = await CharacterArt.load(game, u.unit!.sheet);
    final b = art.bbox;
    final full = art.firstFrame(u.unit!.idleAction);
    return Sprite(full.image, srcPosition: Vector2(b.left, b.top), srcSize: Vector2(b.width, b.height));
  }

  @override
  void render(Canvas canvas) {
    _background.render(canvas, size: size);
    canvas.drawRect(size.toRect(), _shade);
    // 오른쪽 위 솔방울 수
    final text = '${game.progress.pinecones}';
    final w = _count.getLineMetrics(text).width;
    _count.render(canvas, text, Vector2(1250, 62), anchor: Anchor.centerRight);
    pinecone.render(canvas, position: Vector2(1250 - w - 8, 62), size: Vector2.all(56), anchor: Anchor.centerRight);
  }
}

/// 강화 카드 하나: 초상화, 이름, 단계마다 오르는 것, 단계 칸 3개, 값 버튼.
/// 아직 못 만난 유닛은 자물쇠와 "1-2 깨면 열려요".
class UpgradeCard extends PositionComponent with TapCallbacks, HasGameReference<MenuGame> {
  UpgradeCard(this.upgrade, this._portrait, Rect slot)
      : super(position: slot.center.toVector2(), size: slot.size.toVector2(), anchor: Anchor.center);

  final Upgrade upgrade;
  final Sprite _portrait;

  final _wood = Paint()..color = const Color(0xFFE9D3A6);
  final _rim = Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4;
  final _dim = Paint()..color = const Color(0xA0302418);
  final _pipOn = Paint()..color = const Color(0xFFFFD34D);
  final _pipOff = Paint()..color = const Color(0x334A3220);
  final _pipRim = Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;
  final _buy = Paint()..color = const Color(0xFF7BC96F);
  final _cannot = Paint()..color = const Color(0xFFBDB3A0);
  final _done = Paint()..color = const Color(0xFFFFD34D);
  late final _name = _text(36, _ink);
  late final _effect = _text(24, const Color(0xFF6B4A2E));
  late final _price = _text(30, _ink);
  late final _note = _text(30, const Color(0xFFFFF4DC), shadow: 2);
  double _t = 0;

  int get level => game.progress.levelOf(upgrade);
  bool get available => game.progress.isAvailable(upgrade);

  /// 이 강화의 유닛을 여는 스테이지 id.
  String get _unlockStage => stages.firstWhere((s) => s.unlocks == upgrade.unit, orElse: () => stages.first).id;

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final card = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(22));
    canvas.drawRRect(card, _wood);
    canvas.drawRRect(card.deflate(2), _rim);

    // 초상화 (위쪽 96px 안, 발을 바닥에)
    final box = Rect.fromLTWH(20, 14, size.x - 40, 92);
    final s = math.min(box.width / _portrait.srcSize.x, box.height / _portrait.srcSize.y);
    final pw = _portrait.srcSize.x * s, ph = _portrait.srcSize.y * s;
    _portrait.render(canvas, position: Vector2(box.center.dx - pw / 2, box.bottom - ph), size: Vector2(pw, ph));

    if (!available) {
      // 아직 못 만난 친구: 흐린 초상화 위에 자물쇠, 언제 열리는지만
      canvas.drawRRect(card, _dim);
      _lock(canvas, Offset(size.x / 2, 112));
      _note.render(canvas, Strings.unlockAt(_unlockStage), Vector2(size.x / 2, 196), anchor: Anchor.center);
      return;
    }

    _name.render(canvas, Strings.upgradeName(upgrade), Vector2(size.x / 2, 128), anchor: Anchor.center);
    _effect.render(canvas, Strings.upgradeEffect(upgrade), Vector2(size.x / 2, 160), anchor: Anchor.center);

    // 단계 칸 3개
    for (var i = 0; i < Upgrade.maxLevel; i++) {
      final c = Offset(size.x / 2 + (i - 1) * 34.0, 190);
      canvas.drawCircle(c, 11, i < level ? _pipOn : _pipOff);
      canvas.drawCircle(c, 11, _pipRim);
    }

    // 값 버튼
    final button = RRect.fromRectAndRadius(Rect.fromLTWH(30, 206, size.x - 60, 34), const Radius.circular(17));
    final cost = upgrade.costAt(level);
    if (cost == null) {
      canvas.drawRRect(button, _done);
      canvas.drawRRect(button, _pipRim);
      _price.render(canvas, Strings.maxed, Vector2(size.x / 2, 223), anchor: Anchor.center);
    } else {
      final ok = game.progress.canBuy(upgrade);
      if (ok) {
        // 살 수 있으면 버튼이 살짝 숨쉰다
        final glow = Paint()..color = const Color(0xFFB8F0A8).withValues(alpha: 0.5 + 0.4 * math.sin(_t * 4));
        canvas.drawRRect(button.inflate(4), glow);
      }
      canvas.drawRRect(button, ok ? _buy : _cannot);
      canvas.drawRRect(button, _pipRim);
      final label = '$cost';
      final w = _price.getLineMetrics(label).width;
      final x = size.x / 2 + 16;
      _price.render(canvas, label, Vector2(x - w / 2, 223), anchor: Anchor.centerLeft);
      final icon = (parent as ShopScreen).pinecone;
      icon.render(canvas, position: Vector2(x - w / 2 - 6, 223), size: Vector2.all(36), anchor: Anchor.centerRight);
    }

  }

  void _lock(Canvas canvas, Offset c) {
    final paint = Paint()..color = const Color(0xFFE9D3A6);
    final stroke = Paint()
      ..color = const Color(0xFFE9D3A6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    canvas.drawArc(Rect.fromCenter(center: c - const Offset(0, 18), width: 40, height: 44), math.pi, math.pi, false, stroke);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c + const Offset(0, 8), width: 58, height: 46), const Radius.circular(9)), paint);
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (!game.progress.buy(upgrade)) {
      _shake();
      return;
    }
    game.progress.save();
    game.sfx.play(Sfx.pickup);
    add(SequenceEffect([
      ScaleEffect.to(Vector2.all(1.08), EffectController(duration: 0.08)),
      ScaleEffect.to(Vector2.all(1), EffectController(duration: 0.18, curve: Curves.easeOutBack)),
    ]));
  }

  void _shake() {
    if (children.whereType<Effect>().isNotEmpty) return;
    add(SequenceEffect([
      MoveByEffect(Vector2(-6, 0), EffectController(duration: 0.04)),
      MoveByEffect(Vector2(12, 0), EffectController(duration: 0.08)),
      MoveByEffect(Vector2(-6, 0), EffectController(duration: 0.04, curve: Curves.easeOut)),
    ]));
  }
}
