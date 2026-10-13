{{flutter_js}}
{{flutter_build_config}}

// Flutter 기본 서비스 워커(곧 없어질 예정)는 등록하지 않는다.
// 오프라인 캐시는 index.html이 등록하는 sw.js가 맡는다 (tools/make_sw.py, 16단계).
_flutter.loader.load();
