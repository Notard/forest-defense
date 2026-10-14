import 'package:flame/extensions.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/config.dart';
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

/// 12-4단계 도움말: 메인 화면 버튼, 세 쪽, 닫기, 글이 판·카드 안에 들어가는지.
void main() {
  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    // 그림 읽기는 실제 시간이 흘러야 끝난다
    for (var i = 0; i < 300 && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(done(), isTrue);
  }

  HelpPanel? panelOf(MenuGame g) => g.world.children.whereType<HelpPanel>().firstOrNull;

  final played = <StageDef>[];
  GameTester(() => MenuGame(progress: Progress(), onPlay: played.add, sound: false)).testGameWidget(
    '메인 화면 도움말 버튼 → 세 쪽 → 닫기. 떠 있는 동안 뒤의 게임 시작은 눌리지 않는다',
    verify: (game, tester) async {
      // 메인 화면은 캐릭터 그림 7종을 읽은 뒤에 버튼을 붙인다
      await waitFor(tester, () => game.world.children.whereType<TitleScreen>().any((t) => t.children.whereType<PanelButton>().isNotEmpty));
      // 16-2단계부터 도움말 왼쪽에 설정 버튼이 있다
      final button = game.world.children.whereType<TitleScreen>().single.children.whereType<PanelButton>().singleWhere((b) => b.label == Strings.help);
      expect(button.label, Strings.help);
      expect(button.position.x + button.size.x, lessThanOrEqualTo(GameConfig.width - 20));
      await tapWorld(tester, button.position + button.size / 2);
      await waitFor(tester, () => panelOf(game)?.isMounted ?? false);
      final panel = panelOf(game)!;
      expect(panel.page, HelpPage.howTo);

      // 판이 떠 있으면 게임 시작(가운데)을 눌러도 지도로 가지 않는다
      await tapWorld(tester, Vector2(640, 438));
      expect(game.page, MenuPage.title);

      await tapWorld(tester, HelpPanel.tabRect(1).center.toVector2());
      await waitFor(tester, () => panel.page == HelpPage.friends);
      // 카드 일곱 장은 그림을 기다리지 않고 바로 붙고, 그림은 뒤이어 채워진다
      List<HelpCard> cards() => panel.children.expand((c) => c.children).expand((c) => c.children).whereType<HelpCard>().toList();
      await waitFor(tester, () => cards().length == UnitType.values.length);
      await waitFor(tester, () => cards().every((c) => c.hasPortrait));
      await tapWorld(tester, HelpPanel.tabRect(2).center.toVector2());
      await waitFor(tester, () => panel.page == HelpPage.monsters);

      final close = panel.closeButton;
      await tapWorld(tester, close.absolutePosition + close.size / 2);
      await waitFor(tester, () => panelOf(game) == null);
      expect(played, isEmpty);
    },
  );

  test('친구 쪽: 처음엔 다람쥐·여우만 보이고 나머지는 그림자 + 만나는 스테이지', () {
    final page = CardPage.friends(Progress());
    final shown = page.entries.where((e) => !e.hidden).map((e) => e.name);
    expect(shown, [Strings.unitName(UnitType.squirrel), Strings.unitName(UnitType.fox)]);
    final hedgehog = page.entries[UnitType.hedgehog.index];
    expect(hedgehog.hidden, isTrue);
    expect(hedgehog.name, Strings.unknown);
    expect(hedgehog.line, Strings.meetAt('1-2'));
    expect(page.entries, hasLength(UnitType.values.length));
  });

  test('몬스터 쪽: 몬스터 종류마다 한 장, 같은 그림을 쓰는 작은 버섯은 작게 (사용자 제보: 둘이 똑같아 보였다)', () {
    final entries = CardPage.monsters().entries;
    expect(entries, hasLength(MonsterType.values.length));
    final big = entries[MonsterType.mushroom.index], small = entries[MonsterType.miniMushroom.index];
    expect(big.scale, 1);
    expect(small.scale, closeTo(MonsterType.miniMushroom.displayHeight / MonsterType.mushroom.displayHeight, 1e-9));
    expect(entries[MonsterType.bossSlime.index].scale, 1);
  });

  test('글이 판·카드 안에 들어간다 (테스트 글꼴은 Gaegu보다 넓어 넉넉한 기준)', () {
    for (final (title, line) in Strings.howTo) {
      for (final (paint, text) in [(HowToPage.titlePaint, title), (HowToPage.linePaint, line)]) {
        expect(HowToPage.textX + paint.getLineMetrics(text).width, lessThanOrEqualTo(HelpPanel.content.width), reason: text);
      }
    }
    final names = [...UnitType.values.map(Strings.unitName), ...MonsterType.values.map(Strings.monsterName), Strings.unknown];
    final lines = [
      ...UnitType.values.map(Strings.unitAbility),
      ...MonsterType.values.map(Strings.monsterAbility),
      for (final s in stages) Strings.meetAt(s.id),
    ];
    for (final n in names) {
      expect(HelpCard.namePaint.getLineMetrics(n).width, lessThanOrEqualTo(CardPage.cardW - 24), reason: n);
    }
    for (final l in lines) {
      expect(HelpCard.linePaint.getLineMetrics(l).width, lessThanOrEqualTo(CardPage.cardW - 16), reason: l);
    }
    // 카드 두 줄이 쪽 높이 안에, 판이 화면 안에
    expect(2 * CardPage.cardH + CardPage.gapY, lessThanOrEqualTo(HelpPanel.content.height));
    expect(HelpPanel.content.bottom, lessThan(HelpPanel.board.bottom - 92));
    expect(HelpPanel.board.right, lessThanOrEqualTo(GameConfig.width));
    expect(Strings.howTo.length * HowToPage.rowHeight, lessThanOrEqualTo(HelpPanel.content.height));
  });
}
