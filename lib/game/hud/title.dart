import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../art.dart';
import '../config.dart';
import '../difficulty.dart';
import '../forest_game.dart';
import '../monsters.dart';
import '../sfx.dart';
import '../strings.dart';
import '../units.dart';
import 'frozen.dart';
import '../../platform/install.dart' as install;
import 'panel.dart';

TextPaint _text(double size, Color color, {double shadow = 4}) => TextPaint(
      style: TextStyle(
        fontFamily: GameConfig.fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: size,
        color: color,
        shadows: [
          Shadow(color: const Color(0xDD2E1A0A), offset: Offset(0, shadow)),
          Shadow(color: const Color(0x66000000), offset: Offset(0, shadow + 2), blurRadius: 8),
        ],
      ),
    );

/// 메인 화면: 숲 배경, 제목, 마주 선 동물과 몬스터, 게임 시작 버튼 (7-2단계).
class TitleScreen extends PositionComponent with TapCallbacks, HasGameReference<FlameGame> {
  TitleScreen({required this.onStart, this.onHelp, this.onBook, this.difficulty, this.onDifficulty, this.onSettings}) : super(size: Vector2(GameConfig.width, GameConfig.height), priority: 3000);

  /// 게임 시작 버튼 (숲 지도로).
  final void Function() onStart;

  /// 도움말 버튼 (12-4단계). 없으면 버튼을 두지 않는다.
  final void Function()? onHelp;

  /// 아래 책 소개 띠를 눌렀을 때 (14-3단계). 없으면 띠를 두지 않는다.
  final void Function()? onBook;

  /// 설정 창 (16-2단계). 있으면 도움말 왼쪽에 버튼.
  final void Function()? onSettings;

  /// 지금 난이도와 바꿀 때 (14-4단계). 둘 다 있어야 고르는 줄을 둔다.
  final Difficulty? difficulty;
  final void Function(Difficulty)? onDifficulty;

  late final Sprite _background;
  final _shade = Paint()..color = const Color(0x59000000);
  double _t = 0;
  late final TextComponent _title;

  @override
  Future<void> onLoad() async {
    _background = Sprite(await game.images.load('fx/background.webp'));
    _title = TextComponent(
      text: Strings.title,
      textRenderer: _text(132, const Color(0xFFFFF4DC), shadow: 7),
      anchor: Anchor.center,
      position: Vector2(GameConfig.width / 2, 178),
    );
    add(_title);
    add(TextComponent(
      text: Strings.subtitle,
      textRenderer: _text(36, const Color(0xFFFFE6A8), shadow: 3),
      anchor: Anchor.center,
      position: Vector2(GameConfig.width / 2, 278),
    ));

    // 왼쪽 동물들은 오른쪽을, 오른쪽 몬스터들은 왼쪽을 본다 (시트 방향 그대로)
    const ground = 610.0;
    final animals = [(UnitType.squirrel, 120.0), (UnitType.fox, 255.0), (UnitType.turtle, 405.0), (UnitType.skunk, 555.0)];
    for (final (type, x) in animals) {
      final art = await CharacterArt.load(game, type.sheet);
      add(_actor(art, type == UnitType.skunk ? 'arm' : 'idle', x, ground, type.displayHeight * 1.4));
    }
    final monsters = [(MonsterType.slime, 'walk', 800.0), (MonsterType.helmetSlime, 'walk', 945.0), (MonsterType.wisp, 'walk', 1095.0)];
    for (final (type, action, x) in monsters) {
      final art = await CharacterArt.load(game, type.sheet);
      add(_actor(art, action, x, ground - type.floatHeight * 1.4, type.displayHeight * 1.4));
    }
    add(StartButton(position: Vector2(GameConfig.width / 2, 438), onPressed: onStart));
    final help = onHelp;
    if (help != null) {
      final button = PanelButton(Strings.help, help);
      add(button..position = Vector2(GameConfig.width - 24 - button.size.x, 26));
      final settings = onSettings;
      if (settings != null) {
        final s = PanelButton(Strings.settings, settings);
        add(s..position = Vector2(button.position.x - 14 - s.size.x, 26));
      }
      add(InstallButton());
    }
    final book = onBook;
    if (book != null) add(BookBadge(onPressed: book));
    final level = difficulty, pick = onDifficulty;
    if (level != null && pick != null) add(DifficultyPicker(level, pick));
  }

