import 'dart:ui';

/// 게임 전체에서 쓰는 수치. 조정할 때는 여기만 바꾼다 (이유는 WORKLOG에 기록).
///
/// 좌표는 모두 논리 해상도(1280 × 720) 기준이며 왼쪽 위가 (0, 0)이다.
/// 레이아웃 그림은 plan.md 2-1 참고.
abstract final class GameConfig {
  /// 논리 해상도. 다른 화면 비율에서는 레터박스로 채운다.
  static const double width = 1280;
  static const double height = 720;

  // ── 필드 (레인 × 칸) ──────────────────────────────
  static const int rows = 5;
  static const int cols = 9;
  static const double cellWidth = 100;
  static const double cellHeight = 110;

  /// 필드 왼쪽 위 모서리. 왼쪽 140px은 둥지·통나무 열, 위쪽 110px은 HUD.
  static const double fieldX = 140;
  static const double fieldY = 110;
  static const double fieldWidth = cols * cellWidth; // 900
  static const double fieldHeight = rows * cellHeight; // 550

  // ── 필드 바깥 구역 ────────────────────────────────
  static const double hudHeight = fieldY;

  /// 통나무가 놓이는 열 (x 60 ~ 140). 60보다 왼쪽은 둥지.
  static const double logColumnX = 60;

  /// 몬스터가 나타나는 x. 필드 오른쪽 끝(1040)보다 바깥이다.
  static const double spawnX = 1100;

  /// 아래쪽 웨이브 진행 바 영역 (y 660 ~ 720).
  static const double progressY = fieldY + fieldHeight;

  // ── 색 ────────────────────────────────────────────
  /// 레터박스와 화면 바탕색 (어두운 숲색).
  static const Color backgroundColor = Color(0xFF1F3A1A);

  /// 잔디 칸 체크무늬 두 색.
  static const Color grassLight = Color(0xFF8CC461);
  static const Color grassDark = Color(0xFF79B352);

  /// 둥지(왼쪽)와 몬스터 등장 구역(오른쪽) 흙길.
  static const Color nestColor = Color(0xFF6B4A2B);
  static const Color pathColor = Color(0xFF8A6A3F);

  /// HUD 패널.
  static const Color hudPanel = Color(0xFF4A3220);
  static const Color hudSlot = Color(0xFF6E4E33);
}
