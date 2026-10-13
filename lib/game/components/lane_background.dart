import 'dart:ui';

import 'package:flame/components.dart';

import '../config.dart';
import '../grid.dart';

/// 배경: Codex로 그린 숲 그림 + 레인에 맞춘 옅은 칸 체크무늬.
///
/// 배경 그림의 잔디 줄무늬(7줄)는 레인(5줄)과 맞지 않아 tools/prep_props.py에서 지웠다.
/// 칸 경계는 여기서 그리는 체크무늬로 보인다 (WORKLOG 3-g).
class LaneBackground extends PositionComponent with HasGameReference {
  LaneBackground({this.closedLanes = const [], this.night = false})
      : super(size: Vector2(GameConfig.width, GameConfig.height), priority: -10);

  /// 이 스테이지에서 쓰지 않는 레인. 어둡게 덮고 빗금을 긋는다 (놓을 수 없음).
  final List<int> closedLanes;

  /// 밤 숲 그림을 쓸지 (13단계, 낮 그림과 구도가 같다).
  final bool night;
  final _closed = Paint()..color = const Color(0xA0182A12);
  final _hatch = Paint()
    ..color = const Color(0x30000000)
    ..strokeWidth = 6;

  late final Sprite _picture;

  /// 칸을 번갈아 아주 살짝 밝게/어둡게 한다. 그림의 풀결이 비쳐야 하므로 옅게.
  final _light = Paint()..color = const Color(0x1AFFFFFF);
  final _dark = Paint()..color = const Color(0x12000000);

  @override
  Future<void> onLoad() async {
    _picture = Sprite(await game.images.load(night ? 'fx/background_night.webp' : 'fx/background.webp'));
  }

  @override
  void render(Canvas canvas) {
    _picture.render(canvas, size: size);
    for (final cell in Grid.allCells) {
      final tl = Grid.topLeft(cell);
      canvas.drawRect(
        Rect.fromLTWH(tl.x, tl.y, GameConfig.cellWidth, GameConfig.cellHeight),
        (cell.row + cell.col).isEven ? _light : _dark,
      );
    }
    for (final row in closedLanes) {
      final r = Rect.fromLTWH(GameConfig.fieldX, GameConfig.fieldY + row * GameConfig.cellHeight, GameConfig.fieldWidth, GameConfig.cellHeight);
      canvas.drawRect(r, _closed);
      canvas.save();
      canvas.clipRect(r);
      for (var x = r.left - r.height; x < r.right; x += 28) {
        canvas.drawLine(Offset(x, r.bottom), Offset(x + r.height, r.top), _hatch);
      }
      canvas.restore();
    }
  }
}
