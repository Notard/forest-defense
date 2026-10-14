import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/grid.dart';
import 'package:forest_defense/game/hud/layout.dart';
import 'package:forest_defense/game/strings.dart';
import 'package:forest_defense/game/units.dart';
import 'package:forest_defense/portrait_guard.dart';

import 'support.dart';

/// 15단계: 화면 비율이 달라도 게임(1280 × 720)이 가운데에 맞고 누른 자리가 맞는지, 세로 화면 안내.
/// (다른 테스트는 모두 800 × 600 = 4:3 화면에서 돈다: 위아래 레터박스)
void main() {
  /// [screen] 크기 화면에서 게임 좌표 → 화면 좌표 (짧은 쪽에 맞추고 남는 쪽은 가운데 정렬).
  Offset onScreen(Size screen, Vector2 world) {
    final s = (screen.width / 1280).clamp(0.0, screen.height / 720);
    final ox = (screen.width - 1280 * s) / 2, oy = (screen.height - 720 * s) / 2;
    return Offset(ox + world.x * s, oy + world.y * s);
  }

  for (final (name, size) in [('폰 가로 19.5:9 (좌우 여백)', const Size(844, 390)), ('16:9 꼭 맞음', const Size(1280, 720))]) {
    GameTester(testGame).testGameWidget(
      '$name: 카드를 누르고 칸을 누르면 그 칸에 놓인다',
      setUp: (game, tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pump();
        await waitForLoad(game, tester);
      },
      verify: (game, tester) async {
        Future<void> tap(Vector2 world) async {
          await tester.tapAt(onScreen(size, world));
          await tester.pump(const Duration(milliseconds: 100));
        }

        final card = HudLayout.card(0).center;
        await tap(Vector2(card.dx, card.dy));
        expect(game.selectedUnit, UnitType.squirrel);
        const cell = (row: 4, col: 7); // 오른쪽 아래 끝 칸: 배율이 틀리면 가장 크게 어긋난다
        await tester.runAsync(() async {
          await tester.tapAt(onScreen(size, Grid.center(cell)));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump(const Duration(milliseconds: 100));
        expect(game.garden.unitAt(cell), UnitType.squirrel);
      },
    );
  }

  testWidgets('세로 화면이면 "가로로 돌려 주세요"를 덮고, 세로가 될 때마다 알린다', (tester) async {
    var calls = 0;
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    Future<void> show(Size s) async {
      tester.view.physicalSize = s;
      await tester.pumpWidget(MaterialApp(home: PortraitGuard(onPortrait: () => calls++, child: const ColoredBox(color: Colors.green))));
      await tester.pump();
    }

    await show(const Size(390, 844));
    expect(find.text(Strings.rotate), findsOneWidget);
    expect(calls, 1);
    await show(const Size(844, 390));
    expect(find.text(Strings.rotate), findsNothing);
    expect(calls, 1);
    await show(const Size(390, 844));
    expect(calls, 2);
    expect(PortraitGuard.isPortrait(const Size(800, 600)), isFalse);
  });
}
