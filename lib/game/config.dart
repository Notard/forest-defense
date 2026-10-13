import 'dart:ui';

/// 게임 전체에서 쓰는 수치. 조정할 때는 여기만 바꾼다 (이유는 WORKLOG에 기록).
abstract final class GameConfig {
  /// 논리 해상도. 다른 화면 비율에서는 레터박스로 채운다.
  static const double width = 1280;
  static const double height = 720;

  /// 레터박스와 화면 바탕색 (어두운 숲색).
  static const Color backgroundColor = Color(0xFF1F3A1A);
}
