import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../game/art.dart';
import '../game/book.dart' as book;
import '../game/config.dart';
import '../game/hud/panel.dart';
import '../game/hud/title.dart';
import '../game/music.dart';
import '../game/progress.dart';
import '../game/sfx.dart';
import '../game/stages.dart';
import '../game/strings.dart';
import 'help_panel.dart';
import 'shop_screen.dart';

enum MenuPage { title, map, shop }

/// 판 밖의 화면: 메인 화면, 숲 지도, 강화 상점 (plan.md 확장). 판은 ForestGame이 따로 그린다.
class MenuGame extends FlameGame {
  MenuGame({required this.progress, required this.onPlay, this.startPage = MenuPage.title, bool sound = true, this.music, this.openLink = book.openLink})
      : sfx = SoundBoard(enabled: sound)..muted = !progress.soundOn,
        super(camera: CameraComponent.withFixedResolution(width: GameConfig.width, height: GameConfig.height));

  final Progress progress;

  /// 지도에서 스테이지를 고름.
  final void Function(StageDef) onPlay;
  final MenuPage startPage;
  final SoundBoard sfx;

  /// 앱 전체의 배경음악. 메뉴 화면은 모두 '숲속 아침'.
  final Jukebox? music;

  /// 서점 페이지 열기 (테스트에서는 바꿔 끼운다).
  final Future<bool> Function(String url) openLink;
  CenterPanel? _bookPanel;
  MenuPage? page;

  @override
  Color backgroundColor() => GameConfig.backgroundColor;

  @override
  Future<void> onLoad() async {
    CharacterArt.clearCache();
    camera.viewfinder.anchor = Anchor.topLeft;
    await sfx.load();
    await show(startPage);
  }

  /// 도움말을 띄운다 (이미 떠 있으면 그대로).
  void openHelp() {
    if (world.children.whereType<HelpPanel>().isNotEmpty) return;
    sfx.play(Sfx.place);
    world.add(HelpPanel(progress: progress, sfx: sfx));
  }

  /// 책 소개 창 (14-3단계): 책 이름·부제·저자와 서점 버튼 셋.
  void openBook() {
    if (_bookPanel?.parent != null) return;
    sfx.play(Sfx.place);
    late final CenterPanel panel;
    panel = CenterPanel(
      title: Strings.bookTitle,
      lines: Strings.bookLines,
      buttons: [
        for (final s in book.Book.stores) PanelButton(s.name, () => openLink(s.url)),
        PanelButton(Strings.close, () => panel.removeFromParent()),
      ],
    );
    world.add(_bookPanel = panel..priority = 4000); // 메인 화면(3000) 위
  }

  Future<void> show(MenuPage p) async {
    page = p;
    // 웹은 첫 누름 전 자동 재생을 막는다: 메인 화면에서 막혔다면 '게임 시작'을 누를 때(→ 지도) 다시 시작된다
    music?.play(Track.title);
    world.removeAll(world.children);
    await world.add(switch (p) {
      MenuPage.title => TitleScreen(
          onHelp: openHelp,
          onBook: openBook,
          difficulty: progress.difficulty,
          onDifficulty: (d) {
            sfx.play(Sfx.place);
            progress.difficulty = d;
            progress.save();
          },
          onStart: () {
            sfx.play(Sfx.place);
            show(MenuPage.map);
          },
        ),
      MenuPage.map => MapScreen(),
      MenuPage.shop => ShopScreen(),
    });
  }
}

TextPaint _text(double size, Color color, {double shadow = 3}) => TextPaint(
      style: TextStyle(
        fontFamily: GameConfig.fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: size,
        color: color,
        shadows: [Shadow(color: const Color(0xCC2E1A0A), offset: Offset(0, shadow))],
      ),
    );

/// 숲 지도: 스테이지 원판 10개가 길을 따라 놓여 있다. 왼쪽 낮 숲, 오른쪽 밤 숲.
class MapScreen extends PositionComponent with HasGameReference<MenuGame> {
  MapScreen() : super(size: Vector2(GameConfig.width, GameConfig.height));

