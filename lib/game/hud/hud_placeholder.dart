import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../config.dart';
import '../strings.dart';

/// HUD와 진행 바가 들어갈 자리. 크기와 위치만 잡아 둔다.
///
/// - 위쪽 패널: 도토리 수(1칸) · 유닛 카드(4칸) · 삽(1칸) · 일시정지(오른쪽 끝)
/// - 아래쪽: 웨이브 진행 바
///
/// 4단계(카드 바·도토리 수)와 6단계(진행 바)에서 실제 컴포넌트로 바꾼다.
/// 슬롯 위치는 [HudLayout]에 두어 실제 HUD도 같은 값을 쓰게 한다.
class HudPlaceholder extends PositionComponent {
  HudPlaceholder()
      : super(size: Vector2(GameConfig.width, GameConfig.height), priority: 10);

  static final _text = TextPaint(
    style: const TextStyle(
      fontFamily: GameConfig.fontFamily,
      fontWeight: FontWeight.w700,
      color: Color(0xFFFFFFFF),
    ),
  );

  @override
  Future<void> onLoad() async {
    // 폰트가 실제로 쓰이는지 보려고 넣은 임시 글자. 4·6단계에서 실제 값으로 바꾼다.
    addAll([
      TextComponent(
        text: '150',
        textRenderer: _sized(44),
        anchor: Anchor.center,
        position: Vector2(HudLayout.acornCounter.center.dx,
            HudLayout.acornCounter.center.dy),
      ),
      TextComponent(
        text: Strings.wave(1, 5),
        textRenderer: _sized(30),
        anchor: Anchor.centerLeft,
        position: Vector2(24, HudLayout.progressBar.center.dy),
      ),
    ]);
  }

  static TextPaint _sized(double size) =>
      _text.copyWith((s) => s.copyWith(fontSize: size));

  final _panel = Paint()..color = GameConfig.hudPanel;
  final _slot = Paint()..color = GameConfig.hudSlot;
  final _barTrack = Paint()..color = const Color(0xFF2E2014);
  final _barFill = Paint()..color = const Color(0xFF9BCB5A);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
        const Rect.fromLTWH(0, 0, GameConfig.width, GameConfig.hudHeight),
        _panel);
    for (final rect in [
      HudLayout.acornCounter,
      ...HudLayout.cards,
      HudLayout.shovel,
      HudLayout.pause,
    ]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(10)), _slot);
    }

    canvas.drawRect(
        const Rect.fromLTWH(0, GameConfig.progressY, GameConfig.width,
            GameConfig.height - GameConfig.progressY),
        _panel);
    final track = RRect.fromRectAndRadius(
        HudLayout.progressBar, const Radius.circular(8));
    canvas.drawRRect(track, _barTrack);
    // 자리 표시용으로 30%만 채워 둔다.
    final bar = HudLayout.progressBar;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(bar.left, bar.top, bar.width * 0.3, bar.height),
          const Radius.circular(8)),
      _barFill,
    );
  }
}

/// HUD 슬롯 위치 (논리 좌표).
abstract final class HudLayout {
  static const double _top = 10;
  static const double _slotHeight = 90;

  static const Rect acornCounter = Rect.fromLTWH(12, _top, 116, _slotHeight);

  /// 유닛 카드 4장. 도토리 칸 오른쪽에 80px 간격 + 8px 틈으로 놓는다.
  static final List<Rect> cards = [
    for (var i = 0; i < 4; i++)
      Rect.fromLTWH(140 + i * 88.0, _top, 80, _slotHeight),
  ];

  static const Rect shovel = Rect.fromLTWH(504, _top, 80, _slotHeight);
  static const Rect pause = Rect.fromLTWH(1198, _top + 15, 70, 60);

  /// 진행 바는 오른쪽 아래에 놓는다 (원작과 같은 위치).
  static const Rect progressBar = Rect.fromLTWH(880, 676, 380, 28);
}
