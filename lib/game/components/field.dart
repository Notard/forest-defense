import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../config.dart';
import '../forest_game.dart';
import '../grid.dart';

/// 필드 입력 영역. 마우스를 올린 칸을 밝게 하고, 누른 칸을 [onCellTap]으로 알린다.
///
/// 마우스와 터치는 같은 탭 경로로 들어온다. 마지막으로 누른 칸은 [selectedCell]에 남는다.
class Field extends PositionComponent with TapCallbacks, PointerMoveCallbacks, HasGameReference<ForestGame> {
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

  /// 삽 모드에서 동물이 있는 칸: 치울 수 있다는 붉은 표시.
  final _shovelFill = Paint()..color = const Color(0x55FF5A3C);

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
    if (hovered != null) {
      final removable = game.shovelMode && game.garden.unitAt(hovered) != null;
      canvas.drawRect(_localRect(hovered), removable ? _shovelFill : _hoverFill);
    }
  }

  Rect _localRect(Cell cell) {
    final tl = Grid.topLeft(cell) - position;
    return Rect.fromLTWH(
        tl.x, tl.y, GameConfig.cellWidth, GameConfig.cellHeight);
  }
}
