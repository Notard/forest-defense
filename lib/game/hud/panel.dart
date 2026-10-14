import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../config.dart';
import 'frozen.dart';

const _ink = Color(0xFF4A3220);
const _cream = Color(0xFFFFF4DC);

TextPaint _text(double size, Color color) => TextPaint(
      style: TextStyle(
        fontFamily: GameConfig.fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: size,
        color: color,
      ),
    );

/// 화면 가운데 판: 일시정지·클리어·게임오버. 뒤는 어둡게 덮고, 판은 통통 튀며 나타난다.
///
/// 판이 떠 있는 동안 게임 시계는 멈춘다(ForestGame.frozen). 판 자신의 등장 효과는
/// 멈춘 시계와 상관없이 [update]에서 실제 시간으로 돌린다.
class CenterPanel extends PositionComponent with TapCallbacks, RunsWhileFrozen {
  CenterPanel({required this.title, this.lines = const [], this.stars, required this.buttons, this.titleColor = _cream, this.picture})
      : super(size: Vector2(GameConfig.width, GameConfig.height), priority: 2000);

  final String title;

  /// 제목 아래 작은 글줄들 (결과, 솔방울, 새 친구).
  final List<String> lines;

  /// 결과의 별 (0~3). null이면 별 줄을 그리지 않는다.
  final int? stars;
  final Color titleColor;
  final List<PanelButton> buttons;

  /// 별 아래, 글줄 위에 세우는 그림 (새 친구·처음 보는 몬스터, 14단계). 발이 그림 줄 바닥 가운데에 오게 놓는다.
  final PositionComponent? picture;

  final _dim = Paint()..color = const Color(0x99000000);

  late final _PanelBox _box;

  /// 판 크기와 줄 위치. 위에서부터 차례로 쌓는다: 제목 → 별 → 글줄 → 버튼.
  static const double padX = 48, titleY = 66, firstY = 122, starRow = 66, pictureRow = 150, lineGap = 40, buttonGap = 24, bottomPad = 34;

  /// 버튼 줄 위쪽 y (판 안 좌표). 마지막 글줄 아래에 띄운다.
  double get buttonTop {
    var y = firstY + (stars == null ? 0 : starRow) + (picture == null ? 0 : pictureRow) + lines.length * lineGap;
    if (stars != null || picture != null || lines.isNotEmpty) y += 14;
    return y;
  }

  Size get panelSize {
    final row = buttons.fold<double>(0, (a, b) => a + b.size.x) + (buttons.length - 1) * buttonGap;
    final widest = lines.fold<double>(0, (a, l) => math.max(a, _line.getLineMetrics(l).width));
    final w = [640.0, row + 2 * padX, widest + 2 * padX, _title.getLineMetrics(title).width + 2 * padX].reduce(math.max);
    return Size(w, buttonTop + PanelButton.buttonSize.y + bottomPad);
  }

  late final _title = _text(64, titleColor);
  static final _line = _text(28, const Color(0xFFE9D3A6));

  @override
  Future<void> onLoad() async {
    final panel = panelSize;
    _box = _PanelBox(
      position: Vector2(GameConfig.width / 2, GameConfig.height / 2),
      size: Vector2(panel.width, panel.height),
    );
    _box.add(TextComponent(text: title, textRenderer: _title, anchor: Anchor.center, position: Vector2(panel.width / 2, titleY)));
    var y = firstY;
    if (stars != null) {
      _box.add(StarRow(stars!, position: Vector2(panel.width / 2, y + 22)));
      y += starRow;
    }
    final pic = picture;
    if (pic != null) {
      _box.add(pic..position = Vector2(panel.width / 2, y + pictureRow - 14));
      y += pictureRow;
    }
    for (final line in lines) {
      _box.add(TextComponent(text: line, textRenderer: _line, anchor: Anchor.center, position: Vector2(panel.width / 2, y + 12)));
      y += lineGap;
    }
    final row = buttons.fold<double>(0, (a, b) => a + b.size.x) + (buttons.length - 1) * buttonGap;
    var x = (panel.width - row) / 2;
    for (final b in buttons) {
      b.position = Vector2(x, buttonTop);
      x += b.size.x + buttonGap;
      _box.add(b);
    }
    _box.add(ScaleEffect.to(Vector2.all(1), EffectController(duration: 0.3, curve: Curves.easeOutBack)));
    add(_box);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), _dim);
  }

  /// 판 밖을 눌러도 아래 게임으로 전달되지 않게 막는다.
  @override
  void onTapDown(TapDownEvent event) {}
}

