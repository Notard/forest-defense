import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../art.dart';
import '../config.dart';
import '../forest_game.dart';
import '../strings.dart';
import '../units.dart';
import 'layout.dart';

const _ink = Color(0xFF4A3220);
const _cream = Color(0xFFFFF4DC);
const _panel = Color(0xB0362412);

TextPaint _text(double size, {Color color = _cream}) => TextPaint(
      style: TextStyle(
        fontFamily: GameConfig.fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: size,
        color: color,
        shadows: const [Shadow(color: Color(0x99000000), offset: Offset(0, 2), blurRadius: 2)],
      ),
    );

/// 화면 위·아래 HUD 전체. 월드 위에 가장 높은 우선순위로 그린다.
class Hud extends PositionComponent with HasGameReference<ForestGame> {
  Hud() : super(size: Vector2(GameConfig.width, GameConfig.height), priority: 1000);

  final _panelPaint = Paint()..color = _panel;
  final _barTrack = Paint()..color = const Color(0xFF2E2014);
  final _barFill = Paint()..color = const Color(0xFF9BCB5A);

  late final AcornCounter acornCounter;
  late final List<UnitCard> cards;
  late final ShovelButton shovel;

  @override
  Future<void> onLoad() async {
    final acorn = Sprite(await game.images.load('fx/acorn.webp'));
    final shovelIcon = Sprite(await game.images.load('fx/shovel.webp'));
    acornCounter = AcornCounter(acorn);
    cards = [
      for (final (i, type) in UnitType.values.indexed)
        UnitCard(type, await CharacterArt.load(game, type.sheet), HudLayout.cards[i]),
    ];
    shovel = ShovelButton(shovelIcon);
    await addAll([
      acornCounter,
      ...cards,
      shovel,
      PauseButton(),
      _waveLabel,
    ]);
  }

  final _waveLabel = TextComponent(
    text: '',
    textRenderer: _text(30),
    anchor: Anchor.centerLeft,
    position: Vector2(24, HudLayout.progressBar.center.dy),
  );
  final _marker = Paint()..color = _cream;
  final _bigMarker = Paint()..color = const Color(0xFFFFE066);

  @override
  void update(double dt) {
    final d = game.waveRunner?.director;
    _waveLabel.text = d == null ? '' : Strings.wave(d.displayWave, d.waves.length);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(RRect.fromRectAndRadius(HudLayout.topPanel, const Radius.circular(16)), _panelPaint);
    canvas.drawRect(HudLayout.bottomBand, _panelPaint);
    final d = game.waveRunner?.director;
    if (d == null) return;
    // 진행 바: 내보낸 몬스터 비율. 왼쪽이 시작, 오른쪽 끝이 마지막 웨이브
    final bar = HudLayout.progressBar;
    canvas.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(8)), _barTrack);
    if (d.progress > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bar.left, bar.top, max(bar.height, bar.width * d.progress), bar.height), const Radius.circular(8)),
        _barFill,
      );
    }
    // 웨이브가 시작되는 자리마다 작은 표시, 큰 무리는 노란 표시
    var before = 0;
    for (final w in d.waves) {
      if (before > 0) {
        final x = bar.left + bar.width * before / d.total;
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(x - 2, bar.top - 6, 4, bar.height + 12), const Radius.circular(2)),
            w.big ? _bigMarker : _marker);
      }
      before += w.monsters.length;
    }
  }
}

/// 둥근 나무판 슬롯 (카드·삽·도토리 칸 공통 바탕).
void _drawSlot(Canvas canvas, Vector2 size, {required bool highlighted}) {
  final r = RRect.fromRectAndRadius(Offset.zero & Size(size.x, size.y), const Radius.circular(12));
  canvas.drawRRect(r, Paint()..color = const Color(0xFFE9D3A6));
  canvas.drawRRect(
    r.deflate(1.5),
    Paint()
      ..color = highlighted ? const Color(0xFFFFE066) : _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = highlighted ? 5 : 3,
  );
}

/// 왼쪽 위 도토리 수.
class AcornCounter extends PositionComponent with HasGameReference<ForestGame> {
  AcornCounter(this._icon)
      : super(position: HudLayout.acornCounter.topLeft.toVector2(), size: HudLayout.acornCounter.size.toVector2());

  final Sprite _icon;
  final _bg = Paint()..color = const Color(0xFFE9D3A6);

  /// 아이콘 오른쪽에 숫자가 들어갈 폭. 자릿수가 늘면 글자를 줄여 아이콘과 겹치지 않게 한다.
  static const double _numberRoom = 58;
  final Map<int, TextPaint> _sized = {};

  TextPaint _fit(String text) {
    for (final size in [40, 36, 32, 28, 24]) {
      final paint = _sized.putIfAbsent(size, () => _text(size.toDouble(), color: _ink));
      if (paint.getLineMetrics(text).width <= _numberRoom) return paint;
    }
    return _sized[24]!;
  }

