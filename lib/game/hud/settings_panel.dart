import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../config.dart';
import '../strings.dart';
import 'frozen.dart';
import 'panel.dart';

const _ink = Color(0xFF4A3220);
const _cream = Color(0xFFFFF4DC);

TextPaint _text(double size, Color color) => TextPaint(
      style: TextStyle(fontFamily: GameConfig.fontFamily, fontWeight: FontWeight.w700, fontSize: size, color: color),
    );

/// 설정 창 (16-2단계): 언어, 효과음, 배경음악, (Windows) 화면. 줄마다 두 가지 중 하나를 고른다.
///
/// 메인 화면과 판의 일시정지 창에서 연다. 바꾸는 즉시 [onSound] 같은 함수를 부른다 (저장은 부른 쪽이).
/// 함수가 없는 줄은 보이지 않는다: 판 안에서는 언어 줄을 빼고(글이 이미 그려져 있어서), 웹·Android는 화면 줄이 없다.
class SettingsPanel extends PositionComponent with TapCallbacks, RunsWhileFrozen {
  SettingsPanel({
    required this.sound,
    required this.music,
    required this.onSound,
    required this.onMusic,
    required this.onClose,
    this.lang,
    this.onLang,
    this.fullscreen,
    this.onFullscreen,
  }) : super(size: Vector2(GameConfig.width, GameConfig.height), priority: 4500);

  bool sound, music;
  Lang? lang;
  bool? fullscreen;
  final void Function(bool) onSound, onMusic;
  final void Function(Lang)? onLang;
  final void Function(bool)? onFullscreen;
  final void Function() onClose;

  static const double boxWidth = 660, titleY = 62, firstRowY = 128, rowGap = 74, padX = 52;
  static const double pillWidth = 168, pillHeight = 54, pillGap = 14;

  final _dim = Paint()..color = const Color(0x99000000);
  static final _title = _text(56, _cream);
  static final _label = _text(32, const Color(0xFFE9D3A6));

  /// 보이는 줄 (위에서부터).
  late final List<ChoiceRow> rows;

  @override
  Future<void> onLoad() async {
    rows = [
      if (onLang != null)
        ChoiceRow(Strings.language, [Strings.langName(Lang.ko), Strings.langName(Lang.en)], () => lang == Lang.en ? 1 : 0,
            (i) {
          lang = i == 0 ? Lang.ko : Lang.en;
          onLang!(lang!);
        }),
      ChoiceRow(Strings.soundFx, [Strings.on, Strings.off], () => sound ? 0 : 1, (i) => onSound(sound = i == 0)),
      ChoiceRow(Strings.music, [Strings.on, Strings.off], () => music ? 0 : 1, (i) => onMusic(music = i == 0)),
      if (onFullscreen != null && fullscreen != null)
        ChoiceRow(Strings.screen, [Strings.windowed, Strings.fullscreen], () => fullscreen! ? 1 : 0,
            (i) => onFullscreen!(fullscreen = i == 1)),
    ];
    final close = PanelButton(Strings.close, () {
      removeFromParent();
      onClose();
    });
    final height = firstRowY + rows.length * rowGap + 18 + PanelButton.buttonSize.y + 32;
    final box = _Box(Vector2(boxWidth, height));
    box.add(TextComponent(text: Strings.settings, textRenderer: _title, anchor: Anchor.center, position: Vector2(boxWidth / 2, titleY)));
    for (final (i, row) in rows.indexed) {
      final y = firstRowY + i * rowGap;
      box.add(TextComponent(text: row.label, textRenderer: _label, anchor: Anchor.centerLeft, position: Vector2(padX, y + pillHeight / 2)));
      for (var c = 0; c < 2; c++) {
        final x = boxWidth - padX - (2 - c) * pillWidth - (1 - c) * pillGap;
        box.add(row.pills[c]..position = Vector2(x, y));
      }
    }
    box.add(close..position = Vector2((boxWidth - close.size.x) / 2, firstRowY + rows.length * rowGap + 18));
    add(box);
  }

  @override
  void render(Canvas canvas) => canvas.drawRect(size.toRect(), _dim);

  /// 창 밖을 눌러도 아래로 전달되지 않게.
  @override
  void onTapDown(TapDownEvent event) {}
}

/// 설정 한 줄: 이름과 고를 것 둘.
class ChoiceRow {
  ChoiceRow(this.label, List<String> choices, this.selected, void Function(int) onPick)
      : pills = [for (final (i, c) in choices.indexed) ChoicePill(c, () => selected() == i, () => onPick(i))];

  final String label;

  /// 지금 고른 번호 (0 또는 1).
  final int Function() selected;
  final List<ChoicePill> pills;
}

/// 고르는 알약 버튼. 고른 것은 노랗게.
class ChoicePill extends PositionComponent with TapCallbacks {
  ChoicePill(this.label, this.isOn, this.onPressed) : super(size: Vector2(SettingsPanel.pillWidth, SettingsPanel.pillHeight));

  final String label;
  final bool Function() isOn;
  final void Function() onPressed;

  static final _on = Paint()..color = const Color(0xFFFFD866);
  static final _off = Paint()..color = const Color(0xFF5C4128);
  static final _rimOn = Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  static final _rimOff = Paint()
    ..color = const Color(0x99E9D3A6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _textOn = _text(28, _ink);
  static final _textOff = _text(28, _cream);

  @override
  void render(Canvas canvas) {
    final on = isOn();
    final r = RRect.fromRectAndRadius(size.toRect(), Radius.circular(size.y / 2));
    canvas.drawRRect(r, on ? _on : _off);
    canvas.drawRRect(r.deflate(1.5), on ? _rimOn : _rimOff);
    final paint = on ? _textOn : _textOff;
    // 긴 글(English 등)은 알약 안에 들어가게 줄인다
    final w = paint.getLineMetrics(label).width;
    final k = w > size.x - 20 ? (size.x - 20) / w : 1.0;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(k);
    paint.render(canvas, label, Vector2.zero(), anchor: Anchor.center);
    canvas.restore();
  }

  @override
  void onTapUp(TapUpEvent event) => onPressed();
}

/// 가운데 나무판 (통통 튀며 나타난다).
class _Box extends PositionComponent {
  _Box(Vector2 size)
      : super(size: size, anchor: Anchor.center, position: Vector2(GameConfig.width / 2, GameConfig.height / 2), scale: Vector2.all(0.6));

  final _wood = Paint()..color = const Color(0xF0473020);
  final _rim = Paint()
    ..color = const Color(0xFFE9D3A6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5;

  @override
  Future<void> onLoad() async {
    add(ScaleEffect.to(Vector2.all(1), EffectController(duration: 0.3, curve: Curves.easeOutBack)));
  }

  @override
  void render(Canvas canvas) {
    final r = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(28));
    canvas.drawRRect(r, _wood);
    canvas.drawRRect(r.deflate(8), _rim);
  }
}
