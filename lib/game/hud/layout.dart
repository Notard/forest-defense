import 'dart:ui';

/// HUD 위치 (논리 좌표, plan.md 2-1 표).
abstract final class HudLayout {
  static const double _top = 9;
  static const double _slotHeight = 90;

  /// 도토리 칸·카드·삽 뒤에 까는 반투명 판. 나머지 위쪽은 배경 나무 지붕이 보이게 둔다.
  static const Rect topPanel = Rect.fromLTWH(4, 3, 588, 102);

  static const Rect acornCounter = Rect.fromLTWH(12, _top, 116, _slotHeight);

  /// 유닛 카드 4장. 도토리 칸 오른쪽에 80px 폭 + 8px 틈.
  static final List<Rect> cards = [
    for (var i = 0; i < 4; i++) Rect.fromLTWH(140 + i * 88.0, _top, 80, _slotHeight),
  ];

  static const Rect shovel = Rect.fromLTWH(504, _top, 80, _slotHeight);
  static const Rect pause = Rect.fromLTWH(1198, 22, 70, 60);

  /// 아래 띠 (웨이브 이름 + 진행 바). 배경 뿌리가 비치게 반투명.
  static const Rect bottomBand = Rect.fromLTWH(0, 652, 1280, 68);

  /// 진행 바는 오른쪽 아래 (원작과 같은 위치).
  static const Rect progressBar = Rect.fromLTWH(880, 674, 380, 26);
}
