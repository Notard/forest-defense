"""앱 아이콘을 플랫폼별 크기로 만든다 (15단계 항목을 사용자 요청으로 12-5단계에 앞당김).

    python tools/gen_art.py prop icon     → art/ref/props/icon.png (Codex, 1:1 원본)
    python tools/make_icons.py            → 웹·Windows·Android 아이콘 + preview/12-5_icon_sizes.png

- 일반 아이콘: 원본 그대로, 모서리만 둥글게 (반지름 20%, 바깥은 투명)
- 마스커블(웹 PWA): 기기가 동그랗게·둥근 사각으로 잘라도 귀가 잘리지 않도록, 원본을 84%로 줄여 가운데 두고
  둘레는 원본 가장자리(숲 초록)를 흐려 이어 붙인다
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art" / "ref" / "props" / "icon.png"
MASTER = ROOT / "art" / "icon" / "icon_1024.png"


def square(im: Image.Image) -> Image.Image:
    s = min(im.size)
    left, top = (im.width - s) // 2, (im.height - s) // 2
    return im.crop((left, top, left + s, top + s)).convert("RGB")


def rounded_mask(size: int, radius: float, feather: float = 0) -> Image.Image:
    """둥근 사각 알파 (4배로 그려 줄여서 가장자리를 매끄럽게)."""
    k = 4
    m = Image.new("L", (size * k, size * k), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size * k - 1, size * k - 1), radius=radius * size * k, fill=255)
    m = m.resize((size, size), Image.LANCZOS)
    return m.filter(ImageFilter.GaussianBlur(feather)) if feather else m


def rounded(master: Image.Image, size: int, radius: float = 0.2) -> Image.Image:
    im = master.resize((size, size), Image.LANCZOS).convert("RGBA")
    im.putalpha(rounded_mask(size, radius))
    return im


def maskable(master: Image.Image, size: int, inner: float = 0.84) -> Image.Image:
    """원본을 [inner]배로 줄여 가운데 두고, 둘레는 원본 가장자리(숲 초록)를 흐려 이어 붙인다.
    84%면 귀 끝까지 안쪽 원(동그란 마스크) 안에 들어온다."""
    big = 1024
    back = master.filter(ImageFilter.GaussianBlur(big * 0.03))
    n = int(big * inner)
    fore = master.resize((n, n), Image.LANCZOS)
    mask = rounded_mask(n, 0.14, feather=n * 0.02)
    back.paste(fore, ((big - n) // 2, (big - n) // 2), mask)
    return back.resize((size, size), Image.LANCZOS)


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    if not SRC.exists():
        sys.exit(f"원본이 없습니다: {SRC} (먼저: python tools/gen_art.py prop icon)")
    master = square(Image.open(SRC)).resize((1024, 1024), Image.LANCZOS)
    MASTER.parent.mkdir(parents=True, exist_ok=True)
    master.save(MASTER)
    out: list[Path] = []

    def save(im: Image.Image, rel: str) -> None:
        path = ROOT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        im.save(path, optimize=True)
        out.append(path)

    # 웹 (PWA)
    save(rounded(master, 32), "web/favicon.png")
    save(rounded(master, 192), "web/icons/Icon-192.png")
    save(rounded(master, 512), "web/icons/Icon-512.png")
    save(maskable(master, 192), "web/icons/Icon-maskable-192.png")
    save(maskable(master, 512), "web/icons/Icon-maskable-512.png")
    # Windows: 한 파일에 여러 크기
    ico = ROOT / "windows/runner/resources/app_icon.ico"
    rounded(master, 256).save(ico, sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
    out.append(ico)
    # Android (런처 아이콘)
    for folder, s in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        save(rounded(master, s), f"android/app/src/main/res/mipmap-{folder}/ic_launcher.png")

    # 확인용 한 장: 일반 512·192·48·32·16, 마스커블 512를 원·둥근 사각으로 잘랐을 때
    sheet = Image.new("RGB", (1500, 560), (236, 230, 214))
    x = 20
    for s in (512, 192, 48, 32, 16):
        im = rounded(master, s)
        sheet.paste(im, (x, 20 + (512 - s) // 2), im)
        x += s + 24
    m = maskable(master, 300)
    circle = Image.new("L", (300, 300), 0)
    ImageDraw.Draw(circle).ellipse((0, 0, 299, 299), fill=255)
    sheet.paste(m, (x, 20), circle)
    sheet.paste(m, (x, 250), rounded_mask(300, 0.3))
    preview = ROOT / "preview" / "12-5_icon_sizes.png"
    sheet.save(preview, optimize=True)

    for p in out:
        print(f"{p.relative_to(ROOT).as_posix():55} {p.stat().st_size / 1024:6.1f} KB")
    print(f"확인용: {preview.relative_to(ROOT).as_posix()}")


if __name__ == "__main__":
    main()