  /// 원판 자리 (논리 좌표). 앞 다섯이 낮 숲, 뒤 다섯이 밤 숲.
  static const List<Offset> spots = [
    Offset(160, 560), Offset(280, 440), Offset(400, 540), Offset(505, 410), Offset(590, 260),
    Offset(700, 260), Offset(790, 410), Offset(905, 540), Offset(1020, 430), Offset(1125, 270),
  ];

  late final Sprite _background;
  late final Sprite _nightPicture;
  final _shade = Paint()..color = const Color(0x66000000);
  final _nightRim = Paint()
    ..color = const Color(0x99B9D4FF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  /// 밤 숲 구역 (오른쪽).
  static final RRect nightArea = RRect.fromRectAndRadius(const Rect.fromLTWH(648, 125, 620, 565), const Radius.circular(30));
  final _path = Paint()
    ..color = const Color(0xFFE9D3A6)
    ..strokeWidth = 7
    ..strokeCap = StrokeCap.round;

  @override
  Future<void> onLoad() async {
    _background = Sprite(await game.images.load('fx/background.webp'));
    _nightPicture = Sprite(await game.images.load('fx/background_night.webp'));
    final p = game.progress;
    add(TextComponent(text: Strings.map, textRenderer: _text(64, const Color(0xFFFFF4DC), shadow: 5), anchor: Anchor.center, position: Vector2(640, 62)));
    add(TextComponent(text: Strings.dayForest, textRenderer: _text(36, const Color(0xFFFFE6A8)), anchor: Anchor.center, position: Vector2(330, 150)));
    add(TextComponent(text: Strings.nightForest, textRenderer: _text(36, const Color(0xFFB9D4FF)), anchor: Anchor.center, position: Vector2(950, 150)));
    add(TextComponent(text: Strings.pinecones(p.pinecones), textRenderer: _text(32, const Color(0xFFFFF4DC)), anchor: Anchor.centerRight, position: Vector2(1250, 62)));
    add(TextComponent(text: Strings.totalStars(p.totalStars, stages.length * 3), textRenderer: _text(28, const Color(0xFFFFE066)), anchor: Anchor.centerRight, position: Vector2(1250, 104)));
    final back = PanelButton(Strings.toTitle, () => game.show(MenuPage.title))..position = Vector2(24, 26);
    add(back);
    add(ShopButton(canBuy: p.canBuyAny));
    for (final (i, s) in stages.indexed) {
      add(StageNode(s, open: p.isOpen(s), stars: p.starsOf(s), isNext: p.isOpen(s) && !p.cleared(s), position: spots[i].toVector2()));
    }
  }

  @override
  void render(Canvas canvas) {
    _background.render(canvas, size: size);
    // 밤 숲 구역은 밤 그림을 같은 자리에 겹쳐 그린다 (두 그림의 구도가 같아 이어져 보인다)
    canvas.save();
    canvas.clipRRect(nightArea);
    _nightPicture.render(canvas, size: size);
    canvas.restore();
    canvas.drawRect(size.toRect(), _shade);
    canvas.drawRRect(nightArea, _nightRim);
    // 원판을 잇는 점선 길
    for (var i = 0; i + 1 < spots.length; i++) {
      final a = spots[i], b = spots[i + 1];
      final n = ((b - a).distance / 22).floor();
      for (var k = 1; k < n; k++) {
        final t = k / n;
        canvas.drawCircle(Offset.lerp(a, b, t)!, 4, _path);
      }
    }
  }
}

/// 스테이지 원판: 번호, 별, 자물쇠. 다음에 할 스테이지는 빛이 맥박친다.
class StageNode extends PositionComponent with TapCallbacks, HasGameReference<MenuGame> {
  StageNode(this.stage, {required this.open, required this.stars, required this.isNext, required super.position})
      : super(anchor: Anchor.center, size: Vector2.all(stage.boss ? 124 : 100));

  final StageDef stage;
  final bool open;
  final int stars;
  final bool isNext;
  double _t = 0;

