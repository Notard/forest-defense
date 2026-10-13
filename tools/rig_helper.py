"""리그(부위 다각형·기준점)를 정할 때 보는 좌표 격자 그림을 만든다.

    python tools/rig_helper.py squirrel                      → 전체 격자 (100px 굵은 선, 50px 가는 선)
    python tools/rig_helper.py squirrel 380 540 1010 720     → 그 영역 확대 (25px 선)

결과는 art/parts/<캐릭터>/_grid*.jpg (git 제외). 투명 배경은 파란색으로 칠해 경계가 잘 보이게 한다.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent


def load(name: str) -> Image.Image:
    im = Image.open(ROOT / "art" / "ref" / f"{name}.png").convert("RGBA")
    a = im.getchannel("A").point(lambda v: 0 if v < 16 else (255 if v >= 200 else v))
    im.putalpha(a)
    bg = Image.new("RGBA", im.size, (90, 140, 200, 255))
    bg.alpha_composite(im)
    return bg


def grid(img: Image.Image, box: tuple[int, int, int, int], scale: int, step: int, label: int) -> Image.Image:
    x0, y0, x1, y1 = box
    out = img.crop(box).resize(((x1 - x0) * scale, (y1 - y0) * scale), Image.NEAREST)
    d = ImageDraw.Draw(out)
    font = ImageFont.truetype("arial.ttf", 14 if scale > 1 else 22)
    for v in range((x0 // step + 1) * step, x1, step):
        x = (v - x0) * scale
        major = v % (step * 2 if step < 100 else 100) == 0
        d.line([(x, 0), (x, out.height)], fill=(255, 0, 0) if major else (255, 150, 150), width=2 if major else 1)
        if v % label == 0:
            d.text((x + 3, 3), str(v), fill=(255, 255, 0), font=font)
    for v in range((y0 // step + 1) * step, y1, step):
        y = (v - y0) * scale
        major = v % (step * 2 if step < 100 else 100) == 0
        d.line([(0, y), (out.width, y)], fill=(255, 0, 0) if major else (255, 150, 150), width=2 if major else 1)
        if v % label == 0:
            d.text((3, y + 3), str(v), fill=(255, 255, 0), font=font)
    return out


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) not in (2, 6):
        sys.exit(__doc__)
    name = sys.argv[1]
    img = load(name)
    out_dir = ROOT / "art" / "parts" / name
    out_dir.mkdir(parents=True, exist_ok=True)
    if len(sys.argv) == 2:
        out = grid(img, (0, 0, *img.size), 1, 50, 100)
        path = out_dir / "_grid.jpg"
    else:
        box = tuple(int(v) for v in sys.argv[2:6])
        scale = max(1, min(4, 900 // max(box[2] - box[0], box[3] - box[1])))
        out = grid(img, box, scale, 25, 50)
        path = out_dir / f"_grid_{'_'.join(sys.argv[2:6])}.jpg"
    out.convert("RGB").save(path, quality=90)
    print(path.relative_to(ROOT).as_posix(), out.size)


if __name__ == "__main__":
    main()
