@Tags(['shots'])
library;

import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/hud/title.dart';
import 'package:forest_defense/game/progress.dart';
import 'package:forest_defense/game/stages.dart';
import 'package:forest_defense/game/units.dart';
import 'package:forest_defense/menu/help_panel.dart';
import 'package:forest_defense/menu/menu_game.dart';

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

  // 도움말 세 쪽 (12-4단계). 1-1·1-2를 깬 진행: 거북이·고슴도치까지 보이고 나머지는 그림자
  for (final page in HelpPage.values) {
    GameTester(() => MenuGame(progress: Progress(stars: {'1-1': 3, '1-2': 2}), onPlay: (_) {}, sound: false)).testGameWidget(
      '도움말 ${page.name}',
      verify: (game, tester) async {
        Future<void> waitFor(bool Function() done) async {
          for (var i = 0; i < 400 && !done(); i++) {
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
            await tester.pump();
          }
        }

        await waitFor(() => game.world.children.whereType<TitleScreen>().any((t) => t.children.length > 3));
        game.openHelp();
        await waitFor(() => game.world.children.whereType<HelpPanel>().any((p) => p.isMounted));
        final panel = game.world.children.whereType<HelpPanel>().single;
        await tester.runAsync(() => panel.show(page));
        for (var i = 0; i < 40; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
          await tester.pump(const Duration(milliseconds: 20));
        }
        await expectLater(find.byType(GameWidget<MenuGame>), matchesGoldenFile('shots/help_${page.name}.png'));
      },
    );
  }
}
