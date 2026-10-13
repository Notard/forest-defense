import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

/// 웹 효과음: 오디오 통로(AudioContext) **하나**에 소리를 미리 풀어 두고(AudioBuffer) 낼 때마다 가벼운 재생 노드만 만든다.
///
/// flame_audio(audioplayers)는 웹에서 소리를 낼 때마다 플레이어와 AudioContext를 새로 만들고 닫지 않아,
/// 한 스테이지에 통로가 5개에서 40개로 늘며 핸드폰에서 끊김이 생겼다 (16-1단계에서 측정).
class WebSfx {
  static web.AudioContext? _ctx;
  static final Map<String, web.AudioBuffer> _buffers = {};
  static Future<void>? _loading;

  static bool get available => true;

  /// 이름 → 에셋 키 ('assets/audio/pickup.wav'). 앱에서 한 번만 받는다 (판을 다시 해도 그대로 쓴다).
  static Future<void> load(Map<String, String> assets) => _loading ??= _load(assets);

  static Future<void> _load(Map<String, String> assets) async {
    final ctx = _ctx ??= web.AudioContext();
    await Future.wait([
      for (final MapEntry(key: name, value: key) in assets.entries)
        () async {
          try {
            final url = ui_web.assetManager.getAssetUrl(key);
            final response = await web.window.fetch(url.toJS).toDart;
            final data = await response.arrayBuffer().toDart;
            _buffers[name] = await ctx.decodeAudioData(data).toDart;
          } catch (_) {
            // 소리 하나가 없어도 게임은 돈다
          }
        }(),
    ]);
  }

  static void play(String name, double volume) {
    final ctx = _ctx;
    final buffer = _buffers[name];
    if (ctx == null || buffer == null) return;
    try {
      // 웹은 첫 누름 전엔 통로가 멈춰 있다: 누른 뒤 처음 소리를 낼 때 깨운다
      if (ctx.state == 'suspended') unawaited(ctx.resume().toDart.then<void>((_) {}, onError: (Object _) {}));
      final source = ctx.createBufferSource()..buffer = buffer;
      final gain = ctx.createGain()..gain.value = volume;
      source.connect(gain);
      gain.connect(ctx.destination);
      source.start();
    } catch (_) {}
  }
}
