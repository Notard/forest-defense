/// 웹: 전체화면 설정을 두지 않는다 (브라우저가 정한다).
bool get canFullscreen => false;

Future<void> setupWindow({required bool fullscreen, required String title}) async {}

Future<void> setFullscreen(bool on) async {}

Future<bool> isFullscreen() async => false;

Future<void> setTitle(String title) async {}
