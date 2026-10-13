import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../game/art.dart';
import '../game/config.dart';
import '../game/hud/panel.dart';
import '../game/monsters.dart';
import '../game/progress.dart';
import '../game/sfx.dart';
import '../game/stages.dart';
import '../game/strings.dart';
import '../game/units.dart';

const _ink = Color(0xFF4A3220);
const _cream = Color(0xFFFFF4DC);
const _sand = Color(0xFFE9D3A6);
const _gold = Color(0xFFFFE066);

TextPaint _text(double size, Color color) => TextPaint(
      style: TextStyle(fontFamily: GameConfig.fontFamily, fontWeight: FontWeight.w700, fontSize: size, color: color),
    );

enum HelpPage { howTo, friends, monsters }

/// 메인 화면의 도움말 (12-4단계): 놀이 방법 · 친구들 · 몬스터 세 쪽. 뒤를 어둡게 덮고 누름을 막는다.
class HelpPanel extends PositionComponent with TapCallbacks, HasGameReference<FlameGame> {
  HelpPanel({required this.progress, this.sfx, this.onClose})
      : super(size: Vector2(GameConfig.width, GameConfig.height), priority: 4000);

  /// 아직 못 만난 친구는 그림자로 가린다.
  final Progress progress;
  final SoundBoard? sfx;
  final void Function()? onClose;

  /// 나무판 (논리 좌표).
  static const Rect board = Rect.fromLTWH(70, 40, 1140, 640);

  /// 쪽 내용이 들어가는 칸 (판 안 좌표가 아니라 화면 좌표).
  static const Rect content = Rect.fromLTWH(110, 196, 1060, 384);

  static Rect tabRect(int i) => Rect.fromLTWH(GameConfig.width / 2 - 330 + i * 230.0, 122, 200, 56);

  HelpPage page = HelpPage.howTo;
  final _dim = Paint()..color = const Color(0xB3000000);
  late final PositionComponent _body;
  PositionComponent? _page;
  late final PanelButton closeButton;

  @override
  Future<void> onLoad() async {
    _body = PositionComponent(size: size, anchor: Anchor.center, position: size / 2, scale: Vector2.all(0.85));
    _body.add(_Board());
    _body.add(TextComponent(text: Strings.help, textRenderer: _text(52, _cream), anchor: Anchor.center, position: Vector2(GameConfig.width / 2, 86)));
    for (final p in HelpPage.values) {
      _body.add(HelpTab(p, tabRect(p.index), this));
    }
    closeButton = PanelButton(Strings.close, close);
    closeButton.position = Vector2(GameConfig.width / 2 - closeButton.size.x / 2, board.bottom - 92);
    _body.add(closeButton);
    _body.add(ScaleEffect.to(Vector2.all(1), EffectController(duration: 0.22, curve: Curves.easeOutBack)));
    add(_body);
    await show(HelpPage.howTo);
  }

  Future<void> show(HelpPage p) async {
    page = p;
    _page?.removeFromParent();
    final next = switch (p) {
      HelpPage.howTo => HowToPage(),
      HelpPage.friends => CardPage.friends(progress),
      HelpPage.monsters => CardPage.monsters(),
    };
    _page = next;
    await _body.add(next);
  }

  void close() {
    sfx?.play(Sfx.place);
    removeFromParent();
    onClose?.call();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), _dim);
  }

  /// 판 밖·판 위 빈 곳을 눌러도 아래 메인 화면으로 가지 않게.
  @override
  void onTapDown(TapDownEvent event) {}
}

/// 판 자체를 그리는 바탕 (탭·쪽보다 먼저 그려지도록 _body의 맨 아래).
class _Board extends PositionComponent {
  _Board() : super(position: HelpPanel.board.topLeft.toVector2(), size: HelpPanel.board.size.toVector2(), priority: -1);

  final _wood = Paint()..color = const Color(0xFF473020);
  final _rim = Paint()
    ..color = _sand
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5;

  @override
  void render(Canvas canvas) {
    final r = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(30));
    canvas.drawRRect(r, _wood);
    canvas.drawRRect(r.deflate(9), _rim);
  }
}

/// 쪽 고르기 탭. 고른 탭은 노랗게.
class HelpTab extends PositionComponent with TapCallbacks {
  HelpTab(this.page, Rect r, this.panel) : super(position: r.topLeft.toVector2(), size: r.size.toVector2());

  final HelpPage page;
  final HelpPanel panel;
  final _on = Paint()..color = const Color(0xFFFFD866);
  final _off = Paint()..color = const Color(0xFF8A6A48);
  final _rim = Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  static final _labelOn = _text(30, _ink);
  static final _labelOff = _text(30, _sand);

  bool get selected => panel.page == page;