  /// 날아오는 도토리가 닿는 곳 (월드 좌표).
  Vector2 get target => absolutePosition + Vector2(30, size.y / 2);

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(RRect.fromRectAndRadius(size.toRect(), const Radius.circular(12)), _bg);
    _icon.render(canvas, position: Vector2(4, size.y / 2), size: Vector2.all(48), anchor: Anchor.centerLeft);
    final text = '${game.garden.acorns}';
    _fit(text).render(canvas, text, Vector2(size.x - 8, size.y / 2), anchor: Anchor.centerRight);
  }
}

/// 유닛 카드: 초상화 + 비용. 쿨다운은 위에서부터 어두운 덮개, 도토리가 모자라면 전체를 흐리게.
class UnitCard extends PositionComponent with TapCallbacks, HasGameReference<ForestGame> {
  UnitCard(this.type, this._art, Rect slot)
      : _home = slot.topLeft.toVector2(),
        super(position: slot.topLeft.toVector2(), size: slot.size.toVector2());

  final UnitType type;
  final CharacterArt _art;
  final Vector2 _home;
  late final Sprite _portrait;
  final _cost = _text(26, color: _ink);
  final _shade = Paint()..color = const Color(0x8C1E140A);
  final _dim = Paint()..color = const Color(0x661E140A);

  bool get selected => game.selectedUnit == type;

  @override
  Future<void> onLoad() async {
    // 초상화: 기본 동작 첫 프레임에서 그림이 있는 영역만 잘라 쓴다
    final b = _art.bbox;
    final full = _art.firstFrame(type.idleAction);
    _portrait = Sprite(full.image, srcPosition: Vector2(b.left, b.top), srcSize: Vector2(b.width, b.height));
  }

  @override
  void update(double dt) {
    // 고른 카드는 살짝 위로
    position.y = _home.y - (selected ? 5 : 0);
  }

  @override
  void render(Canvas canvas) {
    _drawSlot(canvas, size, highlighted: selected);
    final box = Rect.fromLTWH(6, 6, size.x - 12, 58);
    final s = (box.width / _portrait.srcSize.x).clamp(0.0, box.height / _portrait.srcSize.y);
    final w = _portrait.srcSize.x * s, h = _portrait.srcSize.y * s;
    _portrait.render(canvas, position: Vector2(box.center.dx - w / 2, box.bottom - h), size: Vector2(w, h));
    _cost.render(canvas, '${type.cost}', Vector2(size.x / 2, size.y - 14), anchor: Anchor.center);

    final g = game.garden;
    if (!g.canAfford(type)) {
      canvas.drawRRect(RRect.fromRectAndRadius(size.toRect(), const Radius.circular(12)), _dim);
    }
    final f = g.cooldownFraction(type);
    if (f > 0) {
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(size.toRect(), const Radius.circular(12)));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y * f), _shade);
      canvas.restore();
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!game.selectCard(type)) shake();
  }

  /// 누를 수 없을 때 좌우로 짧게 흔든다.
  void shake() {
    if (children.whereType<Effect>().isNotEmpty) return;
    add(SequenceEffect([
      MoveByEffect(Vector2(-5, 0), EffectController(duration: 0.04)),
      MoveByEffect(Vector2(10, 0), EffectController(duration: 0.08)),
      MoveByEffect(Vector2(-5, 0), EffectController(duration: 0.04, curve: Curves.easeOut)),
    ]));
  }
}

/// 삽: 누르면 치우기 모드, 다시 누르면 취소.
class ShovelButton extends PositionComponent with TapCallbacks, HasGameReference<ForestGame> {
  ShovelButton(this._icon)
      : super(position: HudLayout.shovel.topLeft.toVector2(), size: HudLayout.shovel.size.toVector2());

  final Sprite _icon;

  @override
  void render(Canvas canvas) {
    _drawSlot(canvas, size, highlighted: game.shovelMode);
    _icon.render(canvas, position: size / 2, size: Vector2.all(64), anchor: Anchor.center);
  }

  @override
  void onTapDown(TapDownEvent event) => game.toggleShovel();
}

/// 일시정지 버튼.
class PauseButton extends PositionComponent with TapCallbacks, HasGameReference<ForestGame> {
  PauseButton() : super(position: HudLayout.pause.topLeft.toVector2(), size: HudLayout.pause.size.toVector2());

  final _bg = Paint()..color = _panel;
  final _bars = Paint()..color = _cream;

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(RRect.fromRectAndRadius(size.toRect(), const Radius.circular(14)), _bg);
    for (final x in [size.x / 2 - 11, size.x / 2 + 4]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 16, 7, size.y - 32), const Radius.circular(3)), _bars);
    }
  }

  @override
  void onTapDown(TapDownEvent event) => game.togglePause();
}
