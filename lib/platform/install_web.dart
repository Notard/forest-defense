import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// 브라우저가 설치를 제안했는지 (web/index.html이 beforeinstallprompt를 받아 둔다).
bool canInstall() {
  final f = globalContext['forestCanInstall'];
  if (f == null || !f.isA<JSFunction>()) return false;
  final r = (f as JSFunction).callAsFunction();
  return r != null && r.isA<JSBoolean>() && (r as JSBoolean).toDart;
}

/// 설치 창을 띄운다. 사용자가 설치를 고르면 true.
Future<bool> promptInstall() async {
  final f = globalContext['forestInstall'];
  if (f == null || !f.isA<JSFunction>()) return false;
  final r = (f as JSFunction).callAsFunction();
  if (r == null || !r.isA<JSPromise>()) return false;
  final v = await (r as JSPromise<JSAny?>).toDart;
  return v != null && v.isA<JSBoolean>() && (v as JSBoolean).toDart;
}
