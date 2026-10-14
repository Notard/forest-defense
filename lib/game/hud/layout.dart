import 'dart:ui';

/// HUD 위치 (논리 좌표, plan.md 2-1 표).
abstract final class HudLayout {
  static const double _top = 9;
  static const double _slotHeight = 90;

  /// 도토리 칸·카드·삽 뒤에 까는 반투명 판. 카드 수에 맞춰 늘고, 나머지 위쪽은 배경 나무 지붕이 보이게 둔다.
  static Rect topPanel(int cards) => Rect.fromLTWH(4, 3, shovel(cards).right + 8 - 4, 102);

  static const Rect acornCounter = Rect.fromLTWH(12, _top, 116, _slotHeight);

  /// 유닛 카드 (최대 7장). 도토리 칸 오른쪽에 80px 폭 + 8px 틈.
  static Rect card(int i) => Rect.fromLTWH(140 + i * 88.0, _top, 80, _slotHeight);

  /// 삽은 마지막 카드 오른쪽 (카드가 4장이면 x 504).
  static Rect shovel(int cards) => Rect.fromLTWH(140 + cards * 88.0 + 12, _top, 80, _slotHeight);
  static const Rect pause = Rect.fromLTWH(1198, 22, 70, 60);
  static const Rect sound = Rect.fromLTWH(1118, 22, 70, 60);
  static const Rect music = Rect.fromLTWH(1038, 22, 70, 60);

  /// 아래 띠 (웨이브 이름 + 진행 바). 배경 뿌리가 비치게 반투명.
  static const Rect bottomBand = Rect.fromLTWH(0, 652, 1280, 68);

  /// 진행 바는 오른쪽 아래. 왼쪽 아래는 웨이브 이름과 둥지 하트.
  static const Rect progressBar = Rect.fromLTWH(880, 674, 380, 26);

  /// 둥지 하트 (14-1단계). 웨이브 이름 오른쪽, 쉬움이면 다섯 개라 x 220 ~ 380.
  static const Rect hearts = Rect.fromLTWH(220, 662, 160, 50);

  /// 첫 웨이브까지 남은 시간 (14-2단계). 아래 띠 가운데, 하트와 진행 바 사이.
  /// 글자 "몬스터가 오기까지" + 줄어드는 막대 + 남은 초.
  static const Rect firstWave = Rect.fromLTWH(396, 662, 464, 50);
  static const Rect firstWaveBar = Rect.fromLTWH(606, 677, 182, 20);
}
