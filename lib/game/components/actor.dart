import 'dart:ui';

import 'package:flame/components.dart';

import '../art.dart';
import '../forest_game.dart';
import 'smoke.dart';

/// 유닛과 몬스터가 함께 쓰는 바탕: 동작 시트 전환, 이벤트 프레임, HP, 맞을 때 흰색 깜빡임, 쓰러짐.
///
/// 동작 이름은 스프라이트 시트 이름과 같다 (`idle`, `attack`, `hit`, `death` …).
abstract class Actor extends SpriteAnimationGroupComponent<String> with HasGameReference<ForestGame> {
  Actor({
    required this.art,
    required this.maxHp,
    required double scale,
    required String startAction,
    super.position,
    super.priority,
  })  : hp = maxHp.toDouble(),
        _scale = scale,
        super(
          animations: {for (final a in art.actions) a: art.animation(a)},
          current: startAction,
          size: art.frameSize * scale,
          anchor: Anchor(art.anchor.x / art.frameSize.x, art.anchor.y / art.frameSize.y),
        );

  final CharacterArt art;
  final int maxHp;
  final double _scale;
  double hp;

  bool get alive => hp > 0;

  /// 평소 반복 동작 (유닛은 idle, 몬스터는 walk). 다른 동작이 끝나면 돌아온다.
  String get restAction;

  /// 맞았을 때 흰색 깜빡임이 남은 시간.
  double _flash = 0;
  static const double flashTime = 0.12;
  static final _flashFilter = ColorFilter.mode(const Color(0xB0FFFFFF), BlendMode.srcATop);

  /// 지금 동작이 반복이 아닌 한 번짜리(공격·피격 등)로 재생 중인지.
  bool _busy = false;
  bool get busy => _busy;

  /// 프레임 안 위치(시트 px)를 월드 좌표로. 발사점·생산 위치 계산에 쓴다.
  Vector2 framePointToWorld(Vector2 framePoint) =>
      absolutePosition + (framePoint - art.anchor) * _scale;

  /// [action]을 처음부터 재생한다. 이벤트 프레임(시트 JSON의 event)에 [onEvent],
  /// 끝나면 [onDone]을 부르고 반복 동작으로 돌아간다(쓰러짐 제외).
  void play(String action, {void Function()? onEvent, void Function()? onDone}) {
    current = action;
    final ticker = animationTicker!..reset();
    final event = art.eventFrame(action);
    ticker.onFrame = (event == null || onEvent == null)
        ? null
        : (index) {
            if (index + 1 == event) onEvent();
          };
    if (art.loops(action)) {
      _busy = false;
      ticker.onComplete = null;
      return;
    }
    _busy = true;
    ticker.onComplete = () {
      _busy = false;
      onDone?.call();
      if (alive && current == action) play(restAction);
    };
  }

  /// 피해를 받는다. 깜빡이고, 한가하면 피격 동작을 하고, HP가 0이 되면 쓰러진다.
  void takeDamage(double amount) {
    if (!alive) return;
    hp -= amount;
    _flash = flashTime;
    if (hp <= 0) {
      hp = 0;
      die();
    } else {
      onHurt();
      if (!_busy && canFlinch && art.actions.contains('hit')) play('hit');
    }
  }

  /// 깜빡임이 없을 때 늘 입히는 색 (감속된 몬스터는 푸르다). 기본은 없음.
  ColorFilter? get standingTint => null;

  /// 피해 뒤 처리 (거북이 금 간 등껍질 등). 기본은 아무것도 안 함.
  void onHurt() {}

  /// 맞았을 때 피격 동작을 할지. 갉아먹는 몬스터는 깜빡이기만 해서 깨무는 박자를 지킨다.
  bool get canFlinch => true;

  /// 게임 규칙에서 빼기 (칸 비우기, 몬스터 목록에서 빼기).
  void onDeath();

  void die() {
    onDeath();
    if (art.actions.contains('death')) {
      play('death', onDone: _vanish);
    } else {
      _vanish();
    }
  }

  void _vanish() {
    game.world.add(Smoke(position: absolutePosition - Vector2(0, size.y * 0.3), size: size.y * 0.9));
    removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flash > 0) _flash -= dt;
    paint.colorFilter = _flash > 0 ? _flashFilter : standingTint;
  }
}
