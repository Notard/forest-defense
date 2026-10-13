"""효과·배경 정지 그림을 게임용으로 정리해 assets/images/fx/에 저장한다 (plan.md 3단계).

    python tools/prep_props.py

- art/ref/props/<이름>.png (gen_art.py prop) → 알파 정리, 여백 자르기, size 안에 맞춰 가운데 정렬
- 배경(opaque)은 16:9로 가운데를 잘라 원본 해상도 그대로 JPG로 저장 (고해상도 화면에서도 선명하게)
  flatten_rows가 있으면 그 영역에서 가로줄마다 밝기를 평균에 맞춰 줄무늬를 지운다 (풀결은 남는다)
- 컷아웃 조각에서 바로 쓰는 효과: 여우불 = fox/flame, 투구 = slime_helmet/helmet (build_sprites.sh를 먼저)
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "images" / "fx"
FROM_PARTS = {"fireball": ("fox", "flame", (96, 128)), "helmet": ("slime_helmet", "helmet", (160, 140))}


def clean(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    a = im.getchannel("A").point(lambda v: 0 if v < 16 else (255 if v >= 200 else v))
    im.putalpha(a)
    return im.crop(a.getbbox())


def fit(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    w, h = size
    s = min(w / im.width, h / im.height)
    small = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    canvas = Image.new("RGBA", size)
    canvas.alpha_composite(small, ((w - small.width) // 2, (h - small.height) // 2))
    return canvas


def flatten_rows(im: Image.Image, box: list[float]) -> Image.Image:
    """box(비율) 안 잔디 픽셀의 가로줄 밝기를 전체 평균에 맞춘다. 가장자리는 부드럽게 섞는다."""
    a = np.array(im).astype(float)
    h, w = a.shape[:2]
    x0, x1, y0, y1 = int(box[0] * w), int(box[1] * w), int(box[2] * h), int(box[3] * h)
    region = a[y0:y1, x0:x1]
    grass = (region[..., 1] > region[..., 0] + 20) & (region[..., 1] > region[..., 2] + 40)
    lum = region.mean(axis=2)
    target = lum[grass].mean()
    row_mean = np.array([lum[r][grass[r]].mean() if grass[r].any() else target for r in range(region.shape[0])])
    row_mean = np.convolve(row_mean, np.ones(5) / 5, mode="same")  # 풀결은 남기고 줄무늬만
    gain = (target / row_mean)[:, None, None]
    fixed = np.clip(region * gain, 0, 255)
    # 잔디 픽셀만 바꾸고, 영역 가장자리 30px는 원래 그림과 섞는다
    rh, rw = region.shape[:2]
    xs, ys = np.arange(rw), np.arange(rh)
    ramp_x = np.minimum(xs, rw - 1 - xs) / 30
    ramp_y = np.minimum(ys, rh - 1 - ys) / 30
    ramp = np.minimum(ramp_y[:, None], ramp_x[None, :])
    weight = (np.clip(ramp, 0, 1) * grass)[..., None]
    a[y0:y1, x0:x1] = region * (1 - weight) + fixed * weight
    return Image.fromarray(a.astype(np.uint8))


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    props = json.loads((ROOT / "tools" / "art_prompts.json").read_text(encoding="utf-8"))["props"]
    OUT.mkdir(parents=True, exist_ok=True)
    for name, spec in props.items():
        if name.startswith("_"):
            continue
        src = ROOT / "art" / "ref" / "props" / f"{name}.png"
        if not src.exists():
            print(f"{name}: 원본 없음 (gen_art.py prop {name})")
            continue
        im = Image.open(src)
        if spec.get("opaque"):
            im = im.convert("RGB")
            target = im.width / im.height
            if target > 16 / 9:
                w = round(im.height * 16 / 9)
                im = im.crop(((im.width - w) // 2, 0, (im.width + w) // 2, im.height))
            else:
                h = round(im.width * 9 / 16)
                im = im.crop((0, (im.height - h) // 2, im.width, (im.height + h) // 2))
            if "flatten_rows" in spec:
                im = flatten_rows(im, spec["flatten_rows"])
            path = OUT / f"{name}.jpg"
            im.save(path, quality=88, optimize=True)
        else:
            path = OUT / f"{name}.png"
            fit(clean(im), tuple(spec["size"])).save(path, optimize=True)
        print(f"{path.relative_to(ROOT).as_posix()}  {Image.open(path).size}  {path.stat().st_size / 1024:,.0f} KB")
    for name, (character, part, size) in FROM_PARTS.items():
        src = ROOT / "art" / "parts" / character / f"{part}.png"
        if not src.exists():
            print(f"{name}: {character} 조각 없음 (bash tools/build_sprites.sh {character})")
            continue
        path = OUT / f"{name}.png"
        fit(clean(Image.open(src)), size).save(path, optimize=True)
        print(f"{path.relative_to(ROOT).as_posix()}  {size}  ← {character}/{part}")


if __name__ == "__main__":
    main()
