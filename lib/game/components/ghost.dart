import 'dart:ui';

import 'package:flame/components.dart';

import '../art.dart';
import '../forest_game.dart';
import '../units.dart';
import 'unit.dart';

/// 카드를 고른 채 칸 위에 마우스를 올리면, 놓일 모습을 반투명하게 보여 준다.
/// 터치에는 마우스 올림이 없으므로 나타나지 않는다.
///
/// SpriteComponent는 붙을 때 그림이 꼭 있어야 해서(없으면 assert) 평소에 그림이 없는
/// 이 컴포넌트는 PositionComponent로 직접 그린다 (WORKLOG 4).
class PlacementGhost extends PositionComponent with HasGameReference<ForestGame> {
  PlacementGhost() : super(priority: 900);

  final Map<UnitType, CharacterArt> _arts = {};
  final _paint = Paint()..color = const Color(0x80FFFFFF);
  Sprite? _sprite;

  @override
  Future<void> onLoad() async {
    for (final type in UnitType.values) {
      _arts[type] = await CharacterArt.load(game, type.sheet);
    }
  }

  @override
  void update(double dt) {
    final type = game.selectedUnit;
    final cell = game.field.hoveredCell;
    if (type == null || cell == null || !game.laneOpen(cell.row) || game.garden.unitAt(cell) != null) {
      _sprite = null;
      return;
    }
    final art = _arts[type]!;
    _sprite = art.firstFrame(type.idleAction);
    size = art.frameSize * art.scaleForHeight(type.displayHeight);
    anchor = Anchor(art.anchor.x / art.frameSize.x, art.anchor.y / art.frameSize.y);
    position = UnitComponent.footOf(cell);
  }

  @override
  void render(Canvas canvas) => _sprite?.render(canvas, size: size, overridePaint: _paint);
}
