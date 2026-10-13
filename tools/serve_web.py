"""웹 빌드(build/web)를 내주는 개발용 서버 (12-3단계).

    python tools/serve_web.py          → http://localhost:8770
    python tools/serve_web.py 8771

`python -m http.server`와 다른 점:
- 브라우저가 파일을 저장해 두지 않게 한다 (Cache-Control: no-store). 새로 빌드해도 예전 main.dart.js를
  그대로 쓰는 일이 없다.
- 그 포트에 이미 다른 서버가 있으면 시작하지 않는다. Windows에서 http.server는 같은 포트를 겹쳐 열 수 있어서,
  예전에 띄운 서버가 남아 있으면 브라우저가 그쪽에 붙는 일이 있었다 (12-3단계: 음악이 안 나온다는 제보).
- IPv4·IPv6 모두에서 받는다 (`localhost`가 어느 쪽으로 풀려도 같은 서버).
"""
from __future__ import annotations

import functools
import http.server
import socket
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "build" / "web"


class NoStoreHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, format: str, *args) -> None:  # noqa: A002 - 부모 이름 그대로
        pass  # 요청마다 찍지 않는다 (오류만 아래에서)


class ExclusiveServer(http.server.ThreadingHTTPServer):
    address_family = socket.AF_INET6
    allow_reuse_address = False  # Windows: 이미 쓰는 포트면 bind 실패

    def server_bind(self) -> None:
        if hasattr(socket, "SO_EXCLUSIVEADDRUSE"):  # Windows: 다른 프로그램이 이 포트를 겹쳐 열지 못하게
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
        self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)  # IPv4도 함께
        super().server_bind()


def port_in_use(port: int) -> bool:
    for family, host in ((socket.AF_INET, "127.0.0.1"), (socket.AF_INET6, "::1")):
        with socket.socket(family, socket.SOCK_STREAM) as s:
            s.settimeout(0.3)
            if s.connect_ex((host, port)) == 0:
                return True
    return False


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8770
    if not (WEB / "index.html").exists():
        sys.exit(f"{WEB} 에 빌드가 없습니다. 먼저: flutter build web --release")
    if port_in_use(port):
        sys.exit(f"포트 {port}에 이미 다른 서버가 있습니다. 예전에 띄운 서버 창을 닫거나(Ctrl+C) 다른 포트를 쓰세요:\n"
                 f"    python tools/serve_web.py {port + 1}")
    handler = functools.partial(NoStoreHandler, directory=str(WEB))
    try:
        server = ExclusiveServer(("::", port), handler)
    except OSError as e:
        sys.exit(f"포트 {port}를 열 수 없습니다: {e}")
    print(f"숲 지키기 웹 빌드: http://localhost:{port}  (끄기: Ctrl+C)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
