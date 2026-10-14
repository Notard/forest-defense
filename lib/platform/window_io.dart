import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// Windows exe에서만 (Android는 늘 전체화면). 테스트(Windows에서 돌아도 창 플러그인이 없다)에서는 false.
bool get canFullscreen => Platform.isWindows && !_inTest;

bool get _inTest => Platform.environment.containsKey('FLUTTER_TEST');

/// 앱을 시작할 때: 창 제목을 지금 언어로, 저장된 대로 전체화면.
Future<void> setupWindow({required bool fullscreen, required String title}) async {
  if (!canFullscreen) return;
  try {
    await windowManager.ensureInitialized();
    await windowManager.setTitle(title);
    if (fullscreen) await windowManager.setFullScreen(true);
  } catch (e) {
    debugPrint('창 설정 실패: $e');
  }
}

Future<void> setFullscreen(bool on) async {
  if (!canFullscreen) return;
  try {
    await windowManager.setFullScreen(on);
  } catch (e) {
    debugPrint('전체화면 바꾸기 실패: $e');
  }
}

Future<bool> isFullscreen() async {
  if (!canFullscreen) return false;
  try {
    return await windowManager.isFullScreen();
  } catch (_) {
    return false;
  }
}

Future<void> setTitle(String title) async {
  if (!canFullscreen) return;
  try {
    await windowManager.setTitle(title);
  } catch (_) {}
}
