import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/hud/title.dart';
import 'package:forest_defense/platform/install.dart' as install;

/// 16단계 "앱으로 설치": 브라우저가 설치를 제안할 때만 버튼이 보인다.
void main() {
  test('웹이 아닌 곳(테스트·Windows·Android)에서는 설치할 수 없다', () async {
    expect(install.canInstall(), isFalse);
    expect(await install.promptInstall(), isFalse);
  });

  testWithFlameGame('제안이 오면 나타나고, 사라지면 숨는다 (0.5초마다 확인)', (game) async {
    var can = false;
    final button = InstallButton(canInstall: () => can, prompt: () async => true);
    await game.ensureAdd(button);
    game.update(0.6);
    expect(button.shown, isFalse);
    can = true;
    game.update(0.6);
    await game.ready();
    expect(button.shown, isTrue);
    can = false;
    game.update(0.6);
    await game.ready();
    expect(button.shown, isFalse);
  });
}
