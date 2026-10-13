"""렌더한 프레임을 동작별 가로 한 줄 스프라이트 시트로 묶고 메타데이터 JSON을 쓴다 (plan.md 3-4).

    python tools/pack_sheets.py fox

읽는 것  art/render/<캐릭터>/<동작>/0001.png …, tools/rigs/<캐릭터>.json
만드는 것 assets/images/<캐릭터>/<동작>.png, assets/images/<캐릭터>/<캐릭터>.json

JSON (게임이 읽음)
  frame   [너비, 높이]         한 프레임 크기 (px)
  anchor  [x, y]              프레임 안의 발 위치 → 칸 바닥에 맞춘다
  muzzle  [x, y]              (있으면) 이벤트가 일어나는 위치: 여우불 발사점, 다람쥐 도토리가 튀어나오는 곳 …
                              리그의 muzzle_part 부위 기준점 (없으면 flame 부위)
  actions.<동작>              frames, fps, loop, event(이 프레임에서 발사·생산·피해)
"""
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    name = sys.argv[1] if len(sys.argv) == 2 else sys.exit(__doc__)
    rig = json.loads((ROOT / "tools" / "rigs" / f"{name}.json").read_text(encoding="utf-8"))
    left, top, right, bottom = rig["canvas"]["box"]
    scale = rig["canvas"]["frame_px"] / max(right - left, bottom - top)

    def to_frame(p: list[float]) -> list[float]:
        return [round((p[0] - left) * scale, 1), round((p[1] - top) * scale, 1)]

    parts = {p["name"]: p for p in rig["parts"]}
    out_dir = ROOT / "assets" / "images" / name
    out_dir.mkdir(parents=True, exist_ok=True)
    meta = {"character": name, "anchor": to_frame(parts["body"]["pivot"]), "actions": {}}
    muzzle = rig.get("muzzle_part", "flame")
    if muzzle in parts:
        meta["muzzle"] = to_frame(parts[muzzle]["pivot"])

    for action, spec in rig["actions"].items():
        frames = sorted((ROOT / "art" / "render" / name / action).glob("*.png"))
        if len(frames) != spec["frames"]:
            sys.exit(f"{action}: 프레임 {len(frames)}장, 리그에는 {spec['frames']}장 (Blender 렌더를 먼저)")
        imgs = [Image.open(f).convert("RGBA") for f in frames]
        w, h = imgs[0].size
        sheet = Image.new("RGBA", (w * len(imgs), h))
        for i, im in enumerate(imgs):
            sheet.paste(im, (i * w, 0))
        sheet.save(out_dir / f"{action}.png", optimize=True)
        meta["frame"] = [w, h]
        meta["actions"][action] = {k: spec[k] for k in ("frames", "fps", "loop", "event") if k in spec}
        print(f"{name}/{action}.png  {sheet.width}×{sheet.height}  {(out_dir / f'{action}.png').stat().st_size / 1024:,.0f} KB")

    (out_dir / f"{name}.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"{name}/{name}.json  anchor {meta['anchor']}  muzzle {meta.get('muzzle')}")


if __name__ == "__main__":
    main()
