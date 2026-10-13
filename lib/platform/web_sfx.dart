/// 웹 효과음 엔진 (16-1단계). 웹에서만 실제로 동작하고, 그 밖에서는 [available]이 false라 flame_audio를 쓴다.
library;

export 'web_sfx_stub.dart' if (dart.library.js_interop) 'web_sfx_web.dart';
