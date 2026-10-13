import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/components/log.dart';
import 'package:forest_defense/game/components/monster.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/hud/layout.dart';
import 'package:forest_defense/game/hud/panel.dart';
import 'package:forest_defense/game/monsters.dart';
import 'package:forest_defense/game/strings.dart';
import 'package:forest_defense/game/waves.dart';

import 'support.dart';

/// 통나무·게임오버·클리어·일시정지 (plan.md 7단계).
void main() {
  Future<Monster> spawn(ForestGame game, WidgetTester tester, MonsterType type, int row, double x) async {
    late Monster m;
    await tester.runAsync(() async {
      m = await game.addMonster(type, row: row, x: x);
      game.update(0);
    });
    return m;
  }

  void run(ForestGame game, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      game.update(1 / 60);
    }
  }

  /// 프레임 사이에 실제 시간을 흘린다. 쓰러진 몬스터 자리에 생기는 연기가 그림을 읽어야
  /// Flame이 그 뒤의 붙이기·떼기(통나무 사라짐 등)를 이어서 처리한다 (WORKLOG 7).
  Future<void> runReal(ForestGame game, WidgetTester tester, double seconds) => tester.runAsync(() async {
        for (var t = 0.0; t < seconds; t += 1 / 60) {
          game.update(1 / 60);
          await Future<void>.delayed(Duration.zero);
        }
      });

  Future<void> settle(ForestGame game, WidgetTester tester) => tester.runAsync(() async {
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          game.update(1 / 60);
        }
      });

  String? panelTitle(ForestGame game) {
    final panels = game.world.children.whereType<CenterPanel>();
    return panels.isEmpty ? null : panels.single.title;
  }

  GameTester(testGame).testGameWidget(
    '레인마다 통나무가 하나씩 있고, 몬스터가 닿으면 굴러가 그 레인 몬스터만 모두 쓰러뜨린다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      expect(game.logs.keys, unorderedEquals([0, 1, 2, 3, 4]));
      final a = await spawn(game, tester, MonsterType.slime, 2, RollingLog.triggerX + 30);
      final b = await spawn(game, tester, MonsterType.helmetSlime, 2, 700);
      final other = await spawn(game, tester, MonsterType.slime, 3, 900); // 자기 레인 통나무까지 멀다
      final log = game.logs[2]!;
      run(game, 2.0); // 30px 걸어 통나무에 닿음 (약 1.5초)
      expect(log.rolling, isTrue);
      expect(game.logs.containsKey(2), isFalse);
      await runReal(game, tester, 2.5); // 520 px/초로 화면 끝까지 약 2.3초
      expect(a.alive, isFalse);
      expect(b.alive, isFalse, reason: '투구도 소용없다');
      expect(log.isMounted, isFalse, reason: '화면 밖으로 나가면 사라진다');
      expect(other.alive, isTrue, reason: '다른 레인은 그대로');
      expect(game.logs.containsKey(3), isTrue);
      expect(game.state, GameState.playing);
    },
  );

  GameTester(testGame).testGameWidget(
    '통나무를 쓴 레인에서 몬스터가 둥지에 닿으면 게임오버 판이 뜨고 시계가 멈춘다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      game.logs[1]!.roll();
      run(game, 2);
      final m = await spawn(game, tester, MonsterType.wisp, 1, Monster.reachedHomeX + 20);
      run(game, 1.0);
      expect(game.state, GameState.lost);
      await settle(game, tester);
      expect(panelTitle(game), Strings.gameOver);
      final x = m.position.x;
      run(game, 2.0);
      expect(m.position.x, x, reason: '게임오버 뒤에는 움직이지 않는다');
    },
  );

  GameTester(() => ForestGame(skyAcorns: false, waves: true, startWave: 5, sound: false, intro: false)).testGameWidget(
    '마지막 웨이브까지 모두 쓰러뜨리면 클리어 판이 뜬다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      // 웨이브 5가 다 나올 때까지, 나오는 대로 쓰러뜨린다
      final until = WaveDirector.firstDelay + stageWaves.last.gap * stageWaves.last.monsters.length + 3;
      await tester.runAsync(() async {
        for (var t = 0.0; t < until; t += 1 / 30) {
          game.update(1 / 30);
          for (final m in game.monsters.toList()) {
            m.takeDamage(10000);
          }
          await Future<void>.delayed(Duration.zero);
        }
      });
      expect(game.waveRunner!.director.allSpawned, isTrue);
      expect(game.state, GameState.won);
      await settle(game, tester);
      expect(panelTitle(game), Strings.cleared);
      expect(game.defeated, stageWaves.last.monsters.length);
    },
  );

  GameTester(testGame).testGameWidget(
    '일시정지 버튼을 누르면 시계가 멈추고, 계속하기로 이어 한다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      final m = await spawn(game, tester, MonsterType.slime, 0, 900);
      final pause = HudLayout.pause.center;
      await tapWorld(tester, Vector2(pause.dx, pause.dy));
      expect(game.state, GameState.paused);
      await settle(game, tester);
      expect(panelTitle(game), Strings.paused);
      final x = m.position.x;
      run(game, 3);
      expect(m.position.x, x);
      game.togglePause(); // 계속하기 버튼과 같은 동작
      await settle(game, tester);
      expect(panelTitle(game), isNull);
      run(game, 1);
      expect(m.position.x, lessThan(x));
    },
  );

}

