import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

/// 캐릭터 하나의 스프라이트 시트 묶음 (tools/pack_sheets.py가 만든 `<캐릭터>.json` + 동작별 PNG).
class CharacterArt {
  CharacterArt._(this.name, this.frameSize, this.anchor, this.bbox, this.muzzle, this._data, this._images);

  final String name;

  /// 한 프레임 크기 (px).
  final Vector2 frameSize;

  /// 프레임 안의 발 위치. 칸 바닥에 맞추는 기준점이다.
  final Vector2 anchor;

  /// 첫 동작 첫 프레임에서 그림이 있는 영역 (표시 크기·카드 초상화).
  final Rect bbox;

  /// 발사·생산·폭발 위치 (없을 수 있음).
  final Vector2? muzzle;

  final Map<String, Map<String, dynamic>> _data;
  final Map<String, Image> _images;

  Iterable<String> get actions => _data.keys;

  /// 동작의 이벤트 프레임 번호 (1부터, 없으면 null).
  int? eventFrame(String action) => _data[action]?['event'] as int?;

  bool loops(String action) => _data[action]!['loop'] as bool;

  /// 발에서 머리 끝까지의 높이 (프레임 px).
  double get characterHeight => anchor.y - bbox.top;

  /// 키가 [height] 논리 px로 보이게 하는 배율.
  double scaleForHeight(double height) => height / characterHeight;

  SpriteAnimation animation(String action) {
    final a = _data[action]!;
    return SpriteAnimation.fromFrameData(
      _images[action]!,
      SpriteAnimationData.sequenced(
        amount: a['frames'] as int,
        stepTime: 1 / (a['fps'] as num),
        textureSize: frameSize,
        loop: a['loop'] as bool,
      ),
    );
  }

  /// 첫 동작 첫 프레임 (카드 초상화, 놓기 전 미리보기).
  Sprite firstFrame(String action) =>
      Sprite(_images[action]!, srcPosition: Vector2.zero(), srcSize: frameSize);

  static final Map<String, Future<CharacterArt>> _cache = {};

  /// `assets/images/<name>/`을 읽는다. 같은 캐릭터는 한 번만 읽는다.
  static Future<CharacterArt> load(FlameGame game, String name) =>
      _cache.putIfAbsent(name, () => _load(game, name));

  static Future<CharacterArt> _load(FlameGame game, String name) async {
    final json = await game.assets.readJson('images/$name/$name.json');
    final actions = (json['actions'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as Map<String, dynamic>),
    );
    final images = <String, Image>{
      for (final action in actions.keys)
        action: await game.images.load('$name/$action.webp'),
    };
    Vector2 vec(List<dynamic> v) => Vector2((v[0] as num).toDouble(), (v[1] as num).toDouble());
    final b = (json['bbox'] as List).map((v) => (v as num).toDouble()).toList();
    return CharacterArt._(
      name,
      vec(json['frame'] as List),
      vec(json['anchor'] as List),
      Rect.fromLTRB(b[0], b[1], b[2], b[3]),
      json['muzzle'] == null ? null : vec(json['muzzle'] as List),
      actions,
      images,
    );
  }

  /// 테스트에서 게임을 새로 만들 때 이전 게임의 그림 캐시를 비운다.
  static void clearCache() => _cache.clear();
}
