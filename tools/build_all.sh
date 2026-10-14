#!/usr/bin/env bash
# 모든 플랫폼 빌드 (15단계). Git Bash에서:  bash tools/build_all.sh
#
# - 처음에 flutter clean: 플러그인을 더하거나 뺀 뒤 증분 빌드가 예전 플러그인 등록 파일을 쓰는 문제가 두 번 있었다 (12단계 저장, 14-3단계 링크)
# - 웹은 GitHub Pages와 같은 하위 경로(/forest-defense/)로 빌드하고 오프라인 저장 목록(sw.js)을 만든다
# - Android APK는 Android SDK가 있을 때만 (15단계: 지금은 PWA로 대신해 뺐다)
set -euo pipefail
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1   # Git Bash가 /forest-defense/를 C:/Program Files/Git/forest-defense/로 바꾸지 않게

step() { printf '\n== %s ==\n' "$1"; }

step "정리"
flutter clean >/dev/null
flutter pub get >/dev/null

step "Windows"
flutter build windows --release
exe=build/windows/x64/runner/Release/forest_defense.exe
test -f "$exe"

step "웹 (/forest-defense/)"
flutter build web --release --base-href /forest-defense/ --no-web-resources-cdn
python tools/make_sw.py

step "Android"
if flutter doctor 2>/dev/null | grep -q '\[√\] Android toolchain'; then
  flutter build apk --release
  apk=build/app/outputs/flutter-apk/app-release.apk
else
  echo "Android SDK가 없어 건너뜀 (안드로이드는 PWA로 설치)"
  apk=""
fi

step "결과"
du -sh build/windows/x64/runner/Release | sed 's/^/Windows  /'
du -sh build/web | sed 's/^/웹       /'
if [ -n "$apk" ]; then du -h "$apk" | sed 's/^/APK      /'; fi
echo "Windows 실행:  $exe   (소리 없이: --mute)"
echo "웹 확인:      python tools/serve_web.py 8790 --base /forest-defense/  →  http://localhost:8790/forest-defense/"
