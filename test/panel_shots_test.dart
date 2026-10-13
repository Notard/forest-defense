@Tags(['shots'])
library;

import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/progress.dart';
import 'package:forest_defense/game/stages.dart';
import 'package:forest_defense/game/units.dart';

import 'support.dart';

/// 가운데 판을 진짜 폰트(Gaegu)로 그려 그림으로 남긴다 (눈으로 확인용, 기본 테스트에서는 빠짐).
///   flutter test --run-skipped --tags shots --update-goldens test/panel_shots_test.dart
/// → test/shots/panel_*.png
void main() {
  setUpAll(() async {
    final font = FontLoader('Gaegu')..addFont(rootBundle.load('assets/fonts/Gaegu-Bold.ttf'));
    await font.load();
  });

  Future<void> shoot(ForestGame game, WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 30; i++) {
        game.update(1 / 60);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pump();
    await expectLater(find.byType(GameWidget<ForestGame>), matchesGoldenFile('shots/panel_$name.png'));
  }

  ForestGame stageGame() => ForestGame(
        stage: stageById('1-1'),
        skyAcorns: false,
        waves: false,
        sound: false,
        intro: false,
        onFinish: ({required won, required usedLog, required lostUnit}) =>
            const Reward(stars: 3, newStars: 3, pinecones: 30, unlocked: UnitType.turtle),
      );

  GameTester(stageGame).testGameWidget('클리어', setUp: waitForLoad, verify: (game, tester) async {
    game.win();
    await shoot(game, tester, 'win');
  });
  GameTester(testGame).testGameWidget('게임오버', setUp: waitForLoad, verify: (game, tester) async {
    game.lose();
    await shoot(game, tester, 'lose');
  });
  GameTester(testGame).testGameWidget('일시정지', setUp: waitForLoad, verify: (game, tester) async {
    game.togglePause();
    await shoot(game, tester, 'pause');
  });
}
