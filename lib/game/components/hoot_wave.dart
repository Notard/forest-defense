import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config.dart';

/// 부엉이 소리 물결: 부리에서 레인 오른쪽으로 퍼지는 둥근 물결 세 겹 (10단계).
/// 그림 파일 없이 호를 그린다. [duration]초 동안 커지며 옅어진다.
class HootWave extends PositionComponent {
  HootWave({required Vector2 from, required int row})
      : super(position: from, priority: row * 10 + 6);

  static const double duration = 0.8;

  /// 물결이 가는 거리 (논리 px). 감속은 레인 앞쪽 전체에 걸리므로 레인 끝까지 퍼진다.
  static const double reach = GameConfig.cellWidth * 8;

  double _t = 0;
  final _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    for (var i = 0; i < 3; i++) {
      final k = (_t / duration - i * 0.18).clamp(0.0, 1.0);
      if (k <= 0 || k >= 1) continue;
      final r = 16 + reach * k;
      _paint
        ..strokeWidth = 7 * (1 - k) + 2
        ..color = const Color(0xFFBFE3FF).withValues(alpha: 0.85 * (1 - k));
      // 오른쪽을 향한 호 (위아래 ±40°), 레인 높이를 넘지 않게 납작하게
      canvas.save();
      canvas.scale(1, 0.55);
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: r), -40 * math.pi / 180, 80 * math.pi / 180, false, _paint);
      canvas.restore();
    }
  }
}
