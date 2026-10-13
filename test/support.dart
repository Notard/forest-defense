import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/forest_game.dart';

/// 위젯 테스트 화면은 800 × 600 (4:3)이라 위아래 레터박스가 생긴다.
/// 1280 × 720 → 배율 0.625, 그려지는 높이 450, 위쪽 여백 75.
Offset toScreen(Vector2 world) => Offset(world.x * 0.625, 75 + world.y * 0.625);

/// 테스트용 게임: 하늘 도토리를 끈다 (무작위라 결과가 흔들린다).
ForestGame testGame() => ForestGame(skyAcorns: false);

/// 그림을 실제로 읽어 들이는 동안(가짜 시계가 아닌 실제 시간) 필드와 HUD가 붙을 때까지 기다린다.
Future<void> waitForLoad(ForestGame game, WidgetTester tester) async {
  bool ready() => game.isLoaded && game.field.isMounted && game.hud.isMounted && game.hud.cards.every((c) => c.isMounted);
  for (var i = 0; i < 300 && !ready(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await tester.pump();
  }
  expect(game.hud.isMounted, isTrue);
}

/// 화면을 누르고 탭 인식기 타이머(40ms)가 끝날 때까지 시간을 흘린다.
Future<void> tapWorld(WidgetTester tester, Vector2 world) async {
  await tester.tapAt(toScreen(world));
  await tester.pump(const Duration(milliseconds: 100));
}
