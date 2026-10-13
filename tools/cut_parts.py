"""기준 그림을 리그 파일(tools/rigs/<캐릭터>.json)대로 부위 조각으로 자른다 (컷아웃, plan.md 3단계).

    python tools/cut_parts.py fox

결과
  art/parts/<캐릭터>/<부위>.png   부위 조각 (여백을 잘라낸 크기)
  art/parts/<캐릭터>/rig.json     조각 위치·기준점·부모·그리는 순서 (Blender 스크립트가 읽음)
  art/parts/<캐릭터>/_overlay.png 부위별 색칠 확인 그림 (git 제외)
  art/parts/<캐릭터>/_rebuild.png 조각을 다시 합친 그림 — 기준 그림과 같아야 한다 (git 제외)

규칙
  - 알파 정리: 16 미만 → 0, 200 이상 → 255 (Codex 그림의 옅은 점과 반투명 몸통 정리, WORKLOG 3-a)
  - 픽셀은 그 위치를 다각형에 포함하는 가장 앞 부위가 가진다
  - color_key "flame": 다각형 안에서 채도 높은 주황·노랑 픽셀 + 그 테두리 안쪽(밝은 불꽃 속)을 불꽃으로 본다.
    불꽃 속(253,253,222)과 앞발 크림색(253,247,232)은 색이 거의 같아서 색만으로는 못 나눈다
  - 다각형 경계에서 떨어져 나온 작은 섬(부위 픽셀의 2% 미만)은 가장 많이 맞닿은 부위에 넘긴다
  - 뒤 부위는 앞 부위에 가려진 곳을 fill_band 너비까지, 가려진 곳 바로 옆 그 부위 털 색(외곽선 뺀 중앙값)으로 채운다.
    단 캐릭터 전체 실루엣의 바깥 테두리에서 INSET px 안쪽만 채운다.
    움직일 때 틈으로 살짝 보이는 곳이라 무늬를 흉내 내는 것보다 깨끗한 단색이 낫다
"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
INSET = 30  # 채움이 전체 실루엣 바깥 테두리에서 떨어져야 하는 거리 (px)
COLORS = [(255, 80, 80), (80, 200, 255), (120, 220, 90), (255, 200, 60), (200, 120, 255), (255, 140, 200)]


def polygon_mask(size: tuple[int, int], polygon: list) -> np.ndarray:
    img = Image.new("L", size, 0)
    ImageDraw.Draw(img).polygon([tuple(p) for p in polygon], fill=255)
    return np.array(img) > 0


def flame_key(rgb: np.ndarray, region: np.ndarray) -> np.ndarray:
    hsv = cv2.cvtColor(np.ascontiguousarray(rgb), cv2.COLOR_RGB2HSV)
    ring = region & (hsv[..., 1] > 80) & (hsv[..., 2] > 110) & (hsv[..., 0] <= 35)
    contours, _ = cv2.findContours(ring.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    filled = np.zeros(ring.shape, np.uint8)
    cv2.drawContours(filled, contours, -1, 1, thickness=cv2.FILLED)
    return filled > 0


def reassign_islands(owner: np.ndarray, count: int) -> int:
    """부위마다 작은 섬을 떼어 가장 많이 맞닿은 다른 부위에 준다. 옮긴 픽셀 수를 돌려준다."""
    moved = 0
    kernel = np.ones((3, 3), np.uint8)
    for i in range(count):
        mask = (owner == i).astype(np.uint8)
        n, labels, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
        if n <= 2:
            continue
        limit = 0.02 * mask.sum()
        for k in range(1, n):
            if stats[k, cv2.CC_STAT_AREA] >= limit:
                continue
            island = labels == k
            ring = (cv2.dilate(island.astype(np.uint8), kernel) > 0) & ~island
            neighbours = owner[ring]
            neighbours = neighbours[(neighbours >= 0) & (neighbours != i)]
            if neighbours.size:
                owner[island] = np.bincount(neighbours).argmax()
                moved += int(island.sum())
    return moved


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    name = sys.argv[1] if len(sys.argv) == 2 else sys.exit(__doc__)
    rig = json.loads((ROOT / "tools" / "rigs" / f"{name}.json").read_text(encoding="utf-8"))
    src = Image.open(ROOT / rig["ref"]).convert("RGBA")
    rgba = np.array(src)
    alpha = rgba[..., 3]
    alpha[:] = np.where(alpha < 16, 0, np.where(alpha >= 200, 255, alpha))
    rgb = rgba[..., :3]
    size = src.size
    solid = alpha > 0

    # 1) 각 픽셀의 주인 부위 정하기 (앞 부위 우선)
    owner = np.full(alpha.shape, -1, dtype=int)
    polys = []
    for i, part in enumerate(rig["parts"]):
        poly = polygon_mask(size, part["polygon"])
        polys.append(poly)
        mine = poly & solid & (owner < 0)
        if part.get("color_key") == "flame":
            mine &= flame_key(rgb, poly)
        owner[mine] = i
    moved = reassign_islands(owner, len(rig["parts"]))
    orphan = solid & (owner < 0)

    out_dir = ROOT / "art" / "parts" / name
    out_dir.mkdir(parents=True, exist_ok=True)
    rebuild = Image.new("RGBA", size, (0, 0, 0, 0))
    overlay = np.zeros_like(rgba)
    meta = {"character": name, "ref_size": list(size), "parts": []}

    # 2) 부위 조각 만들기. 그리는 순서는 뒤 → 앞이므로 거꾸로 돈다.
    inset = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * INSET + 1, 2 * INSET + 1))
    inner = cv2.erode(solid.astype(np.uint8), inset) > 0
    for i in reversed(range(len(rig["parts"]))):
        part = rig["parts"][i]
        own = owner == i
        piece = np.zeros_like(rgba)
        piece[own] = rgba[own]

        band = part.get("fill_band", 0)
        if band:
            # 앞 부위에 가려진 곳 중 내 영역 가장자리에서 band 안쪽만 채운다
            kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * band + 1, 2 * band + 1))
            grown = cv2.dilate(own.astype(np.uint8), kernel) > 0
            # 캐릭터 바깥 테두리 근처까지 채우면 움직일 때 테두리 없는 흰 띠가 바깥으로 삐져나온다 (WORKLOG 3-b).
            # 전체 실루엣을 INSET px 줄인 안쪽에만 채운다.
            hidden = grown & inner & polys[i] & solid & (owner >= 0) & (owner < i)
            if hidden.any():
                # 채움 색은 가려진 곳 바로 옆 내 털 색 (외곽선 제외). 흰 여우는 흰색, 주황 다람쥐 꼬리는 주황 (WORKLOG 3-c)
                near = cv2.dilate(hidden.astype(np.uint8), kernel) > 0
                fur = rgba[own & near & (alpha == 255)][:, :3]
                fur = fur[fur.astype(int).sum(axis=1) > 3 * 110]
                if len(fur) < 50:
                    fur = rgba[own & (alpha == 255)][:, :3]
                piece[hidden, :3] = np.median(fur, axis=0).astype(np.uint8)
                piece[hidden, 3] = 255

        ys, xs = np.nonzero(piece[..., 3])
        x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
        Image.fromarray(piece[y0:y1, x0:x1]).save(out_dir / f"{part['name']}.png")
        meta["parts"].insert(0, {
            "name": part["name"],
            "parent": part["parent"],
            "pivot": part["pivot"],
            "offset": [int(x0), int(y0)],
            "size": [int(x1 - x0), int(y1 - y0)],
            "z": len(rig["parts"]) - 1 - i,
            "pixels": int(own.sum()),
            "filled": int((piece[..., 3] > 0).sum() - own.sum()),
        })
        rebuild.alpha_composite(Image.fromarray(piece))
        overlay[own, :3] = COLORS[i % len(COLORS)]
        overlay[own, 3] = 255

    (out_dir / "rig.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")

    # 3) 확인 그림: 반은 원본, 반은 부위 색 + 기준점
    over = Image.alpha_composite(src.copy(), Image.fromarray(overlay).point(lambda v: v * 0.55 if v else 0))
    d = ImageDraw.Draw(over)
    for part in rig["parts"]:
        x, y = part["pivot"]
        d.ellipse([x - 12, y - 12, x + 12, y + 12], outline=(0, 0, 0, 255), width=4)
        d.text((x + 16, y - 8), part["name"], fill=(0, 0, 0, 255))
    over.save(out_dir / "_overlay.png")
    rebuild.save(out_dir / "_rebuild.png")

    diff = np.abs(np.array(rebuild).astype(int) - rgba.astype(int)).max(axis=2)
    for p in meta["parts"]:
        print(f"{p['name']:6} {p['size'][0]:4}×{p['size'][1]:<4} 픽셀 {p['pixels']:7,} 채움 {p['filled']:6,}")
    exact = solid & (alpha == 255)
    print(f"주인 없는 픽셀 {int(orphan.sum()):,} · 섬 정리로 옮긴 픽셀 {moved:,} · "
          f"다시 합친 그림이 원본과 다른 불투명 픽셀 {int((diff[exact] > 2).sum()):,}")


if __name__ == "__main__":
    main()
