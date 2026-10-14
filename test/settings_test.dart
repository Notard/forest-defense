import 'dart:convert';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/difficulty.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/hud/panel.dart';
import 'package:forest_defense/game/hud/settings_panel.dart';
import 'package:forest_defense/game/hud/title.dart';
import 'package:forest_defense/game/monsters.dart';
import 'package:forest_defense/game/progress.dart';
import 'package:forest_defense/game/units.dart';
import 'package:forest_defense/game/upgrades.dart';
import 'package:forest_defense/game/strings.dart';
import 'package:forest_defense/menu/menu_game.dart';

import 'support.dart';

/// 16-2단계: 한국어·영어, 설정 창, (Windows) 전체화면.
void main() {
  tearDown(() => Strings.lang = Lang.ko);

  /// 화면에 나오는 글을 (거의) 모두 모은다.
  List<String> allText() => [
        Strings.title, Strings.wave(1, 5), Strings.waveBanner(2), Strings.firstWaveIn, Strings.seconds(3),
        Strings.bigWave, Strings.bossWave, Strings.subtitle, Strings.rotate, Strings.start, Strings.go,
        Strings.toTitle, Strings.map, Strings.dayForest, Strings.nightForest, Strings.toMap, Strings.next,
        Strings.shop, Strings.pineconesGained(3), Strings.pinecones(3), Strings.totalStars(1, 30), Strings.newTag,
        Strings.meetTitle, Strings.gotIt, Strings.help, Strings.install, Strings.close, Strings.helpHowTo,
        Strings.helpFriends, Strings.helpMonsters, Strings.meetAt('1-2'), Strings.maxed, Strings.unlockAt('1-3'),
        Strings.shopHint, Strings.cleared, Strings.gameOver, Strings.paused, Strings.retry, Strings.resume,
        Strings.result(defeated: 3, hearts: 2), Strings.settings, Strings.language, Strings.soundFx, Strings.music,
        Strings.on, Strings.off, Strings.screen, Strings.windowed, Strings.fullscreen,
        for (final (a, b) in Strings.howTo) ...[a, b],
        for (final d in Difficulty.values) ...[Strings.difficultyName(d), Strings.difficultyLine(d)],
        for (final u in UnitType.values) ...[Strings.unitName(u), Strings.unitAbility(u), Strings.unitTip(u), Strings.newFriend(u), Strings.newFriendHint(u)],
        for (final m in MonsterType.values) ...[Strings.monsterName(m), Strings.monsterAbility(m), Strings.monsterTip(m), Strings.meetLine(m)],
        for (final u in Upgrade.values) ...[Strings.upgradeName(u), Strings.upgradeEffect(u)],
      ];

  test('영어 화면에는 한글이 없고, 한국어와 영어 글이 다르다 (책 소개는 한국어 화면에서만)', () {
    final hangul = RegExp(r'[가-힣]');
    Strings.lang = Lang.ko;
    final ko = allText();
    Strings.lang = Lang.en;
    final en = allText();
    expect(en.where(hangul.hasMatch), isEmpty);
    expect(ko.length, en.length);
    final same = [for (var i = 0; i < ko.length; i++) if (ko[i] == en[i] && hangul.hasMatch(ko[i])) ko[i]];
    expect(same, isEmpty);
    // Gaegu에 없는 기호를 쓰지 않는다
    expect(en.where((s) => RegExp('[’…·→]').hasMatch(s)), isEmpty);
  });

  test('언어·전체화면은 저장되고, 예전 저장(없음)은 기기 언어·창', () {
    final p = Progress(lang: Lang.en, fullscreen: true);
    final back = Progress.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
    expect(back.lang, Lang.en);
    expect(back.fullscreen, isTrue);
    final old = Progress.fromJson({'stars': {}});
    expect(old.lang, isNull);
    expect(old.fullscreen, isFalse);
  });

  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 300 && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(done(), isTrue);
  }

  final langs = <Lang>[];
  final screens = <bool>[];
  final progress = Progress();
  GameTester(() => MenuGame(
        progress: progress,
        onPlay: (_) {},
        sound: false,
        onLang: langs.add,
        onFullscreen: screens.add,
      )).testGameWidget(
    '메인 화면 설정: 언어·효과음·배경음악·화면 네 줄, 누르면 바로 바뀌고 진행에 남는다',
    verify: (game, tester) async {
      // GameTester의 setUp은 기다려 주지 않아 여기서 버튼이 붙을 때까지 기다린다
      await waitFor(tester, () => game.world.children.whereType<TitleScreen>().any((t) => t.children.whereType<PanelButton>().length >= 2));
      final title = game.world.children.whereType<TitleScreen>().single;
      final settingsButton = title.children.whereType<PanelButton>().singleWhere((b) => b.label == Strings.settings);
      await tapWorld(tester, settingsButton.position + settingsButton.size / 2);
      await waitFor(tester, () => game.world.children.whereType<SettingsPanel>().any((p) => p.isMounted));
      final panel = game.world.children.whereType<SettingsPanel>().single;
      expect(panel.rows.map((r) => r.label), [Strings.language, Strings.soundFx, Strings.music, Strings.screen]);
      for (final r in panel.rows) {
        for (final pill in r.pills) {
          expect(pill.absolutePosition.x + pill.size.x, lessThanOrEqualTo(1280 - 40));
        }
      }

      Future<void> pick(int row, int choice) async {
        final pill = panel.rows[row].pills[choice];
        await tapWorld(tester, pill.absolutePosition + pill.size / 2);
      }

      await pick(1, 1); // 효과음 끄기
      expect(progress.soundOn, isFalse);
      expect(game.sfx.muted, isTrue);
      await pick(2, 1); // 배경음악 끄기
      expect(progress.musicOn, isFalse);
      await pick(3, 1); // 전체화면
      expect(screens, [true]);
      await pick(0, 1); // English
      expect(langs, [Lang.en]);
      expect(panel.rows[0].selected(), 1);

      final close = panel.children.first.children.whereType<PanelButton>().single;
      await tapWorld(tester, close.absolutePosition + close.size / 2);
      await tester.pump();
      expect(panel.isMounted, isFalse);
    },
  );

  GameTester(() {
    Strings.lang = Lang.en;
    return MenuGame(progress: Progress(), onPlay: (_) {}, sound: false, onLang: (_) {});
  }).testGameWidget(
    '영어 메인 화면: 책 소개 띠가 없고, 화면 줄은 전체화면 함수가 있을 때만 (웹·Android는 없음)',
    verify: (game, tester) async {
      // GameTester의 setUp은 기다려 주지 않아 여기서 버튼이 붙을 때까지 기다린다
      await waitFor(tester, () => game.world.children.whereType<TitleScreen>().any((t) => t.children.whereType<PanelButton>().length >= 2));
      expect(game.world.descendants().whereType<BookBadge>(), isEmpty);
      game.openSettings();
      await tester.pump();
      await waitFor(tester, () => game.world.children.whereType<SettingsPanel>().any((p) => p.isMounted));
      final rows = game.world.children.whereType<SettingsPanel>().single.rows;
      expect(rows.map((r) => r.label), ['Language', 'Sound', 'Music']);
    },
  );

  final fullscreens = <bool>[];
  GameTester(() => ForestGame(nestAcorns: false, waves: false, sound: false, intro: false, onFullscreen: fullscreens.add)).testGameWidget(
    '판의 일시정지 창에 설정: 언어 줄은 없고, 효과음을 끄면 판 소리가 꺼진다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      game.togglePause();
      await tester.pump();
      final pause = game.world.children.whereType<CenterPanel>().last;
      final settings = pause.buttons.singleWhere((b) => b.label == Strings.settings);
      settings.onPressed();
      await waitFor(tester, () => game.world.children.whereType<SettingsPanel>().any((p) => p.isMounted));
      final panel = game.world.children.whereType<SettingsPanel>().single;
      expect(panel.rows.map((r) => r.label), [Strings.soundFx, Strings.music, Strings.screen]);
      panel.rows[0].pills[1].onPressed();
      expect(game.sfx.muted, isTrue);
      panel.rows[2].pills[1].onPressed();
      expect(fullscreens, [true]);
      expect(game.fullscreen, isTrue);
      expect(game.state, GameState.paused, reason: '설정을 열어도 일시정지 그대로');
    },
  );

}
