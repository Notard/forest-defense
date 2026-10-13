import 'package:flame/extensions.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/forest_game.dart';
import 'package:forest_defense/game/hud/layout.dart';
import 'package:forest_defense/game/music.dart';
import 'package:forest_defense/game/progress.dart';
import 'package:forest_defense/game/stages.dart';
import 'package:forest_defense/menu/menu_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

/// 12-3단계 배경음악: 곡 고르기, 이어 가기, 멈춤·끝, 끄기와 저장.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('재생기', () {
    test('같은 곡은 다시 시작하지 않고, 다른 곡이면 바꾼다', () {
      final j = Jukebox(enabled: false);
      j.play(Track.title);
      j.play(Track.title);
      j.play(Track.day);
      expect(j.log, ['play title', 'play day']);
    });

    test('멈춤 → 이어 듣기, 판이 끝나면 멈춤', () {
      final j = Jukebox(enabled: false)..play(Track.night);
      j.pause();
      j.resume();
      j.stop();
      j.stop();
      expect(j.log, ['play night', 'pause', 'resume', 'stop']);
      expect(j.current, isNull);
    });

    test('꺼 둔 동안 바뀐 곡을 기억했다가 켜면 그 곡이 나온다', () {
      final j = Jukebox(enabled: false)..play(Track.title);
      j.muted = true;
      j.play(Track.boss);
      expect(j.log, ['play title', 'mute'], reason: '꺼져 있으면 재생하지 않는다');
      j.muted = false;
      expect(j.log, ['play title', 'mute', 'unmute', 'play boss']);
    });

    test('스테이지마다 곡: 낮·밤·보스', () {
      expect(Track.forStage(stageById('1-2')), Track.day);
      expect(Track.forStage(stageById('2-3')), Track.night);
      expect(Track.forStage(stageById('1-5')), Track.boss);
      expect(Track.forStage(stageById('2-5')), Track.boss);
      expect(Track.forStage(demoStage), Track.day);
    });
  });

  test('소리·음악 설정은 저장되고 다시 읽힌다 (예전 저장에는 없으니 켜짐)', () async {
    final p = Progress()
      ..soundOn = false
      ..musicOn = false;
    await p.save();
    final q = await Progress.load();
    expect(q.soundOn, isFalse);
    expect(q.musicOn, isFalse);
    expect(Progress.fromJson({'stars': {}, 'pinecones': 0}).musicOn, isTrue);
  });

  final music = Jukebox(enabled: false);
  final saved = <String>[];
  GameTester(() => ForestGame(
        stage: stageById('1-5'),
        skyAcorns: false,
        waves: false,
        sound: false,
        intro: false,
        music: music,
        onSettings: ({required sound, required music}) => saved.add('sound $sound, music $music'),
      )).testGameWidget(
    '판: 보스 곡 → 일시정지에 멈춤·이어 듣기 → 이기면 멈춤. 음악·소리 버튼은 앱에 저장을 맡긴다',
    setUp: waitForLoad,
    verify: (game, tester) async {
      expect(music.log.last, 'play boss');
      game.togglePause();
      game.togglePause();
      expect(music.log.sublist(music.log.length - 2), ['pause', 'resume']);

      await tapWorld(tester, HudLayout.music.center.toVector2());
      expect(music.muted, isTrue);
      await tapWorld(tester, HudLayout.sound.center.toVector2());
      expect(game.sfx.muted, isTrue);
      expect(saved, ['sound true, music false', 'sound false, music false']);

      music.muted = false;
      game.win();
      expect(music.log.last, 'stop');
    },
  );

  GameTester(() => ForestGame(skyAcorns: false, waves: false, sound: false, intro: false, muted: true)).testGameWidget(
    '효과음을 꺼 두었으면 새 판도 꺼진 채 시작한다 (예전에는 다시 하기마다 켜졌다)',
    setUp: waitForLoad,
    verify: (game, tester) async => expect(game.sfx.muted, isTrue),
  );

  final menuMusic = Jukebox(enabled: false);
  GameTester(() => MenuGame(progress: Progress(), onPlay: (_) {}, sound: false, music: menuMusic)).testGameWidget(
    '메뉴: 메인 화면에서 숲속 아침, 지도·상점으로 가도 이어진다',
    setUp: (game, tester) async {
      for (var i = 0; i < 100 && !game.isLoaded; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    },
    verify: (game, tester) async {
      await tester.runAsync(() async {
        await game.show(MenuPage.map);
        await game.show(MenuPage.shop);
      });
      expect(menuMusic.log, ['play title']);
    },
  );
}