/// 가운데 나무판.
class _PanelBox extends PositionComponent {
  _PanelBox({required super.position, required super.size}) : super(anchor: Anchor.center, scale: Vector2.all(0.6));

  final _wood = Paint()..color = const Color(0xF0473020);
  final _rim = Paint()
    ..color = const Color(0xFFE9D3A6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5;

  @override
  void render(Canvas canvas) {
    final r = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(28));
    canvas.drawRRect(r, _wood);
    canvas.drawRRect(r.deflate(8), _rim);
  }
}

/// 판 안의 나무 버튼.
class PanelButton extends PositionComponent with TapCallbacks {
  /// [width]를 주지 않으면 글자 폭에 맞춘다 (최소 [buttonSize].x, 양옆 여백 [labelPad]).
  PanelButton(this.label, this.onPressed, {double? width}) : super(size: Vector2(width ?? fitWidth(label), buttonSize.y));

  static const double labelPad = 28;

  static double fitWidth(String label) => math.max(buttonSize.x, labelPaint.getLineMetrics(label).width + 2 * labelPad);

  static final Vector2 buttonSize = Vector2(180, 70);

  final String label;
  final void Function() onPressed;
  final _bg = Paint()..color = const Color(0xFFE9D3A6);
  final _rim = Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  static final labelPaint = _text(34, _ink);
  bool _down = false;

  @override
  void render(Canvas canvas) {
    final r = RRect.fromRectAndRadius(size.toRect().translate(0, _down ? 3 : 0), const Radius.circular(16));
    canvas.drawRRect(r, _bg);
    canvas.drawRRect(r.deflate(1.5), _rim);
    // 폭을 정해 준 버튼에 글자가 길면 줄여서 넣는다
    final w = labelPaint.getLineMetrics(label).width;
    final k = math.min(1.0, (size.x - 2 * 12) / w);
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2 + (_down ? 3 : 0));
    canvas.scale(k);
    labelPaint.render(canvas, label, Vector2.zero(), anchor: Anchor.center);
    canvas.restore();
  }

  @override
  void onTapDown(TapDownEvent event) => _down = true;

  @override
  void onTapCancel(TapCancelEvent event) => _down = false;

  @override
  void onTapUp(TapUpEvent event) {
    _down = false;
    onPressed();
  }
}

/// 별 세 개 (얻은 만큼 금색, 나머지는 빈 별). 하나씩 통 튀며 나타난다.
class StarRow extends PositionComponent with RunsWhileFrozen {
  StarRow(this.count, {required super.position}) : super(anchor: Anchor.center, size: Vector2(190, 56));

  final int count;
  double _t = 0;
  final _gold = Paint()..color = const Color(0xFFFFD34D);
  final _empty = Paint()..color = const Color(0x40FFFFFF);
  final _rim = Paint()
    ..color = const Color(0xFF4A3220)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeJoin = StrokeJoin.round;

  @override
  void update(double dt) => _t += dt;

  static Path star(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -1.5708 + i * 0.6283;
      final rr = i.isEven ? r : r * 0.45;
      final p = Offset(c.dx + rr * math.cos(a), c.dy + rr * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void render(Canvas canvas) {
    for (var i = 0; i < 3; i++) {
      final appear = ((_t - 0.25 - i * 0.3) / 0.25).clamp(0.0, 1.0);
      final filled = i < count && appear > 0;
      final pop = filled ? 1 + 0.4 * math.sin(appear * math.pi) : 1.0;
      final path = star(Offset(30 + i * 65.0, size.y / 2), 26 * pop);
      canvas.drawPath(path, filled ? _gold : _empty);
      canvas.drawPath(path, _rim);
    }
  }
}
