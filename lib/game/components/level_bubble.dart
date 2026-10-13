import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart' show TextStyle, FontWeight;

import '../config.dart';
import '../forest_game.dart';
import 'unit.dart';

/// 놓인 친구를 눌렀을 때 머리 위에 뜨는 레벨업 말풍선 (12-2단계): 위 화살표 + 도토리 + 값.
/// 누르면 도토리를 내고 레벨이 오른다. 도토리가 모자라면 흐리고, 누르면 흔들린다. [lifetime]초 뒤 저절로 닫힌다.
class LevelBubble extends PositionComponent with TapCallbacks, HasGameReference<ForestGame> {
  LevelBubble(this.unit) : super(size: Vector2(118, 56), anchor: Anchor.bottomCenter, priority: 900);

  final UnitComponent unit;

  static const double lifetime = 4;

  /// 맨 윗줄 친구는 말풍선이 위 HUD에 가리므로 발 아래에 띄운다.
  static const double hudBottom = 112;

  double _age = 0;
  late final Sprite _acorn;
  final _bg = Paint()..color = const Color(0xFFFFF4DC);
  final _rim = Paint()
    ..color = const Color(0xFF4A3220)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeJoin = StrokeJoin.round;
  final _arrow = Paint()..color = const Color(0xFF5DBB4A);
  final _dim = Paint()..color = const Color(0x88857A6A);
  static final costPaint = TextPaint(
    style: const TextStyle(fontFamily: GameConfig.fontFamily, fontWeight: FontWeight.w700, fontSize: 28, color: Color(0xFF4A3220)),
  );

  /// 말풍선 꼬리가 아래(머리 위에 뜰 때)인지 위(발 아래에 뜰 때)인지.
  bool below = false;

  int get cost => game.levelCost(unit);
  bool get affordable => game.garden.acorns >= cost;

  @override
  Future<void> onLoad() async {
    _acorn = Sprite(await game.images.load('fx/acorn.webp'));
    final head = unit.position.y - unit.type.displayHeight; // 발에서 친구 키만큼 위
    below = head - 6 - size.y < hudBottom;
    if (below) {
      anchor = Anchor.topCenter;
      position = Vector2(unit.position.x, unit.position.y + 6);
    } else {
      position = Vector2(unit.position.x, head - 6);
    }
    scale = Vector2.all(0.6);
    add(ScaleEffect.to(Vector2.all(1), EffectController(duration: 0.18, curve: Curves.easeOutBack)));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age > lifetime || !unit.alive || !unit.isMounted || !unit.canLevel) game.closeBubble();
  }

  @override
  void render(Canvas canvas) {
    const tail = 10.0;
    final body = below ? Rect.fromLTWH(0, tail, size.x, size.y - tail) : Rect.fromLTWH(0, 0, size.x, size.y - tail);
    final path = Path()..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(16)));
    final cx = size.x / 2;
    final tailPath = below
        ? (Path()
          ..moveTo(cx - 10, tail + 1)
          ..lineTo(cx, 0)
          ..lineTo(cx + 10, tail + 1))
        : (Path()
          ..moveTo(cx - 10, body.bottom - 1)
          ..lineTo(cx, size.y)
          ..lineTo(cx + 10, body.bottom - 1));
    final shape = Path.combine(PathOperation.union, path, tailPath..close());
    canvas.drawPath(shape, _bg);
    canvas.drawPath(shape, _rim);

    // 위 화살표 (Gaegu에는 ↑ 글자가 없어 그린다)
    final a = Offset(22, body.center.dy);
    final arrow = Path()
      ..moveTo(a.dx, a.dy - 15)
      ..lineTo(a.dx + 12, a.dy - 2)
      ..lineTo(a.dx + 5, a.dy - 2)
      ..lineTo(a.dx + 5, a.dy + 14)
      ..lineTo(a.dx - 5, a.dy + 14)
      ..lineTo(a.dx - 5, a.dy - 2)
      ..lineTo(a.dx - 12, a.dy - 2)
      ..close();
    canvas.drawPath(arrow, _arrow);
    canvas.drawPath(arrow, _rim);
    _acorn.render(canvas, position: Vector2(52, body.center.dy), size: Vector2.all(30), anchor: Anchor.center);
    costPaint.render(canvas, '$cost', Vector2(70, body.center.dy + 1), anchor: Anchor.centerLeft);
    if (!affordable) canvas.drawPath(shape, _dim);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (game.levelUp(unit)) return;
    if (children.whereType<SequenceEffect>().isNotEmpty) return;
    add(SequenceEffect([
      MoveByEffect(Vector2(-5, 0), EffectController(duration: 0.04)),
      MoveByEffect(Vector2(10, 0), EffectController(duration: 0.08)),
      MoveByEffect(Vector2(-5, 0), EffectController(duration: 0.04)),
    ]));
  }
}

/// 레벨이 오를 때 친구 둘레로 튀어 나가는 작은 별 여섯 개.
class LevelSparkle extends PositionComponent {
  LevelSparkle({required super.position}) : super(priority: 950);

  static const double duration = 0.55;
  double _t = 0;
  final _star = Paint()..color = const Color(0xFFFFD34D);
  final _rim = Paint()
    ..color = const Color(0xFF4A3220)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    // 지난 뒤에는 그리지 않는다: removeFromParent는 다음 프레임에 처리되어 이 프레임에도 render가 불린다.
    // Curve.transform은 0~1 밖의 값이면 릴리스 빌드에서 끝나지 않는다 (웹에서 페이지가 멈춘 원인, 12-2단계)
    if (_t >= duration) return;
    final k = (_t / duration).clamp(0.0, 1.0);
    for (var i = 0; i < 6; i++) {
      final ang = -math.pi / 2 + i * math.pi / 3;
      final r = 20 + 46 * Curves.easeOut.transform(k);
      final c = Offset(math.cos(ang) * r, math.sin(ang) * r);
      final s = 9 * (1 - k * 0.6);
      final p = starPath(c, s);
      _star.color = const Color(0xFFFFD34D).withValues(alpha: 1 - k);
      _rim.color = const Color(0xFF4A3220).withValues(alpha: 1 - k);
      canvas.drawPath(p, _star);
      canvas.drawPath(p, _rim);
    }
  }
}

/// 다섯 꼭짓점 별.
Path starPath(Offset c, double r) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final ang = -math.pi / 2 + i * math.pi / 5;
    final rr = i.isEven ? r : r * 0.45;
    final pt = c + Offset(math.cos(ang) * rr, math.sin(ang) * rr);
    i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}