  String get label => switch (page) {
        HelpPage.howTo => Strings.helpHowTo,
        HelpPage.friends => Strings.helpFriends,
        HelpPage.monsters => Strings.helpMonsters,
      };

  @override
  void render(Canvas canvas) {
    final r = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(18));
    canvas.drawRRect(r, selected ? _on : _off);
    canvas.drawRRect(r.deflate(1.5), _rim);
    (selected ? _labelOn : _labelOff).render(canvas, label, size / 2, anchor: Anchor.center);
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (selected) return;
    panel.sfx?.play(Sfx.place);
    panel.show(page);
  }
}

/// 놀이 방법: 아이콘 + 제목 + 설명 여섯 줄.
class HowToPage extends PositionComponent with HasGameReference<FlameGame> {
  HowToPage() : super(position: HelpPanel.content.topLeft.toVector2(), size: HelpPanel.content.size.toVector2());

  static const double rowHeight = 54, iconSize = 46, textX = 92;
  static final titlePaint = _text(26, _gold);
  static final linePaint = _text(23, _cream);
  static final _lvPaint = _text(24, _ink);

  /// 줄마다 아이콘. null이면 코드로 그린다: '별 세 개'는 별 셋, '레벨업'은 Lv 배지.
  final List<Sprite?> _icons = [];

  @override
  Future<void> onLoad() async {
    Future<Sprite> fx(String name) async => Sprite(await game.images.load('fx/$name.webp'));
    final fox = await CharacterArt.load(game, UnitType.fox.sheet);
    _icons.addAll([await fx('acorn'), portrait(fox, UnitType.fox.idleAction), null, await fx('shovel'), await fx('log'), null, await fx('pinecone')]);
  }

  final _star = Paint()..color = const Color(0xFFFFD34D);
  final _starRim = Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;

  @override
  void render(Canvas canvas) {
    for (final (i, (title, line)) in Strings.howTo.indexed) {
      final y = i * rowHeight;
      final center = Offset(iconSize / 2 + 8, y + rowHeight / 2);
      final icon = i < _icons.length ? _icons[i] : null;
      if (icon != null) {
        drawFitted(canvas, icon, Rect.fromCenter(center: center, width: iconSize, height: iconSize));
      } else if (title == Strings.howTo[2].$1) {
        // 레벨업: 노란 동그라미에 Lv
        canvas.drawCircle(center, 22, _star);
        canvas.drawCircle(center, 22, _starRim);
        _lvPaint.render(canvas, 'Lv', Vector2(center.dx, center.dy), anchor: Anchor.center);
      } else {
        for (var k = 0; k < 3; k++) {
          final p = StarRow.star(center + Offset((k - 1) * 18.0, k == 1 ? -6 : 6), 10);
          canvas.drawPath(p, _star);
          canvas.drawPath(p, _starRim);
        }
      }
      titlePaint.render(canvas, title, Vector2(textX, y + 13), anchor: Anchor.centerLeft);
      linePaint.render(canvas, line, Vector2(textX, y + 39), anchor: Anchor.centerLeft);
    }
  }
}

/// 친구들 · 몬스터: 그림 카드 (한 줄에 4장).
class CardPage extends PositionComponent with HasGameReference<FlameGame> {
  CardPage._(this.entries) : super(position: HelpPanel.content.topLeft.toVector2(), size: HelpPanel.content.size.toVector2());

  factory CardPage.friends(Progress progress) {
    final open = progress.unlockedUnits.toSet();
    String? meet(UnitType t) => stages.where((s) => s.unlocks == t).map((s) => s.id).firstOrNull;
    return CardPage._([
      for (final t in UnitType.values)
        open.contains(t)
            ? HelpEntry(sheet: t.sheet, action: t.idleAction, name: Strings.unitName(t), line: Strings.unitAbility(t), cost: t.cost)
            : HelpEntry(sheet: t.sheet, action: t.idleAction, name: Strings.unknown, line: Strings.meetAt(meet(t) ?? ''), hidden: true),
    ]);
  }

  /// 같은 그림을 쓰는 몬스터(버섯 포자·작은 버섯)는 게임 속 키 비율대로 그려서 크기 차이가 보이게 한다.
  factory CardPage.monsters() => CardPage._([
        for (final m in MonsterType.values)
          HelpEntry(
            sheet: m.sheet,
            action: 'walk',
            name: Strings.monsterName(m),
            line: Strings.monsterAbility(m),
            scale: m.displayHeight /
                MonsterType.values.where((o) => o.sheet == m.sheet).map((o) => o.displayHeight).reduce(math.max),
          ),
      ]);

  final List<HelpEntry> entries;

  static const double cardW = 250, cardH = 182, gapX = 16, gapY = 20;