  SpriteAnimationComponent _actor(CharacterArt art, String action, double x, double footY, double height) {
    final s = art.scaleForHeight(height);
    final anim = art.animation(action);
    return SpriteAnimationComponent(
      animation: art.loops(action) ? anim : anim.clone()..loop = true,
      size: art.frameSize * s,
      anchor: Anchor(art.anchor.x / art.frameSize.x, art.anchor.y / art.frameSize.y),
      position: Vector2(x, footY),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    _title.position.y = 178 + sin(_t * 1.6) * 6; // 제목이 천천히 둥실
  }

  @override
  void render(Canvas canvas) {
    _background.render(canvas, size: size);
    canvas.drawRect(size.toRect(), _shade);
  }

  /// 메인 화면이 떠 있는 동안 아래 게임 화면으로 탭이 가지 않게 막는다.
  @override
  void onTapDown(TapDownEvent event) {}
}

/// 왼쪽 위 "앱으로 설치" (웹에서 브라우저가 설치를 제안할 때만 보인다, 16단계).
/// 브라우저의 제안은 화면이 뜬 뒤에 올 수도 있어서 0.5초마다 다시 본다.
class InstallButton extends PositionComponent {
  InstallButton({this.canInstall = install.canInstall, this.prompt = install.promptInstall}) : super(position: Vector2(24, 26));

  final bool Function() canInstall;
  final Future<bool> Function() prompt;
  PanelButton? _button;
  double _check = 0;

  bool get shown => _button != null;

  @override
  void update(double dt) {
    _check -= dt;
    if (_check > 0) return;
    _check = 0.5;
    final can = canInstall();
    if (can && _button == null) {
      add(_button = PanelButton(Strings.install, () async {
        await prompt();
        _check = 0; // 설치했든 닫았든 버튼 상태를 바로 다시 본다
      }));
    } else if (!can && _button != null) {
      _button!.removeFromParent();
      _button = null;
    }
  }
}

/// 부제와 게임 시작 버튼 사이의 난이도 고르기 [쉬움][보통][어려움] (14-4단계). 고른 것은 노랗게.
class DifficultyPicker extends PositionComponent {
  DifficultyPicker(this.selected, this.onChanged)
      : super(
          anchor: Anchor.center,
          position: Vector2(GameConfig.width / 2, 338),
          size: Vector2(Difficulty.values.length * (pillWidth + gap) - gap, pillHeight),
        );

  static const double pillWidth = 124, pillHeight = 46, gap = 12;
  Difficulty selected;
  final void Function(Difficulty) onChanged;

  @override
  Future<void> onLoad() async {
    for (final (i, d) in Difficulty.values.indexed) {
      add(_DifficultyPill(d, Vector2(i * (pillWidth + gap), 0), () {
        selected = d;
        onChanged(d);
      }));
    }
  }
}

class _DifficultyPill extends PositionComponent with TapCallbacks, HasAncestor<DifficultyPicker> {
  _DifficultyPill(this.level, Vector2 position, this.onPressed)
      : super(position: position, size: Vector2(DifficultyPicker.pillWidth, DifficultyPicker.pillHeight));

  final Difficulty level;
  final void Function() onPressed;
  static final _on = Paint()..color = const Color(0xFFFFD866);
  static final _off = Paint()..color = const Color(0xB0362412);
  static final _rimOn = Paint()
    ..color = const Color(0xFF4A3220)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  static final _rimOff = Paint()
    ..color = const Color(0x99FFE6A8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _textOn = _text(28, const Color(0xFF4A3220), shadow: 0);
  static final _textOff = _text(28, const Color(0xFFFFF4DC), shadow: 2);

  bool get on => ancestor.selected == level;

  @override
  void render(Canvas canvas) {
    final r = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(23));
    canvas.drawRRect(r, on ? _on : _off);
    canvas.drawRRect(r.deflate(1.5), on ? _rimOn : _rimOff);
    (on ? _textOn : _textOff).render(canvas, Strings.difficultyName(level), size / 2, anchor: Anchor.center);
  }

  @override
  void onTapUp(TapUpEvent event) => onPressed();
}

/// 메인 화면 맨 아래 가운데 책 소개 띠 (14-3단계): "“작고 쓸모 있는 코딩 딴짓” 저자가 만든 게임 [책 보기]".
/// 누르면 서점 링크 창을 연다.
class BookBadge extends PositionComponent with TapCallbacks {
  BookBadge({required this.onPressed}) : super(anchor: Anchor.center, position: Vector2(GameConfig.width / 2, 672));

