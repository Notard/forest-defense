"""TODO.md -> todo.html, WORKLOG.md -> worklog.html, REPORT.md -> report.html 변환기.

TODO.md와 WORKLOG.md가 원본이다. 체크 후 이 스크립트를 실행하면
TODO.md의 진행률 숫자를 갱신하고 todo.html, worklog.html을 다시 만든다.

    python tools/make_todo_html.py
"""
import html
import re
from datetime import datetime
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parent.parent
MD = ROOT / "TODO.md"
OUT = ROOT / "todo.html"
WORKLOG_MD = ROOT / "WORKLOG.md"
WORKLOG_OUT = ROOT / "worklog.html"
REPORT_MD = ROOT / "REPORT.md"
REPORT_OUT = ROOT / "report.html"

ITEM = re.compile(r"^- \[( |x|X)\] (.+)$")
STAGE = re.compile(r"^## (.+)$")

# 문서 사이 링크는 HTML 버전으로 연결한다.
MD_TO_HTML = {"TODO.md": "todo.html", "WORKLOG.md": "worklog.html", "plan.md": "plan.html", "REPORT.md": "report.html"}


def fix_links(text: str) -> str:
    return re.sub(
        r'href="([^"]+\.md)"', lambda m: f'href="{MD_TO_HTML.get(m.group(1), m.group(1))}"', text
    )


def inline(text: str) -> str:
    text = html.escape(text)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", text)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)
    return fix_links(text)


def parse(lines):
    stages, log = [], []
    section = None
    for line in lines:
        line = line.rstrip()
        m = STAGE.match(line)
        if m:
            title = m.group(1)
            if title.startswith("완료 기록"):
                section = "log"
            else:
                section = {"title": title, "items": []}
                stages.append(section)
            continue
        if section == "log":
            if line.startswith("|") and not re.match(r"^\|\s*[-:| ]+\|$", line):
                cells = [c.strip() for c in line.strip("|").split("|")]
                if cells[0] != "날짜" and any(cells):
                    log.append(cells)
            continue
        m = ITEM.match(line)
        if m and isinstance(section, dict):
            text = m.group(2)
            gate = "✅ 완료 기준" in text
            text = text.replace("✅ 완료 기준", "").strip()
            section["items"].append({"done": m.group(1) != " ", "text": text, "gate": gate})
    return stages, log


def update_md_progress(lines, done, total):
    out = []
    for line in lines:
        if line.startswith("**진행률:"):
            line = f"**진행률: {done} / {total}**"
        out.append(line)
    MD.write_text("\n".join(out) + "\n", encoding="utf-8")


def render(stages, log, done, total):
    pct = round(done * 100 / total) if total else 0
    cards = []
    for s in stages:
        n = len(s["items"])
        d = sum(i["done"] for i in s["items"])
        state = "complete" if n and d == n else ("active" if d else "")
        num, _, name = s["title"].partition(". ")
        if not name:
            num, name = "", s["title"]
        rows = []
        for i in s["items"]:
            cls = "item" + (" done" if i["done"] else "") + (" gate" if i["gate"] else "")
            tag = '<span class="tag">완료 기준</span>' if i["gate"] else ""
            rows.append(
                f'<li class="{cls}"><span class="box" aria-hidden="true"></span>'
                f'<span class="txt">{inline(i["text"])}{tag}</span></li>'
            )
        cards.append(f"""
<section class="stage {state}">
  <div class="shead">
    <span class="n">{html.escape(num)}</span>
    <h2>{html.escape(name)}</h2>
    <span class="cnt">{d} / {n}</span>
  </div>
  <div class="sbar"><i style="width:{round(d * 100 / n) if n else 0}%"></i></div>
  <ul>{''.join(rows)}</ul>
</section>""")

    if log:
        log_rows = "".join(
            "<tr>" + "".join(f"<td>{inline(c)}</td>" for c in row) + "</tr>" for row in log
        )
        log_html = f"<table><tr><th>날짜</th><th>단계</th><th>메모</th></tr>{log_rows}</table>"
    else:
        log_html = '<p class="muted">아직 완료된 항목이 없습니다.</p>'

    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    return TEMPLATE.format(
        done=done, total=total, pct=pct, cards="".join(cards), log=log_html, now=now
    )


