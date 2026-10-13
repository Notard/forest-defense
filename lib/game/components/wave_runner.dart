import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../config.dart';
import '../forest_game.dart';
import '../sfx.dart';
import '../strings.dart';
import '../waves.dart';

/// 웨이브 규칙([WaveDirector])을 게임에 연결한다: 몬스터 내보내기, 웨이브 글자, 큰 무리 경고.
class WaveRunner extends Component with HasGameReference<ForestGame> {
  WaveRunner({Random? random, int startWave = 1, List<Wave> waves = stageWaves, List<int> lanes = const [0, 1, 2, 3, 4]})
      : _random = random ?? Random(),
        director = WaveDirector(random: random, startWave: startWave, waves: waves, lanes: lanes);

  final WaveDirector director;
  final Random _random;

  @override
  void update(double dt) {
    for (final e in director.update(dt, aliveMonsters: game.monsters.length)) {
      switch (e) {
        case SpawnMonster(:final type, :final row):
          // 흙길 안쪽에서 조금씩 다른 위치로 나와 줄 서 보이지 않게
          game.addMonster(type, row: row, x: GameConfig.spawnX + _random.nextDouble() * 30);
        case WaveStarted(:final number, :final big):
          if (!big) game.world.add(Banner(Strings.waveBanner(number)));
        case BigWaveWarning(:final boss):
          game.sfx.play(Sfx.warning);
          game.world.add(Banner(boss ? Strings.bossWave : Strings.bigWave, big: true));
      }
    }
  }
}

/// 화면 가운데에 커졌다가 떠오르며 사라지는 큰 글자.
class Banner extends TextComponent {
  Banner(String text, {bool big = false})
      : _style = TextStyle(
          fontFamily: GameConfig.fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: big ? 84 : 64,
          color: big ? const Color(0xFFFFE066) : const Color(0xFFFFF4DC),
          shadows: const [
            Shadow(color: Color(0xCC2E1A0A), offset: Offset(0, 4)),
            Shadow(color: Color(0x88000000), offset: Offset(0, 6), blurRadius: 10),
          ],
        ),
        super(
          text: text,
          anchor: Anchor.center,
          position: Vector2(GameConfig.width / 2, GameConfig.height * 0.42),
          priority: 1200,
          scale: Vector2.all(0.4),
        );

  static const double life = 2.6;
  final TextStyle _style;
  double _age = 0;

  @override
  Future<void> onLoad() async {
    textRenderer = TextPaint(style: _style);
    addAll([
      ScaleEffect.to(Vector2.all(1), EffectController(duration: 0.35, curve: Curves.easeOutBack)),
      MoveByEffect(Vector2(0, -20), EffectController(duration: 1.0, startDelay: 1.6, curve: Curves.easeIn)),
      RemoveEffect(delay: life),
    ]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    // 마지막 1초 동안 흐려진다 (TextComponent에는 투명도 효과가 없어 글자색을 직접 낮춘다)
    _age += dt;
    if (_age > life - 1) {
      final alpha = ((life - _age) / 1).clamp(0.0, 1.0);
      textRenderer = TextPaint(
        style: _style.copyWith(
          color: _style.color!.withValues(alpha: alpha),
          shadows: [for (final s in _style.shadows!) Shadow(color: s.color.withValues(alpha: s.color.a * alpha), offset: s.offset, blurRadius: s.blurRadius)],
        ),
      );
    }
  }
}