  final void Function() onPressed;
  static final _label = _text(28, const Color(0xFFFFF4DC), shadow: 2);
  static final _more = _text(24, const Color(0xFF4A3220), shadow: 0);
  final _bg = Paint()..color = const Color(0xB0362412);
  final _rim = Paint()
    ..color = const Color(0x99FFE6A8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final _tag = Paint()..color = const Color(0xFFFFD866);
  static const double _padX = 22, _gap = 14, _tagPadX = 14, _height = 50;
  late final double _labelWidth = _label.getLineMetrics(Strings.bookPromo).width;
  late final double _moreWidth = _more.getLineMetrics(Strings.bookMore).width;
  bool _down = false;

  @override
  Future<void> onLoad() async {
    size = Vector2(_padX + _labelWidth + _gap + _moreWidth + 2 * _tagPadX + 10, _height);
  }

  @override
  void render(Canvas canvas) {
    final r = RRect.fromRectAndRadius(size.toRect().translate(0, _down ? 2 : 0), const Radius.circular(_height / 2));
    canvas.drawRRect(r, _bg);
    canvas.drawRRect(r.deflate(1), _rim);
    final y = size.y / 2 + (_down ? 2 : 0);
    _label.render(canvas, Strings.bookPromo, Vector2(_padX, y), anchor: Anchor.centerLeft);
    final tag = Rect.fromLTWH(_padX + _labelWidth + _gap, y - 17, _moreWidth + 2 * _tagPadX, 34);
    canvas.drawRRect(RRect.fromRectAndRadius(tag, const Radius.circular(17)), _tag);
    _more.render(canvas, Strings.bookMore, Vector2(tag.center.dx, tag.center.dy), anchor: Anchor.center);
  }

  @override
  void onTapDown(TapDownEvent event) => _down = true;

  @override
  void onTapCancel(TapCancelEvent event) => _down = false;

  @override
  void onTapUp(TapUpEvent event) {
    _down = false;
    onPressed();
  }
}

/// 큰 나무 버튼. 숨 쉬듯 커졌다 작아진다.
class StartButton extends PositionComponent with TapCallbacks {
  StartButton({required super.position, required this.onPressed}) : super(size: Vector2(300, 96), anchor: Anchor.center);

  final void Function() onPressed;
  final _bg = Paint()..color = const Color(0xFFFFD866);
  final _rim = Paint()
    ..color = const Color(0xFF4A3220)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5;
  final _shadow = Paint()..color = const Color(0x66000000);
  final _label = _text(48, const Color(0xFF4A3220), shadow: 0);
  double _t = 0;
  bool _down = false;

  @override
  void update(double dt) {
    _t += dt;
    scale = Vector2.all(_down ? 0.96 : 1 + sin(_t * 3) * 0.035);
  }

  @override
  void render(Canvas canvas) {
    final r = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(24));
    canvas.drawRRect(r.shift(const Offset(0, 6)), _shadow);
    canvas.drawRRect(r, _bg);
    canvas.drawRRect(r.deflate(2.5), _rim);
    _label.render(canvas, Strings.start, size / 2, anchor: Anchor.center);
  }

  @override
  void onTapDown(TapDownEvent event) => _down = true;

  @override
  void onTapCancel(TapCancelEvent event) => _down = false;

  @override
  void onTapUp(TapUpEvent event) {
    _down = false;
    onPressed();
  }
}

/// 3 → 2 → 1 → 시작! 숫자가 튀어나왔다 줄어든다. 끝나면 [onDone].
class Countdown extends PositionComponent with TapCallbacks, HasGameReference<ForestGame>, RunsWhileFrozen {
  Countdown({required this.onDone}) : super(size: Vector2(GameConfig.width, GameConfig.height), priority: 3000);

  static const int from = 3;
  static const double step = 1.0, goTime = 0.7;

  final void Function() onDone;
  final _dim = Paint()..color = const Color(0x40000000);
  final _badge = Paint()..color = const Color(0xE0473020);
  final _badgeRim = Paint()
    ..color = const Color(0xFFE9D3A6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6;
  double _t = 0;
  int _shown = -1;

  /// 숫자 뒤 둥근 판 크기: 숫자가 바뀔 때마다 통 튀었다 가라앉는다.
  double get _badgeScale {
    final local = _t < from * step ? _t % step : _t - from * step;
    return 1 + 0.25 * exp(-local * 9);
  }

  /// 끝날 때까지 걸리는 시간 (테스트용).
  static double get total => from * step + goTime;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    final index = _t < from * step ? (_t / step).floor() : from;
    if (index != _shown) {
      _shown = index;
      final last = index == from;
      game.sfx.play(last ? Sfx.go : Sfx.tick);
      removeAll(children.whereType<TextComponent>());
      add(TextComponent(
        text: last ? Strings.go : '${from - index}',
        textRenderer: _text(last ? 130 : 180, last ? const Color(0xFFFFE066) : const Color(0xFFFFF4DC), shadow: 8),
        anchor: Anchor.center,
        position: size / 2,
        scale: Vector2.all(1.8),
      )..add(ScaleEffect.to(Vector2.all(1), EffectController(duration: 0.35, curve: Curves.easeOutBack))));
    }
    if (_t >= total) {
      removeFromParent();
      onDone();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), _dim);
    final center = Offset(size.x / 2, size.y / 2);
    final r = (_shown == from ? 150.0 : 120.0) * _badgeScale;
    if (_shown == from) {
      // 시작!은 가로로 긴 판
      final rect = Rect.fromCenter(center: center, width: r * 3.1, height: r * 1.6);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(r * 0.8)), _badge);
      canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(10), Radius.circular(r * 0.7)), _badgeRim);
    } else {
      canvas.drawCircle(center, r, _badge);
      canvas.drawCircle(center, r - 10, _badgeRim);
    }
  }

  /// 카운트다운 동안 탭을 막는다.
  @override
  void onTapDown(TapDownEvent event) {}
}
