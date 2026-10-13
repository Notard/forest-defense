import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/hud/panel.dart';
import 'package:forest_defense/game/hud/title.dart';
import 'package:forest_defense/game/monsters.dart';
import 'package:forest_defense/game/sfx.dart';
import 'package:forest_defense/game/strings.dart';

import 'support.dart';

/// 메인 화면과 카운트다운 (7-2단계).
void main() {
  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 300 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
    }
    expect(done(), isTrue);
  }

  /// 멈춘 동안에도 메인 화면·카운트다운은 실제 dt로 움직인다.
  void run(ForestGame game, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      game.update(1 / 60);
    }
  }

  GameTester(() => ForestGame(skyAcorns: false, waves: false, sound: false)).testGameWidget(
    '메인 화면 → 게임 시작 → 3 · 2 · 1 · 시작! → 게임',
    setUp: (game, tester) => waitFor(tester, () => game.isLoaded && game.world.children.whereType<TitleScreen>().any((t) => t.isMounted)),
    verify: (game, tester) async {
      expect(game.state, GameState.title);
      // 메인 화면 동안에는 게임이 멈춰 있다
      late final m = game.monsters;
      await tester.runAsync(() async {
        await game.addMonster(MonsterType.slime, row: 2, x: 900);
        game.update(0);
      });
      final x = m.single.position.x;
      run(game, 2);
      expect(m.single.position.x, x);

      await tapWorld(tester, Vector2(640, 438)); // 게임 시작
      expect(game.state, GameState.countdown);
      await tester.pump();
      game.update(0);
      expect(game.world.children.whereType<TitleScreen>(), isEmpty);

      run(game, Countdown.total - 0.2);
      expect(game.state, GameState.countdown, reason: '카운트다운 중에도 멈춰 있다');
      expect(m.single.position.x, x);
      expect(game.sfx.played, [Sfx.tick, Sfx.tick, Sfx.tick, Sfx.go]);

      run(game, 0.4);
      expect(game.state, GameState.playing);
      run(game, 1);
      expect(m.single.position.x, lessThan(x), reason: '시작! 뒤에는 움직인다');
    },
  );

  GameTester(() => ForestGame(skyAcorns: false, waves: false, sound: false, showTitle: false)).testGameWidget(
    '다시 하기로 만든 게임은 메인 화면 없이 카운트다운부터',
    setUp: (game, tester) => waitFor(tester, () => game.isLoaded),
    verify: (game, tester) async {
      expect(game.state, GameState.countdown);
      expect(game.world.children.whereType<TitleScreen>(), isEmpty);
      run(game, Countdown.total + 0.1);
      expect(game.state, GameState.playing);
    },
  );

  test('판의 다시 하기는 카운트다운부터, 처음으로는 메인 화면부터 새 게임을 요청한다', () {
    final asked = <bool>[];
    final game = ForestGame(sound: false, intro: false, onRestart: ({required bool title}) => asked.add(title));
    PanelButton(Strings.retry, game.restart).onPressed();
    toTitleButton(game).onPressed();
    expect(asked, [false, true]);
  });
}