  /// [i]번째 카드 자리 (쪽 안 좌표). 마지막 줄은 가운데로 모은다.
  Rect cardRect(int i) {
    final row = i ~/ 4, col = i % 4;
    final inRow = math.min(4, entries.length - row * 4);
    final rowW = inRow * cardW + (inRow - 1) * gapX;
    return Rect.fromLTWH((size.x - rowW) / 2 + col * (cardW + gapX), row * (cardH + gapY), cardW, cardH);
  }

  /// 카드는 바로 붙이고, 그림은 모두 한꺼번에 읽기 시작해 준비되는 대로 채운다
  /// (처음 보는 친구는 시트를 새로 받아야 해서, 차례로 기다리면 몇 초 동안 쪽이 비어 있었다).
  @override
  void onLoad() {
    for (final (i, e) in entries.indexed) {
      add(HelpCard(e, CharacterArt.load(game, e.sheet).then((art) => portrait(art, e.action)), cardRect(i)));
    }
  }
}

class HelpEntry {
  const HelpEntry({required this.sheet, required this.action, required this.name, required this.line, this.cost, this.hidden = false, this.scale = 1});

  final String sheet, action, name, line;

  /// 친구의 도토리 값 (몬스터는 null).
  final int? cost;

  /// 아직 못 만난 친구: 그림을 그림자로.
  final bool hidden;

  /// 그림 칸 안 크기 비율 (1이면 칸에 꽉, 작은 버섯은 버섯 포자보다 작게).
  final double scale;
}

class HelpCard extends PositionComponent {
  HelpCard(this.entry, Future<Sprite> portrait, Rect r) : super(position: r.topLeft.toVector2(), size: r.size.toVector2()) {
    portrait.then((s) => _portrait = s, onError: (Object _) {});
  }

  final HelpEntry entry;

  /// 그림 (읽는 동안은 null: 글만 보인다).
  Sprite? _portrait;
  bool get hasPortrait => _portrait != null;
  final _bg = Paint()..color = _sand;
  final _hiddenBg = Paint()..color = const Color(0xFF8A7A66);
  final _rim = Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  static final _shadow = Paint()..colorFilter = const ColorFilter.mode(Color(0xFF3A2A1C), BlendMode.srcATop);
  static final namePaint = _text(30, _ink);
  static final linePaint = _text(23, const Color(0xFF6B4A2E));
  static final costPaint = _text(24, _ink);

  @override
  void render(Canvas canvas) {
    final r = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(18));
    canvas.drawRRect(r, entry.hidden ? _hiddenBg : _bg);
    canvas.drawRRect(r.deflate(1.5), _rim);
    final picture = _portrait;
    if (picture != null) {
      final box = Rect.fromLTWH(20, 10, size.x - 40, 88);
      final h = box.height * entry.scale;
      drawFitted(canvas, picture, Rect.fromLTWH(box.left, box.bottom - h, box.width, h), paint: entry.hidden ? _shadow : null, bottom: true);
    }
    namePaint.render(canvas, entry.name, Vector2(size.x / 2, 120), anchor: Anchor.center);
    linePaint.render(canvas, entry.line, Vector2(size.x / 2, 156), anchor: Anchor.center);
    final cost = entry.cost;
    if (cost != null) {
      // 오른쪽 위에 도토리 값
      final badge = RRect.fromRectAndRadius(Rect.fromLTWH(size.x - 62, 8, 54, 30), const Radius.circular(15));
      canvas.drawRRect(badge, Paint()..color = const Color(0xFFFFD866));
      canvas.drawRRect(badge, _rim);
      costPaint.render(canvas, '$cost', Vector2(size.x - 35, 23), anchor: Anchor.center);
    }
  }
}

/// 캐릭터 시트 첫 프레임에서 그림이 있는 부분만 (HUD 카드와 같은 방법).
Sprite portrait(CharacterArt art, String action) {
  final b = art.bbox;
  final full = art.firstFrame(action);
  return Sprite(full.image, srcPosition: Vector2(b.left, b.top), srcSize: Vector2(b.width, b.height));
}

/// [box] 안에 비율을 지켜 가장 크게. [bottom]이면 바닥에 붙인다 (발이 땅에).
void drawFitted(Canvas canvas, Sprite sprite, Rect box, {Paint? paint, bool bottom = false}) {
  final s = math.min(box.width / sprite.srcSize.x, box.height / sprite.srcSize.y);
  final w = sprite.srcSize.x * s, h = sprite.srcSize.y * s;
  final top = bottom ? box.bottom - h : box.center.dy - h / 2;
  sprite.render(canvas, position: Vector2(box.center.dx - w / 2, top), size: Vector2(w, h), overridePaint: paint);
}
