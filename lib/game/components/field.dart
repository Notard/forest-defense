import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../config.dart';
import '../grid.dart';

/// 필드 입력 영역. 마우스를 올린 칸과 마지막으로 누른 칸을 강조한다.
///
/// 마우스와 터치는 같은 탭 경로로 들어온다. 터치에는 "올림"이 없으므로
/// 탭한 칸을 [selectedCell]로 남겨 어느 칸을 눌렀는지 보이게 한다.
/// 4단계에서 [onCellTap]에 유닛 배치를 연결한다.
class Field extends PositionComponent with TapCallbacks, PointerMoveCallbacks {
  Field({this.onCellTap})
      : super(
          position: Vector2(GameConfig.fieldX, GameConfig.fieldY),
          size: Vector2(GameConfig.fieldWidth, GameConfig.fieldHeight),
        );

  /// 칸을 눌렀을 때 호출된다.
  final void Function(Cell cell)? onCellTap;

  /// 마우스가 올라가 있는 칸 (마우스가 필드 밖이면 `null`).
  Cell? hoveredCell;

  /// 마지막으로 누른 칸.
  Cell? selectedCell;

  final _hoverFill = Paint()..color = const Color(0x40FFFFFF);
  final _selectStroke = Paint()
    ..color = const Color(0xFFFFF3B0)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4;

  /// 이 컴포넌트 기준 좌표 [local]이 가리키는 칸.
  Cell? _cellAtLocal(Vector2 local) => Grid.cellAt(local + position);

  @override
  void onPointerMove(PointerMoveEvent event) {
    hoveredCell = _cellAtLocal(event.localPosition);
  }

  @override
  void onPointerMoveStop(PointerMoveEvent event) {
    hoveredCell = null;
  }

  @override
  void onTapDown(TapDownEvent event) {
    final cell = _cellAtLocal(event.localPosition);
    if (cell == null) return;
    selectedCell = cell;
    onCellTap?.call(cell);
  }

  @override
  void render(Canvas canvas) {
    final hovered = hoveredCell;
    if (hovered != null) canvas.drawRect(_localRect(hovered), _hoverFill);
    final selected = selectedCell;
    if (selected != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(_localRect(selected).deflate(2),
            const Radius.circular(10)),
        _selectStroke,
      );
    }
  }

  Rect _localRect(Cell cell) {
    final tl = Grid.topLeft(cell) - position;
    return Rect.fromLTWH(
        tl.x, tl.y, GameConfig.cellWidth, GameConfig.cellHeight);
  }
}
