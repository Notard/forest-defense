"""웹 빌드에 오프라인 캐시 서비스 워커(build/web/sw.js)를 만든다 (16단계).

    flutter build web --release --no-web-resources-cdn [--base-href /forest-defense/]
    python tools/make_sw.py

- 게임 파일(코드·그림·소리·폰트·아이콘)은 설치할 때 미리 저장한다 → 한 번 열면 인터넷 없이도 된다
- 그래픽 엔진(canvaskit/)은 브라우저마다 받는 파일이 달라서, 처음 받을 때 저장한다
- 페이지(index.html)는 인터넷이 되면 새로 받고(업데이트가 바로 보이게), 안 되면 저장본
- 빌드가 바뀌면 파일 목록의 해시가 바뀌어 새 캐시를 만들고 예전 캐시는 지운다
경로는 sw.js 기준 상대 경로라 /forest-defense/ 같은 하위 경로에서도 그대로 된다.
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "build" / "web"

# 미리 저장하지 않는 것: 서비스 워커 자신, 엔진(처음 받을 때 저장), 디버그 기호·소스 맵, Flutter 기본 워커
SKIP_DIRS = ("canvaskit/",)
# og.jpg는 링크 미리보기(카카오톡·SNS)용이라 게임에는 필요 없다
SKIP_FILES = {"sw.js", "flutter_service_worker.js", "og.jpg"}
SKIP_SUFFIXES = (".symbols", ".map")

TEMPLATE = r"""// 숲 지키기 오프라인 캐시 — tools/make_sw.py가 빌드마다 만든다. 고치지 말 것.
const VERSION = '__VERSION__';
const CACHE = 'forest-' + VERSION;
const PRECACHE = __FILES__;

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(PRECACHE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k.startsWith('forest-') && k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  // 페이지: 인터넷 먼저 (새 빌드가 바로 보이게), 안 되면 저장본
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then((response) => {
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put('index.html', copy));
          return response;
        })
        .catch(() => caches.match('index.html', { cacheName: CACHE })),
    );
    return;
  }

  // 나머지: 저장본 먼저, 없으면 받아서 저장 (엔진 파일은 여기서 처음 저장된다)
  event.respondWith(
    caches.open(CACHE).then(async (cache) => {
      const hit = await cache.match(request, { ignoreSearch: true });
      if (hit) return hit;
      const response = await fetch(request);
      // 소리는 부분 요청(206)으로 오기도 한다: 캐시에는 전체 응답(200)만 넣는다
      if (response.status === 200) cache.put(request, response.clone());
      return response;
    }),
  );
});
"""


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    if not (WEB / "index.html").exists():
        sys.exit(f"{WEB} 에 빌드가 없습니다. 먼저: flutter build web --release --no-web-resources-cdn")
    files = []
    digest = hashlib.sha256()
    total = 0
    for p in sorted(WEB.rglob("*")):
        if not p.is_file():
            continue
        rel = p.relative_to(WEB).as_posix()
        if rel in SKIP_FILES or rel.startswith(SKIP_DIRS) or rel.endswith(SKIP_SUFFIXES):
            continue
        # 점으로 시작하는 파일(.last_build_id 등)은 GitHub Pages에 올라가지 않는다. 목록에 있으면 그 하나가 404가 나
        # 설치(cache.addAll) 전체가 실패한다 (16단계, 공개 뒤 실제 사이트에서 찾음)
        if any(part.startswith(".") for part in rel.split("/")):
            continue
        files.append(rel)
        data = p.read_bytes()
        digest.update(rel.encode())
        digest.update(hashlib.sha256(data).digest())
        total += len(data)
    files.insert(0, "./")
    version = digest.hexdigest()[:12]
    sw = TEMPLATE.replace("__VERSION__", version).replace("__FILES__", json.dumps(files, ensure_ascii=False, indent=2))
    (WEB / "sw.js").write_text(sw, encoding="utf-8")
    print(f"build/web/sw.js  버전 {version}  미리 저장 {len(files)}개 {total / 1024 / 1024:.1f} MB (엔진 canvaskit/은 처음 받을 때 저장)")


if __name__ == "__main__":
    main()
