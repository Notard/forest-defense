import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/hud/title.dart';
import 'package:forest_defense/game/monsters.dart';
import 'package:forest_defense/game/progress.dart';
import 'package:forest_defense/game/sfx.dart';
import 'package:forest_defense/game/stages.dart';
import 'package:forest_defense/menu/menu_game.dart';

import 'support.dart';

/// 메인 화면·숲 지도(메뉴 게임)와 판의 카운트다운 (7-2단계, 9단계).
void main() {
  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 300 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
    }
    expect(done(), isTrue);
  }

  /// 멈춘 동안에도 카운트다운은 실제 dt로 움직인다.
  void run(ForestGame game, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      game.update(1 / 60);
    }
  }

  final played = <StageDef>[];
  MenuGame menu() => MenuGame(progress: Progress(), onPlay: played.add, sound: false);

  GameTester(menu).testGameWidget(
    '메인 화면 → 게임 시작 → 숲 지도',
    setUp: (game, tester) => waitFor(tester, () => game.isLoaded && game.world.children.whereType<TitleScreen>().any((t) => t.isMounted)),
    verify: (game, tester) async {
      expect(game.page, MenuPage.title);
      await tapWorld(tester, Vector2(640, 438)); // 게임 시작
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      });
      await waitFor(tester, () => game.world.children.whereType<MapScreen>().any((m) => m.isMounted));
      expect(game.page, MenuPage.map);
    },
  );

  GameTester(() => MenuGame(progress: Progress(), onPlay: played.add, startPage: MenuPage.map, sound: false)).testGameWidget(
    '지도에서 열린 스테이지(1-1)를 누르면 시작하고, 잠긴 스테이지(1-2)는 시작하지 않는다',
    setUp: (game, tester) => waitFor(tester, () => game.world.children.whereType<MapScreen>().any((m) => m.isMounted)),
    verify: (game, tester) async {
      played.clear();
      Vector2 spot(int i) => Vector2(MapScreen.spots[i].dx, MapScreen.spots[i].dy);
      await tapWorld(tester, spot(1)); // 1-2 (잠김)
      expect(played, isEmpty);
      await tapWorld(tester, spot(0)); // 1-1
      expect(played.single.id, '1-1');
    },
  );

  GameTester(() => ForestGame(skyAcorns: false, waves: false, sound: false)).testGameWidget(
    '판은 3 · 2 · 1 · 시작! 뒤에 시작하고, 그동안은 멈춰 있다',
    setUp: (game, tester) => waitFor(tester, () => game.isLoaded),
    verify: (game, tester) async {
      expect(game.state, GameState.countdown);
      await tester.runAsync(() async {
        await game.addMonster(MonsterType.slime, row: 2, x: 900);
        game.update(0);
      });
      final m = game.monsters.single;
      final x = m.position.x;
      run(game, Countdown.total - 0.2);
      expect(game.state, GameState.countdown);
      expect(m.position.x, x);
      expect(game.sfx.played, [Sfx.tick, Sfx.tick, Sfx.tick, Sfx.go]);
      run(game, 0.4);
      expect(game.state, GameState.playing);
      run(game, 1);
      expect(m.position.x, lessThan(x));
    },
  );

  test('판의 버튼은 앱에 다시 하기·지도로·다음 스테이지를 알린다', () {
    final asked = <GameExit>[];
    final game = ForestGame(sound: false, intro: false, onExit: asked.add);
    game.restart();
    game.exit(GameExit.map);
    game.exit(GameExit.next);
    expect(asked, [GameExit.retry, GameExit.map, GameExit.next]);
  });
}
