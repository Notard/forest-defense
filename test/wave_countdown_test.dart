import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/hud/hud.dart';
import 'package:forest_defense/game/strings.dart';
import 'package:forest_defense/game/waves.dart';

import 'support.dart';

/// 14-2단계: 판 시작 뒤 첫 웨이브까지 줄어드는 막대와 글자.
void main() {
  test('웨이브 규칙은 첫 웨이브 전인지와 남은 시간을 알려 준다', () {
    final d = WaveDirector();
    expect(d.beforeFirstWave, isTrue);
    expect(d.untilNext, WaveDirector.firstDelay);
    d.update(10, aliveMonsters: 0);
    expect(d.untilNext, closeTo(WaveDirector.firstDelay - 10, 1e-9));
    d.update(WaveDirector.firstDelay, aliveMonsters: 0);
    expect(d.beforeFirstWave, isFalse);
  });

  GameTester(() => ForestGame(nestAcorns: false, sound: false, intro: false)).testGameWidget(
    '"몬스터가 오기까지 30초" 막대가 줄어들고, 첫 웨이브가 시작되면 사라진다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final c = game.hud.firstWave!;
      String shown() => c.children.whereType<TextComponent>().map((t) => t.text).join(' ');
      expect(shown(), '${Strings.firstWaveIn} ${Strings.seconds(30)}');
      expect(c.fraction, 1);

      await tester.runAsync(() async {
        for (var i = 0; i < 20 * 10; i++) {
          game.update(0.1);
        }
        await Future<void>.delayed(Duration.zero);
      });
      expect(c.fraction, closeTo(1 / 3, 0.01));
      expect(shown(), '${Strings.firstWaveIn} ${Strings.seconds(10)}');

      await tester.runAsync(() async {
        for (var i = 0; i < 12 * 10; i++) {
          game.update(0.1);
          await Future<void>.delayed(Duration.zero);
        }
      });
      expect(game.waveRunner!.director.beforeFirstWave, isFalse);
      expect(c.isMounted, isFalse, reason: '웨이브가 시작되면 사라진다');
    },
  );

  GameTester(testGame).testGameWidget(
    '웨이브가 없는 판(연습)에는 막대가 없다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      expect(game.hud.firstWave, isNull);
      expect(game.hud.children.whereType<FirstWaveCountdown>(), isEmpty);
    },
  );
}
