@Tags(['shots'])
library;

import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/hud/panel.dart';
import 'package:forest_defense/game/hud/title.dart';
import 'package:forest_defense/game/monsters.dart';
import 'package:forest_defense/game/progress.dart';
import 'package:forest_defense/game/stages.dart';
import 'package:forest_defense/game/strings.dart';
import 'package:forest_defense/game/units.dart';
import 'package:forest_defense/menu/help_panel.dart';
import 'package:forest_defense/menu/menu_game.dart';

import 'support.dart';

/// 16-2단계: 영어 화면과 설정 창을 진짜 폰트로 그려 남긴다 (눈으로 확인용, 기본 테스트에서는 빠짐).
///   flutter test --run-skipped --tags shots --update-goldens test/lang_shots_test.dart
/// → test/shots/lang_*.png
void main() {
  setUpAll(() async {
    final font = FontLoader('Gaegu')..addFont(rootBundle.load('assets/fonts/Gaegu-Bold.ttf'));
    await font.load();
  });
  tearDown(() => Strings.lang = Lang.ko);

  Future<void> settle(WidgetTester tester, {int frames = 40}) async {
    for (var i = 0; i < frames; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
  }

  Future<void> shootGame(ForestGame game, WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 30; i++) {
        game.update(1 / 60);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pump();
    await expectLater(find.byType(GameWidget<ForestGame>), matchesGoldenFile('shots/lang_$name.png'));
  }

  MenuGame menu(Lang lang, {MenuPage page = MenuPage.title}) {
    Strings.lang = lang;
    return MenuGame(
      progress: Progress(stars: {'1-1': 3, '1-2': 2, '1-3': 1}, pinecones: 40),
      onPlay: (_) {},
      startPage: page,
      sound: false,
      onLang: (_) {},
      onFullscreen: (_) {},
    );
  }

  for (final lang in Lang.values) {
    GameTester(() => menu(lang)).testGameWidget('${lang.name} 메인 화면 + 설정', verify: (game, tester) async {
      // 버튼은 캐릭터 그림을 다 읽은 뒤에 붙는다 (버튼 둘 = 설정·도움말)
      await waitFor(tester, () => game.world.children.whereType<TitleScreen>().any((t) => t.children.whereType<PanelButton>().length >= 2));
      await settle(tester);
      await expectLater(find.byType(GameWidget<MenuGame>), matchesGoldenFile('shots/lang_${lang.name}_title.png'));
      game.openSettings();
      await settle(tester);
      await expectLater(find.byType(GameWidget<MenuGame>), matchesGoldenFile('shots/lang_${lang.name}_settings.png'));
    });
  }

  GameTester(() => menu(Lang.en, page: MenuPage.map)).testGameWidget('en 숲 지도', verify: (game, tester) async {
    await settle(tester);
    await expectLater(find.byType(GameWidget<MenuGame>), matchesGoldenFile('shots/lang_en_map.png'));
  });
  GameTester(() => menu(Lang.en, page: MenuPage.shop)).testGameWidget('en 강화 상점', verify: (game, tester) async {
    await settle(tester);
    await expectLater(find.byType(GameWidget<MenuGame>), matchesGoldenFile('shots/lang_en_shop.png'));
  });

  for (final page in HelpPage.values) {
    GameTester(() => menu(Lang.en)).testGameWidget('en 도움말 ${page.name}', verify: (game, tester) async {
      await waitFor(tester, () => game.world.children.whereType<TitleScreen>().any((t) => t.children.length > 3));
      game.openHelp();
      await waitFor(tester, () => game.world.children.whereType<HelpPanel>().any((p) => p.isMounted));
      await tester.runAsync(() => game.world.children.whereType<HelpPanel>().single.show(page));
      await settle(tester);
      await expectLater(find.byType(GameWidget<MenuGame>), matchesGoldenFile('shots/lang_en_help_${page.name}.png'));
    });
  }

  GameTester(() {
    Strings.lang = Lang.en;
    return ForestGame(
      stage: stageById('1-2'),
      units: [UnitType.squirrel, UnitType.fox, UnitType.turtle, UnitType.hedgehog],
      nestAcorns: false,
      sound: false,
      intro: false,
      seenMonsters: {},
      usedUnits: {UnitType.squirrel, UnitType.fox, UnitType.turtle},
      onFullscreen: (_) {},
    );
  }).testGameWidget('en 판: 말풍선, 첫 웨이브 막대, 일시정지, 설정, 소개 창', setUp: waitForLoad, verify: (game, tester) async {
    await shootGame(game, tester, 'en_play');
    game.togglePause();
    await shootGame(game, tester, 'en_pause');
    game.openSettings();
    await shootGame(game, tester, 'en_pause_settings');
  });

  GameTester(() {
    Strings.lang = Lang.en;
    return ForestGame(stage: stageById('1-4'), nestAcorns: false, waves: false, sound: false, intro: false, seenMonsters: {});
  }).testGameWidget('en 처음 보는 몬스터', setUp: waitForLoad, verify: (game, tester) async {
    await tester.runAsync(() => game.addMonster(MonsterType.helmetSlime, row: 2, x: 1000));
    await shootGame(game, tester, 'en_meet');
  });

  GameTester(() {
    Strings.lang = Lang.en;
    return ForestGame(
      stage: stageById('1-1'),
      nestAcorns: false,
      waves: false,
      sound: false,
      intro: false,
      onFinish: ({required won, required lostHeart, required lostUnit}) =>
          const Reward(stars: 2, newStars: 2, pinecones: 20, unlocked: UnitType.turtle),
    );
  }).testGameWidget('en 클리어', setUp: waitForLoad, verify: (game, tester) async {
    game.win();
    await shootGame(game, tester, 'en_win');
  });
}
