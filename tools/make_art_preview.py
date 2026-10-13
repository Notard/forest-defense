"""assets/images/<캐릭터>/<캐릭터>.json을 모두 읽어 art_preview.html을 만든다 (Spriteflow Workspace처럼 바로 재생).

    python tools/make_art_preview.py
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

NAMES = {"fox": "여우", "squirrel": "다람쥐", "turtle": "거북이", "skunk": "스컨크", "slime": "슬라임",
         "slime_helmet": "투구 슬라임", "wisp": "도깨비불"}
ACTIONS = {"idle": "기본", "attack": "공격", "hit": "피격", "death": "쓰러짐", "produce": "도토리 만들기",
           "walk": "이동", "eat": "갉아먹기", "arm": "준비", "explode": "폭발", "idle_cracked": "금 간 기본"}

PAGE = """<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>숲 지키기 아트</title>
<style>
:root{--bg:#f6f8f2;--card:#fff;--ink:#22301a;--muted:#5f6b57;--line:#dfe6d4;--leaf:#5f8f3a;--leaf-soft:#e6efd9;--grass1:#8CC461;--grass2:#79B352}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#141a11;--card:#1d2618;--ink:#e6eedd;--muted:#a3b097;--line:#2f3b28;--leaf:#8cc461;--leaf-soft:#26331c}}
:root[data-theme="dark"]{--bg:#141a11;--card:#1d2618;--ink:#e6eedd;--muted:#a3b097;--line:#2f3b28;--leaf:#8cc461;--leaf-soft:#26331c}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.6 system-ui,"Malgun Gothic",sans-serif}
main{max-width:1180px;margin:0 auto;padding:28px 16px 64px}
h1{margin:0 0 4px;font-size:1.7rem}
h2{font-size:1.25rem;margin:32px 0 12px;padding-top:16px;border-top:2px solid var(--leaf)}
a{color:var(--leaf)}
.muted{color:var(--muted);font-size:.92rem}
.bar{position:sticky;top:0;z-index:2;background:var(--bg);padding:10px 0;display:flex;flex-wrap:wrap;gap:8px;align-items:center;border-bottom:1px solid var(--line)}
.bar button{font:inherit;font-size:.92rem;border:1px solid var(--line);background:var(--card);color:var(--ink);border-radius:999px;padding:4px 14px;cursor:pointer}
.bar button[aria-pressed="true"]{background:var(--leaf);border-color:var(--leaf);color:#fff}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:14px}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;overflow:hidden}
.stage{position:relative;background:repeating-linear-gradient(90deg,var(--grass1) 0 50%,var(--grass2) 50% 100%);background-size:200px 100%;display:flex;align-items:flex-end;justify-content:center;height:240px}
.stage canvas{display:block;width:240px;height:240px;image-rendering:auto}
.stage.small{height:150px;background-size:200px 100%;justify-content:flex-start;overflow:hidden}
.stage.small::after{content:'';position:absolute;left:0;right:0;bottom:0;height:40px;background:rgba(0,0,0,.06)}
.stage.small canvas{width:auto}
.meta{padding:8px 12px;font-size:.9rem;display:flex;justify-content:space-between;gap:8px;flex-wrap:wrap}
.meta b{font-size:1rem}
.strip{display:flex;overflow-x:auto;gap:2px;padding:0 12px 10px}
.strip span{flex:0 0 auto;width:34px;height:34px;border-radius:4px;background-repeat:no-repeat;background-color:var(--leaf-soft);outline:2px solid transparent;outline-offset:-2px}
.strip span.on{outline-color:var(--leaf)}
.strip span.ev{box-shadow:inset 0 -4px 0 #e8772e}
code{background:var(--leaf-soft);padding:1px 6px;border-radius:4px;font-size:.88em}
</style>
</head>
<body>
<main>
  <h1>🌰 숲 지키기 · 아트 미리보기</h1>
  <p class="muted"><a href="todo.html">할 일 목록</a> · <a href="preview.html">게임 미리보기</a> · <a href="worklog.html">작업 기록</a> ·
    Blender 컷아웃으로 렌더한 스프라이트 시트를 실제 fps로 재생한다. 아래 띠의 주황 밑줄은 이벤트 프레임(발사·생산·피해).</p>
  <div class="bar">
    <button data-speed="1" aria-pressed="true">실제 속도</button>
    <button data-speed="0.25">¼ 느리게</button>
    <button id="pause">일시정지</button>
    <button id="step">한 프레임</button>
    <button id="size" aria-pressed="false">게임 크기로 보기</button>
  </div>
  <div id="root"></div>
</main>
<script>
const DATA = __DATA__;
const NAMES = __NAMES__, ACTIONS = __ACTIONS__;
const GAME_HEIGHT = 100;  // 게임에서 유닛 키 (plan.md 3-2: 칸 110px 안에 96~100px)
let speed = 1, paused = false, gameSize = false;
const players = [];

for (const ch of DATA) {
  const h2 = document.createElement('h2');
  h2.textContent = `${NAMES[ch.character] || ch.character} (${ch.character})`;
  const grid = document.createElement('div'); grid.className = 'grid';
  for (const [name, a] of Object.entries(ch.actions)) {
    const card = document.createElement('div'); card.className = 'card';
    const stage = document.createElement('div'); stage.className = 'stage';
    const cv = document.createElement('canvas'); cv.width = ch.frame[0]; cv.height = ch.frame[1];
    stage.append(cv);
    const meta = document.createElement('div'); meta.className = 'meta';
    meta.innerHTML = `<span><b>${ACTIONS[name] || name}</b> <code>${name}</code></span>` +
      `<span>${a.frames}프레임 · ${a.fps}fps · ${a.loop ? '반복' : '한 번'}${a.event ? ` · 이벤트 ${a.event}` : ''}</span>`;
    const strip = document.createElement('div'); strip.className = 'strip';
    const src = `assets/images/${ch.character}/${name}.png`;
    for (let i = 0; i < a.frames; i++) {
      const s = document.createElement('span');
      s.style.backgroundImage = `url(${src})`;
      s.style.backgroundSize = `${34 * a.frames}px 34px`;
      s.style.backgroundPosition = `${-34 * i}px 0`;
      if (a.event === i + 1) s.classList.add('ev');
      strip.append(s);
    }
    card.append(stage, meta, strip); grid.append(card);
    const img = new Image(); img.src = src;
    players.push({ ch, a, cv, ctx: cv.getContext('2d'), img, stage, strip, frame: 0, t: 0, hold: 0 });
  }
  document.getElementById('root').append(h2, grid);
}

function draw(p) {
  const [w, h] = p.ch.frame;
  p.ctx.clearRect(0, 0, w, h);
  if (p.img.complete) p.ctx.drawImage(p.img, p.frame * w, 0, w, h, 0, 0, w, h);
  [...p.strip.children].forEach((s, i) => s.classList.toggle('on', i === p.frame));
}
function advance(p) {
  if (p.frame + 1 < p.a.frames) p.frame++;
  else if (p.a.loop) p.frame = 0;
  else { p.hold++; if (p.hold > p.a.fps) { p.frame = 0; p.hold = 0; } }  // 한 번 동작은 1초 쉬고 다시
}
let last = performance.now();
function tick(now) {
  const dt = Math.min(0.1, (now - last) / 1000); last = now;
  for (const p of players) {
    if (!paused) { p.t += dt * speed; const step = 1 / p.a.fps; while (p.t >= step) { p.t -= step; advance(p); } }
    draw(p);
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);

function layout() {
  for (const p of players) {
    p.stage.classList.toggle('small', gameSize);
    // 게임 크기: 캐릭터 키(발 기준점 위쪽)가 GAME_HEIGHT px가 되게 줄인다
    const s = gameSize ? GAME_HEIGHT / (p.ch.anchor[1] * 0.68) : 240 / p.ch.frame[1];
    p.cv.style.width = `${p.ch.frame[0] * s}px`; p.cv.style.height = `${p.ch.frame[1] * s}px`;
    // 두 번째 칸(가로 100~200px) 가운데에 발을 둔다. 첫 칸은 꼬리가 걸치는 자리
    p.cv.style.marginLeft = gameSize ? `${150 - p.ch.anchor[0] * s}px` : '0';
    p.cv.style.marginBottom = gameSize ? `${(p.ch.anchor[1] - p.ch.frame[1]) * s + 20}px` : '0';
  }
}
layout();
document.querySelectorAll('[data-speed]').forEach(b => b.onclick = () => {
  speed = +b.dataset.speed;
  document.querySelectorAll('[data-speed]').forEach(x => x.setAttribute('aria-pressed', x === b));
});
document.getElementById('pause').onclick = e => { paused = !paused; e.target.textContent = paused ? '재생' : '일시정지'; };
document.getElementById('step').onclick = () => { paused = true; document.getElementById('pause').textContent = '재생'; players.forEach(advance); };
document.getElementById('size').onclick = e => { gameSize = !gameSize; e.target.setAttribute('aria-pressed', gameSize); layout(); };
</script>
</body>
</html>
"""


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    data = [json.loads(p.read_text(encoding="utf-8")) for p in sorted((ROOT / "assets" / "images").glob("*/*.json"))]
    html = (PAGE.replace("__DATA__", json.dumps(data, ensure_ascii=False))
            .replace("__NAMES__", json.dumps(NAMES, ensure_ascii=False))
            .replace("__ACTIONS__", json.dumps(ACTIONS, ensure_ascii=False)))
    (ROOT / "art_preview.html").write_text(html, encoding="utf-8")
    print(f"art_preview.html: 캐릭터 {len(data)}개, 동작 {sum(len(d['actions']) for d in data)}개")


if __name__ == "__main__":
    main()