TEMPLATE = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>숲 지키기 할 일</title>
<style>
:root{{
  --bg:#faf6f0; --surface:#fff; --ink:#2b2420; --muted:#7a6d64; --line:#eadfd3;
  --fox:#5f8f3a; --fox-soft:#e6efd9; --ok:#4f9a34; --ok-soft:#e3f1da;
}}
@media (prefers-color-scheme: dark){{
  :root:not([data-theme="light"]){{
    --bg:#1b1715; --surface:#252020; --ink:#f1e9e2; --muted:#b0a39a; --line:#3a322d;
    --fox-soft:#26331c; --ok:#7cc55c; --ok-soft:#24331c;
  }}
}}
:root[data-theme="dark"]{{
  --bg:#1b1715; --surface:#252020; --ink:#f1e9e2; --muted:#b0a39a; --line:#3a322d;
  --fox-soft:#26331c; --ok:#7cc55c; --ok-soft:#24331c;
}}
*{{box-sizing:border-box}}
body{{margin:0;background:var(--bg);color:var(--ink);line-height:1.55;
  font-family:"Pretendard","Malgun Gothic","Apple SD Gothic Neo",system-ui,sans-serif}}
.wrap{{max-width:880px;margin:0 auto;padding:40px 16px 80px}}
h1{{font-size:1.9rem;margin:0 0 4px;letter-spacing:-.02em}}
.muted{{color:var(--muted);font-size:.9rem}}
a{{color:var(--fox)}}
.hero{{background:var(--surface);border:1px solid var(--line);border-radius:14px;padding:20px;margin:20px 0 28px}}
.hero .big{{font-size:2.4rem;font-weight:800;font-variant-numeric:tabular-nums}}
.hero .big small{{font-size:1rem;color:var(--muted);font-weight:500}}
.bar{{height:14px;background:var(--fox-soft);border-radius:999px;overflow:hidden;margin-top:10px}}
.bar i{{display:block;height:100%;background:var(--fox);border-radius:999px}}
.stage{{background:var(--surface);border:1px solid var(--line);border-radius:12px;padding:16px 18px;margin-bottom:14px}}
.stage.complete{{border-color:var(--ok)}}
.shead{{display:flex;align-items:center;gap:10px}}
.shead h2{{font-size:1.08rem;margin:0;flex:1}}
.n{{background:var(--fox);color:#fff;min-width:28px;height:28px;border-radius:6px;display:inline-grid;place-items:center;font-weight:700;font-size:.9rem}}
.stage.complete .n{{background:var(--ok)}}
.cnt{{font-variant-numeric:tabular-nums;color:var(--muted);font-size:.9rem}}
.sbar{{height:4px;background:var(--fox-soft);border-radius:4px;margin:10px 0 6px;overflow:hidden}}
.sbar i{{display:block;height:100%;background:var(--fox)}}
.stage.complete .sbar i{{background:var(--ok)}}
ul{{list-style:none;margin:0;padding:0}}
.item{{display:flex;gap:10px;align-items:flex-start;padding:7px 0;border-bottom:1px dashed var(--line);font-size:.95rem}}
.item:last-child{{border-bottom:0}}
.box{{flex:none;width:18px;height:18px;border:2px solid var(--line);border-radius:5px;margin-top:2px;display:grid;place-items:center}}
.item.done .box{{background:var(--ok);border-color:var(--ok)}}
.item.done .box::after{{content:"";width:5px;height:9px;border:solid #fff;border-width:0 2px 2px 0;transform:rotate(45deg) translate(-1px,-1px)}}
.item.done .txt{{color:var(--muted);text-decoration:line-through;text-decoration-color:var(--line)}}
.item.gate .txt{{font-weight:600}}
.tag{{display:inline-block;margin-left:8px;font-size:.72rem;font-weight:700;padding:1px 7px;border-radius:999px;background:var(--ok-soft);color:var(--ok);text-decoration:none}}
code{{background:var(--fox-soft);padding:1px 6px;border-radius:4px;font-size:.86em}}
h3{{margin:36px 0 12px;font-size:1.1rem}}
table{{width:100%;border-collapse:collapse;background:var(--surface);border:1px solid var(--line);border-radius:12px;overflow:hidden;font-size:.92rem}}
th,td{{text-align:left;padding:8px 12px;border-bottom:1px solid var(--line)}}
th{{color:var(--muted)}}
</style>
</head>
<body>
<div class="wrap">
  <h1>🌰 숲 지키기 · 할 일 목록</h1>
  <p class="muted">원본: TODO.md · 상세 계획: <a href="plan.html">plan.html</a> · 게임 미리보기: <a href="preview.html">preview.html</a> · 아트 미리보기: <a href="art_preview.html">art_preview.html</a> · 작업 기록: <a href="worklog.html">worklog.html</a> · 결과 보고서: <a href="report.html">report.html</a> · 마지막 갱신 {now}</p>

  <div class="hero">
    <div class="big">{pct}% <small>{done} / {total} 완료</small></div>
    <div class="bar"><i style="width:{pct}%"></i></div>
  </div>

  {cards}

  <h3>완료 기록</h3>
  {log}
</div>
</body>
</html>
"""


WORKLOG_CSS = """
article h1{font-size:1.9rem;margin:0 0 8px;letter-spacing:-.02em}
article h2{font-size:1.25rem;margin:36px 0 14px;padding-top:24px;border-top:2px solid var(--fox)}
article h3{font-size:1.02rem;margin:24px 0 10px;color:var(--fox)}
article blockquote{margin:0 0 16px;color:var(--muted);font-size:.92rem;border-left:3px solid var(--line);padding-left:12px}
article blockquote p{margin:0}
article pre{background:var(--fox-soft);padding:14px;border-radius:8px;overflow-x:auto;font-size:.86rem}
article pre code{background:none;padding:0}
article table{margin:8px 0 16px}
article ol,article ul{padding-left:22px}
article hr{display:none}
article img{max-width:100%;border-radius:10px;display:block}
article td img{margin:0 auto}
"""


def render_worklog():
    render_doc(WORKLOG_MD, WORKLOG_OUT, "숲 지키기 작업 기록")


def render_report():
    render_doc(REPORT_MD, REPORT_OUT, "숲 지키기 결과 보고서")


def render_doc(src, out, title):
    if not src.exists():
        return
    body = markdown.markdown(src.read_text(encoding="utf-8"), extensions=["tables", "fenced_code"])
    style = TEMPLATE.split("<style>")[1].split("</style>")[0].replace("{{", "{").replace("}}", "}")
    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    out.write_text(
        f"""<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>{style}{WORKLOG_CSS}</style>
</head>
<body>
<div class="wrap">
  <p class="muted"><a href="todo.html">← 할 일 목록</a> · <a href="plan.html">계획서</a> · <a href="preview.html">게임 미리보기</a> · <a href="art_preview.html">아트 미리보기</a> · <a href="worklog.html">작업 기록</a> · <a href="report.html">결과 보고서</a> · 마지막 갱신 {now}</p>
  <article>{fix_links(body)}</article>
</div>
</body>
</html>
""",
        encoding="utf-8",
    )


def main():
    import sys
    sys.stdout.reconfigure(encoding="utf-8")
    lines = MD.read_text(encoding="utf-8").splitlines()
    stages, log = parse(lines)
    items = [i for s in stages for i in s["items"]]
    done, total = sum(i["done"] for i in items), len(items)
    update_md_progress(lines, done, total)
    OUT.write_text(render(stages, log, done, total), encoding="utf-8")
    render_worklog()
    render_report()
    print(f"todo.html, worklog.html, report.html 생성: {done}/{total}")


if __name__ == "__main__":
    main()
