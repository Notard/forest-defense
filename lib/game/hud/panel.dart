import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../config.dart';

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
class CenterPanel extends PositionComponent with TapCallbacks {
  CenterPanel({required this.title, this.subtitle, required this.buttons, this.titleColor = _cream})
      : super(size: Vector2(GameConfig.width, GameConfig.height), priority: 2000);

  final String title;
  final String? subtitle;
  final Color titleColor;
  final List<PanelButton> buttons;

  static const Size _panel = Size(560, 300);
  final _dim = Paint()..color = const Color(0x99000000);

  late final _PanelBox _box;

  @override
  Future<void> onLoad() async {
    _box = _PanelBox(
      position: Vector2(GameConfig.width / 2, GameConfig.height / 2),
      size: Vector2(_panel.width, _panel.height),
    );
    _box.add(TextComponent(
      text: title,
      textRenderer: _text(64, titleColor),
      anchor: Anchor.center,
      position: Vector2(_panel.width / 2, 74),
    ));
    if (subtitle != null) {
      _box.add(TextComponent(
        text: subtitle!,
        textRenderer: _text(28, const Color(0xFFE9D3A6)),
        anchor: Anchor.center,
        position: Vector2(_panel.width / 2, 138),
      ));
    }
    final gap = 24.0, w = PanelButton.buttonSize.x;
    final total = buttons.length * w + (buttons.length - 1) * gap;
    for (final (i, b) in buttons.indexed) {
      b.position = Vector2((_panel.width - total) / 2 + i * (w + gap), 196);
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
  PanelButton(this.label, this.onPressed) : super(size: buttonSize);

  static final Vector2 buttonSize = Vector2(190, 70);

  final String label;
  final void Function() onPressed;
  final _bg = Paint()..color = const Color(0xFFE9D3A6);
  final _rim = Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  late final _label = _text(34, _ink);
  bool _down = false;

  @override
  void render(Canvas canvas) {
    final r = RRect.fromRectAndRadius(size.toRect().translate(0, _down ? 3 : 0), const Radius.circular(16));
    canvas.drawRRect(r, _bg);
    canvas.drawRRect(r.deflate(1.5), _rim);
    _label.render(canvas, label, Vector2(size.x / 2, size.y / 2 + (_down ? 3 : 0)), anchor: Anchor.center);
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