  late final _label = _text(stage.boss ? 38 : 32, open ? const Color(0xFF4A3220) : const Color(0xFF7A7A7A), shadow: 0);
  final _wood = Paint()..color = const Color(0xFFE9D3A6);
  final _locked = Paint()..color = const Color(0xFF8A8A80);
  final _rim = Paint()
    ..color = const Color(0xFF4A3220)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5;
  final _glow = Paint()..color = const Color(0xFFFFE066);
  final _gold = Paint()..color = const Color(0xFFFFD34D);
  final _empty = Paint()..color = const Color(0x55FFFFFF);
  final _starRim = Paint()
    ..color = const Color(0xFF4A3220)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    final r = size.x / 2 - 6;
    if (isNext) {
      _glow.color = const Color(0xFFFFE066).withValues(alpha: 0.35 + 0.3 * math.sin(_t * 4));
      canvas.drawCircle(c, r + 10 + 3 * math.sin(_t * 4), _glow);
    }
    canvas.drawCircle(c, r, open ? _wood : _locked);
    canvas.drawCircle(c, r, _rim);
    if (stage.boss) _crown(canvas, Offset(c.dx, c.dy - r - 4), open);
    if (open) {
      _label.render(canvas, stage.id, (c - const Offset(0, 6)).toVector2(), anchor: Anchor.center);
    } else {
      _lock(canvas, c);
    }
    for (var i = 0; i < 3; i++) {
      final p = StarRow.star(Offset(c.dx - 30 + i * 30.0, c.dy + r - 2), 13);
      canvas.drawPath(p, i < stars ? _gold : _empty);
      canvas.drawPath(p, _starRim);
    }
  }

  void _crown(Canvas canvas, Offset bottom, bool open) {
    final w = 44.0, h = 26.0;
    final path = Path()
      ..moveTo(bottom.dx - w / 2, bottom.dy)
      ..lineTo(bottom.dx - w / 2, bottom.dy - h * 0.6)
      ..lineTo(bottom.dx - w / 4, bottom.dy - h * 0.25)
      ..lineTo(bottom.dx, bottom.dy - h)
      ..lineTo(bottom.dx + w / 4, bottom.dy - h * 0.25)
      ..lineTo(bottom.dx + w / 2, bottom.dy - h * 0.6)
      ..lineTo(bottom.dx + w / 2, bottom.dy)
      ..close();
    canvas.drawPath(path, open ? _gold : _locked);
    canvas.drawPath(path, _starRim);
  }

  void _lock(Canvas canvas, Offset c) {
    final body = RRect.fromRectAndRadius(Rect.fromCenter(center: c + const Offset(0, 6), width: 34, height: 28), const Radius.circular(6));
    canvas.drawArc(Rect.fromCenter(center: c - const Offset(0, 8), width: 24, height: 28), math.pi, math.pi, false, _rim);
    canvas.drawRRect(body, Paint()..color = const Color(0xFF4A3220));
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (!open) {
      add(SequenceEffect([
        MoveByEffect(Vector2(-6, 0), EffectController(duration: 0.04)),
        MoveByEffect(Vector2(12, 0), EffectController(duration: 0.08)),
        MoveByEffect(Vector2(-6, 0), EffectController(duration: 0.04, curve: Curves.easeOut)),
      ]));
      return;
    }
    game.sfx.play(Sfx.place);
    game.onPlay(stage);
  }
}

/// 지도 오른쪽 아래 강화 상점 버튼. 살 수 있는 강화가 있으면 뒤에서 빛이 맥박친다.
class ShopButton extends PositionComponent with HasGameReference<MenuGame> {
  ShopButton({required this.canBuy}) : super(position: Vector2(1036, 626), size: Vector2(220, 70));

  final bool canBuy;
  double _t = 0;
  final _glow = Paint();

  @override
  Future<void> onLoad() async {
    add(PanelButton(Strings.shop, () => game.show(MenuPage.shop), width: size.x));
  }

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    if (!canBuy) return;
    _glow.color = const Color(0xFFFFE066).withValues(alpha: 0.35 + 0.3 * math.sin(_t * 4));
    canvas.drawRRect(RRect.fromRectAndRadius(size.toRect().inflate(7 + 2 * math.sin(_t * 4)), const Radius.circular(22)), _glow);
  }
}
