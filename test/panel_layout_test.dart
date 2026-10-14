import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/config.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/hud/layout.dart';
import 'package:forest_defense/game/hud/panel.dart';
import 'package:forest_defense/game/progress.dart';
import 'package:forest_defense/game/stages.dart';
import 'package:forest_defense/game/units.dart';

import 'support.dart';

/// 가운데 판 배치: 글줄이 버튼과 겹치지 않고, 버튼 글자가 버튼 안에 들어가고, 판이 화면 안에 있다.
/// (사용자 제보: 1-1 결과 판에서 "새 친구: 거북이!"가 버튼에 가려지고 "다음 스테이지"가 버튼 밖으로 나왔다)
void main() {
  Future<CenterPanel> shown(ForestGame game, WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 20; i++) {
        game.update(1 / 60);
        await Future<void>.delayed(Duration.zero);
      }
    });
    return game.world.children.whereType<CenterPanel>().last;
  }

  void checkLayout(CenterPanel panel) {
    final box = panel.children.whereType<PositionComponent>().single;
    final texts = box.children.whereType<TextComponent>().toList();
    final buttons = box.children.whereType<PanelButton>().toList();
    expect(buttons, isNotEmpty);
    final lowestText = texts.map((t) => t.position.y + t.size.y / 2).reduce((a, b) => a > b ? a : b);
    for (final b in buttons) {
      expect(b.position.y, greaterThanOrEqualTo(lowestText + 8), reason: '${b.label} 버튼이 글줄을 가린다');
      expect(PanelButton.labelPaint.getLineMetrics(b.label).width, lessThanOrEqualTo(b.size.x - 24), reason: '${b.label} 글자가 버튼 밖으로 나온다');
      expect(b.position.x, greaterThanOrEqualTo(24));
      expect(b.position.x + b.size.x, lessThanOrEqualTo(box.size.x - 24));
      expect(b.position.y + b.size.y, lessThanOrEqualTo(box.size.y - 20));
    }
    for (final t in texts) {
      expect(t.size.x, lessThanOrEqualTo(box.size.x - 40), reason: '"${t.text}"가 판보다 넓다');
    }
    for (var i = 0; i + 1 < buttons.length; i++) {
      expect(buttons[i].position.x + buttons[i].size.x, lessThan(buttons[i + 1].position.x), reason: '버튼끼리 겹친다');
    }
    expect(box.size.x, lessThanOrEqualTo(GameConfig.width - 40));
    expect(box.size.y, lessThanOrEqualTo(GameConfig.height - 40));
  }

  // 결과 판에 들어갈 수 있는 것을 모두 넣은 경우: 별 3 + 결과·솔방울·새 친구 + 버튼 셋
  GameTester(() => ForestGame(
        stage: stageById('1-1'),
        nestAcorns: false,
        waves: false,
        sound: false,
        intro: false,
        onFinish: ({required won, required lostHeart, required lostUnit}) =>
            const Reward(stars: 3, newStars: 3, pinecones: 30, unlocked: UnitType.turtle),
      )).testGameWidget(
    '클리어 판 (가장 긴 경우)',
    setUp: waitForLoad,
    verify: (game, tester) async {
      game.win();
      final panel = await shown(game, tester);
      expect(panel.lines, hasLength(3));
      expect(panel.buttons, hasLength(3));
      expect(panel.picture, isNotNull, reason: '새 친구 그림 (14단계)');
      final pic = panel.picture!;
      final box = panel.children.whereType<PositionComponent>().single;
      final firstLine = box.children.whereType<TextComponent>().where((t) => t.text == panel.lines.first).single;
      expect(pic.position.y, lessThanOrEqualTo(firstLine.toRect().top), reason: '그림 발이 글줄 위에 (프레임 아래 빈 곳은 투명)');
      expect(pic.position.y - 110, greaterThan(box.children.whereType<StarRow>().single.toRect().bottom - 6), reason: '머리가 별을 가리지 않는다');
      checkLayout(panel);
    },
  );

  GameTester(testGame).testGameWidget(
    '게임오버 판',
    setUp: waitForLoad,
    verify: (game, tester) async {
      game.lose();
      checkLayout(await shown(game, tester));
    },
  );

  GameTester(testGame).testGameWidget(
    '일시정지 판',
    setUp: waitForLoad,
    verify: (game, tester) async {
      game.togglePause();
      checkLayout(await shown(game, tester));
    },
  );

  GameTester(testGame).testGameWidget(
    '클리어 판 (데모: 별·다음 스테이지 없음)',
    setUp: waitForLoad,
    verify: (game, tester) async {
      game.win();
      checkLayout(await shown(game, tester));
    },
  );

  GameTester(testGame).testGameWidget(
    '같은 프레임에 일시정지했다 풀어도 판이 남지 않고, 그 뒤 누름이 모두 들어간다 (12-3단계에서 찾은 버그)',
    setUp: waitForLoad,
    verify: (game, tester) async {
      game.togglePause();
      game.togglePause();
      await tester.runAsync(() async {
        game.update(0);
        await Future<void>.delayed(Duration.zero);
      });
      expect(game.world.children.whereType<CenterPanel>(), isEmpty);
      final sound = HudLayout.sound.center;
      final states = <bool>[];
      for (var i = 0; i < 3; i++) {
        await tapWorld(tester, Vector2(sound.dx, sound.dy));
        states.add(game.sfx.muted);
      }
      expect(states, [true, false, true]);
    },
  );
}
