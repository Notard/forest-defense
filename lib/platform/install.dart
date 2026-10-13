/// "앱으로 설치" (웹 PWA, 16단계). 웹에서만 실제로 동작하고, Windows·Android·테스트에서는 언제나 설치할 수 없음.
library;

export 'install_stub.dart' if (dart.library.js_interop) 'install_web.dart';
