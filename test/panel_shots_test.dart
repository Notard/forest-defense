@Tags(['shots'])
library;

import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/components/level_bubble.dart';
import 'package:forest_defense/game/components/unit.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/grid.dart';
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

  // 판 안 레벨업 (12-2단계): Lv3 여우(별 둘), Lv2 곰(별 하나), 거북이 말풍선(맨 윗줄이라 발 아래), 다람쥐 말풍선(머리 위)
  GameTester(() => ForestGame(skyAcorns: false, waves: false, sound: false, intro: false, logsOn: false)).testGameWidget(
    '레벨업',
    setUp: waitForLoad,
    verify: (game, tester) async {
      game.garden.acorns = 10000;
      Future<UnitComponent> put(UnitType t, Cell c) async {
        await tester.runAsync(() async {
          game.selectedUnit = t;
          await game.onCellTapped(c);
          game.update(0);
        });
        return game.unitComponents[c]!;
      }

      final fox = await put(UnitType.fox, (row: 2, col: 3));
      final bear = await put(UnitType.bear, (row: 3, col: 4));
      await put(UnitType.turtle, (row: 0, col: 1));
      await put(UnitType.squirrel, (row: 1, col: 2));
      game.levelUp(fox);
      game.levelUp(fox);
      game.levelUp(bear);
      await tester.runAsync(() async {
        await game.onCellTapped((row: 1, col: 2));
        for (var i = 0; i < 40; i++) {
          game.update(1 / 60);
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      // 거북이 말풍선도 함께 보이도록 하나 더 붙인다 (게임은 하나만 띄우지만 그림용)
      await tester.runAsync(() async {
        await game.world.add(LevelBubble(game.unitComponents[(row: 0, col: 1)]!));
        for (var i = 0; i < 20; i++) {
          game.update(1 / 60);
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await tester.pump();
      await expectLater(find.byType(GameWidget<ForestGame>), matchesGoldenFile('shots/levelup.png'));
    },
  );
}
