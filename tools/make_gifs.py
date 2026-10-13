"""스프라이트 시트를 잔디 배경 GIF로 만든다 (문서·README용).

    python tools/make_gifs.py fox      → preview/03_fox_<동작>.gif, preview/03_fox_all.gif
"""
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
GRASS = (140, 196, 97)
SIZE = 200  # GIF 한 칸 크기 (px)


def frames_of(name: str, action: str, meta: dict) -> list[Image.Image]:
    sheet = Image.open(ROOT / "assets" / "images" / name / f"{action}.png").convert("RGBA")
    w, h = meta["frame"]
    out = []
    for i in range(meta["actions"][action]["frames"]):
        bg = Image.new("RGBA", (w, h), GRASS + (255,))
        bg.alpha_composite(sheet.crop((i * w, 0, (i + 1) * w, h)))
        out.append(bg.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB"))
    return out


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    name = sys.argv[1] if len(sys.argv) == 2 else sys.exit(__doc__)
    meta = json.loads((ROOT / "assets" / "images" / name / f"{name}.json").read_text(encoding="utf-8"))
    out_dir = ROOT / "preview"
    clips = {}
    for action, spec in meta["actions"].items():
        frames = frames_of(name, action, meta)
        hold = [] if spec["loop"] else [frames[-1]] * (spec["fps"] // 2)  # 한 번 동작은 끝 모습을 0.5초 보여 준다
        clips[action] = (frames + hold, spec["fps"])
        path = out_dir / f"03_{name}_{action}.gif"
        (frames + hold)[0].save(path, save_all=True, append_images=(frames + hold)[1:], duration=round(1000 / spec["fps"]), loop=0)
        print(path.relative_to(ROOT).as_posix())
    # 모든 동작을 한 줄로: 12fps 기준으로 2초씩 반복
    n = 24
    strip = []
    for t in range(n):
        row = Image.new("RGB", (SIZE * len(clips), SIZE), GRASS)
        for k, (frames, fps) in enumerate(clips.values()):
            row.paste(frames[int(t * fps / 12) % len(frames)], (k * SIZE, 0))
        strip.append(row)
    path = out_dir / f"03_{name}_all.gif"
    strip[0].save(path, save_all=True, append_images=strip[1:], duration=round(1000 / 12), loop=0)
    print(path.relative_to(ROOT).as_posix())


if __name__ == "__main__":
    main()
