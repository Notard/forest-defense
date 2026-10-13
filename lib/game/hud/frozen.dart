import 'package:flame/components.dart';

/// 게임 시계가 멈춰 있어도(메인 화면·카운트다운·일시정지·결과) 실제 시간으로 움직이는 화면.
/// ForestGame이 멈춘 동안 이 표시가 붙은 컴포넌트만 따로 update한다.
mixin RunsWhileFrozen on Component {}
