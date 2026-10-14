import 'dart:convert';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/hud/settings_panel.dart';
import 'package:forest_defense/game/hud/title.dart';
import 'package:forest_defense/game/hud/panel.dart';
import 'package:forest_defense/game/progress.dart';
import 'package:forest_defense/game/strings.dart';
import 'package:forest_defense/game/telemetry.dart';
import 'package:forest_defense/game/units.dart';
import 'package:forest_defense/menu/menu_game.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support.dart';

/// 16-4단계: 플레이 기록을 구글 시트로.
void main() {
  test('기기 번호는 16자리 16진수, 매번 다르다', () {
    final a = Telemetry.newPlayerId(), b = Telemetry.newPlayerId();
    expect(a, matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(a, isNot(b));
  });

  test('보내도 될 때만 text/plain JSON 한 줄을 POST한다 (끄면 보내지 않음, 실패해도 게임은 그대로)', () async {
    final posts = <http.Request>[];
    var allowed = true;
    final t = Telemetry(
      url: 'https://example.test/exec',
      playerId: 'abc',
      allowed: () => allowed,
      lang: () => 'ko',
      client: MockClient((r) async {
        posts.add(r);
        return http.Response('ok', 200);
      }),
    );
    await t.send('end', {'stage': '1-2', 'result': 'won', 'sec': 95});
    expect(posts, hasLength(1));
    expect(posts.single.headers['Content-Type'], startsWith('text/plain'));
    final row = jsonDecode(posts.single.body) as Map<String, dynamic>;
    expect(row, containsPair('event', 'end'));
    expect(row, containsPair('id', 'abc'));
    expect(row, containsPair('stage', '1-2'));
    expect(row, containsPair('v', appVersion));
    expect(row['plat'], isNotEmpty);
    expect(row.keys, isNot(contains('name')));

    allowed = false;
    await t.send('open');
    expect(posts, hasLength(1), reason: '끄면 보내지 않는다');
    expect(t.recent.last['event'], 'open', reason: '기록은 남긴다 (디버그용)');

    allowed = true;
    final broken = Telemetry(url: 'https://example.test/exec', playerId: 'x', allowed: () => true, lang: () => 'en',
        client: MockClient((_) async => throw Exception('offline')));
    await broken.send('open'); // 던지지 않는다
    expect(Telemetry(playerId: 'x', allowed: () => true, lang: () => 'ko', url: '').active, isFalse, reason: '주소가 비면 꺼짐');
  });

  test('기기 번호와 "기록 보내기"는 저장된다 (예전 저장은 켜짐)', () {
    final p = Progress(playerId: '00ff', statsOn: false);
    final back = Progress.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
    expect(back.playerId, '00ff');
    expect(back.statsOn, isFalse);
    expect(Progress.fromJson({'stars': {}}).statsOn, isTrue);
  });

  GameTester(testGame).testGameWidget(
    '판 요약: 스테이지·난이도·실제로 돈 시간·놓은 친구·레벨업',
    setUp: waitForLoad,
    verify: (game, tester) async {
      game.garden.acorns = 1000;
      await tester.runAsync(() async {
        for (final cell in [(row: 1, col: 1), (row: 2, col: 1)]) {
          game.garden.tick(60); // 쿨다운 끝내기
          game.selectCard(UnitType.fox);
          await game.onCellTapped(cell);
        }
      });
      game.levelUp(game.unitComponents[(row: 1, col: 1)]!);
      for (var i = 0; i < 120; i++) {
        game.update(1 / 60);
      }
      final s = game.playSummary();
      expect(s['stage'], game.stage.id);
      expect(s['diff'], 'normal');
      expect(s['sec'], 2);
      expect(s['placed'], 'fox:2');
      expect(s['levelups'], 1);
      expect(s['hearts'], 3);
      expect(game.finished, isFalse);
    },
  );

  final links = <String>[];
  final progress = Progress();
  GameTester(() => MenuGame(progress: progress, onPlay: (_) {}, sound: false, openLink: (u) async {
        links.add(u);
        return true;
      })).testGameWidget(
    '설정 창의 "기록 보내기"를 끄면 진행에 남고, "개인정보"는 처리방침을 연다',
    verify: (game, tester) async {
      for (var i = 0; i < 300 && !game.world.children.whereType<TitleScreen>().any((t) => t.children.whereType<PanelButton>().length >= 2); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
      game.openSettings();
      for (var i = 0; i < 20 && !game.world.children.whereType<SettingsPanel>().any((p) => p.isMounted); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
      final panel = game.world.children.whereType<SettingsPanel>().single;
      final stats = panel.rows.singleWhere((r) => r.label == Strings.sendStats);
      expect(stats.selected(), 0);
      stats.pills[1].onPressed();
      expect(progress.statsOn, isFalse);
      final privacy = panel.children.first.children.whereType<PanelButton>().singleWhere((b) => b.label == Strings.privacy);
      privacy.onPressed();
      expect(links, [privacyUrl]);
    },
  );
}
