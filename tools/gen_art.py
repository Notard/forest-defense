"""Codex CLI의 이미지 생성 도구로 스프라이트 원본을 그린다 (Spriteflow 방식, plan.md 3-4).

    python tools/gen_art.py ref <캐릭터>             → art/ref/<캐릭터>.png   (기준 그림)
    python tools/gen_art.py action <캐릭터> <동작>   → art/raw/<캐릭터>_<동작>.png (프레임 격자, 컷아웃으로 바꾼 뒤 안 씀)
    python tools/gen_art.py prop <이름>              → art/ref/props/<이름>.png (효과·배경 정지 그림)

- 프롬프트는 tools/art_prompts.json에서 읽는다.
- 동작은 기준 그림을 `codex exec -i`로 함께 넣어 같은 캐릭터로 그리게 한다.
- Codex 출력은 logs/03_gen_<이름>.log에 남긴다.
- 필요: Codex CLI (`npm install -g @openai/codex`), ChatGPT 계정 로그인.
- 모델: 기본 `gpt-5.6-sol`. ChatGPT 계정 로그인에서는 지원하지 않는 모델이 있어(예: gpt-6.1-sol)
  ~/.codex/config.toml 기본값 대신 여기서 지정한다. 바꾸려면 환경 변수 CODEX_MODEL.
"""
import json
import math
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROMPTS = json.loads((ROOT / "tools" / "art_prompts.json").read_text(encoding="utf-8"))
LOGS = ROOT / "logs"
MODEL = os.environ.get("CODEX_MODEL", "gpt-5.6-sol")


def grid_shape(frames: int) -> tuple[int, int]:
    """프레임 수 → (열, 행). 한 줄에 4칸까지 둔다 (8 → 4×2, 6 → 3×2, 4 → 4×1)."""
    cols = min(4, frames) if frames != 6 else 3
    return cols, math.ceil(frames / cols)


def ref_images(name: str) -> list[Path]:
    """기준 그림에 함께 넣을 그림: based_on 캐릭터 그림, 아니면 여우 그림(그림체 참고)."""
    based = PROMPTS["characters"][name].get("based_on")
    if based:
        path = ROOT / "art" / "ref" / f"{based}.png"
        if not path.exists():
            sys.exit(f"{based} 기준 그림이 먼저 있어야 합니다")
        return [path]
    style = ROOT / "art" / "ref" / "fox.png"
    return [style] if name != "fox" and style.exists() else []


def ref_prompt(name: str) -> str:
    c = PROMPTS["characters"][name]
    if c.get("based_on"):
        guide = "The attached image is the existing character to edit. Keep everything identical except what the description asks to add."
    elif ref_images(name):
        guide = ("The attached image is ANOTHER character from the same game, given only as the art-style reference. "
                 "Match its art style exactly (outline color and thickness, cel shading, fur rendering, palette brightness, cuteness), "
                 "but draw the NEW character described below, not the fox.")
    else:
        guide = ""
    return "\n".join(line for line in [
        PROMPTS["style"],
        PROMPTS["background"],
        guide,
        f"Character: {c['description']}",
        "Draw exactly ONE character, full body, centered, filling about 80% of a square 1024x1024 canvas.",
        "This image is the master reference that the cutout animation is built from, so keep the design simple and readable at 128px, "
        "and keep limbs, tail and head clearly readable as separate shapes.",
    ] if line)


def action_prompt(name: str, action: str) -> str:
    c = PROMPTS["characters"][name]
    a = PROMPTS["actions"][name][action]
    cols, rows = grid_shape(a["frames"])
    return "\n".join([
        PROMPTS["style"],
        PROMPTS["background"],
        "The attached image is the master reference of the character. Copy its design EXACTLY in every frame: "
        "same proportions, same colors, same outline thickness, same size, same facing direction "
        f"({c['facing'].upper()}).",
        f"Character: {c['description']}",
        f"Animation: {a['prompt']}",
        f"Lay out {a['frames']} animation frames as a sprite sheet grid of {cols} columns x {rows} rows, "
        "read left-to-right then top-to-bottom. Every cell has the same size. "
        "In every cell the character is drawn at the same scale and its feet (or lowest point) sit on the same baseline "
        "near the bottom of the cell, horizontally centered. Leave clear empty space between cells; nothing may cross a cell border. "
        "No frame numbers, no grid lines, no labels.",
    ])


def run_codex(prompt: str, out: Path, images: list[Path], log_name: str) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    LOGS.mkdir(exist_ok=True)
    rel = out.relative_to(ROOT).as_posix()
    task = (
        "Use your built-in image generation tool to create exactly one image from the art brief below. "
        "Use the highest quality setting and a transparent background if the tool supports it. "
        f"Then save the generated image as a PNG file at `{rel}` inside this workspace (overwrite if it exists). "
        "Do not create or modify any other file. When done, reply with only the saved path.\n\n"
        "=== ART BRIEF ===\n" + prompt
    )
    cmd = ["codex", "exec", "-m", MODEL, "-C", str(ROOT), "-s", "workspace-write"]
    for img in images:
        cmd += ["-i", str(img)]
    # 프롬프트는 표준 입력으로 넘긴다. Windows의 codex.cmd는 여러 줄 인자를 첫 줄에서 잘라 버린다 (WORKLOG 3).
    cmd.append("-")
    codex = shutil.which("codex") or shutil.which("codex.cmd")
    if codex is None:
        sys.exit("codex CLI를 찾을 수 없습니다 (npm install -g @openai/codex)")
    cmd[0] = codex
    log = LOGS / f"03_gen_{log_name}.log"
    with log.open("w", encoding="utf-8") as f:
        f.write(task + "\n\n=== CODEX OUTPUT ===\n")
        f.flush()
        result = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT, input=task.encode("utf-8"))
    if result.returncode != 0 or not out.exists():
        sys.exit(f"생성 실패 (종료 코드 {result.returncode}). 로그: {log.relative_to(ROOT)}")
    print(f"{rel} 저장 ({out.stat().st_size / 1024:,.0f} KB), 로그: {log.relative_to(ROOT).as_posix()}")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    if len(args) == 2 and args[0] == "ref":
        name = args[1]
        run_codex(ref_prompt(name), ROOT / "art" / "ref" / f"{name}.png", ref_images(name), f"ref_{name}")
    elif len(args) == 3 and args[0] == "action":
        name, action = args[1], args[2]
        ref = ROOT / "art" / "ref" / f"{name}.png"
        if not ref.exists():
            sys.exit(f"기준 그림이 없습니다: {ref.relative_to(ROOT)} (먼저 ref {name})")
        run_codex(action_prompt(name, action), ROOT / "art" / "raw" / f"{name}_{action}.png", [ref], f"{name}_{action}")
    elif len(args) == 2 and args[0] == "prop":
        name = args[1]
        prop = PROMPTS["props"][name]
        style = ROOT / "art" / "ref" / "fox.png"
        lines = [PROMPTS["style"]]
        if not prop.get("opaque"):
            lines.append(PROMPTS["background"])
        lines += [
            "The attached image is a character from the same game, given only as the art-style reference. Match its style, do not draw the fox.",
            prop["prompt"],
        ]
        w, h = prop["size"]
        # 최종 크기를 알려 주면 Codex가 그 크기로 줄여 저장해 원본 해상도를 잃는다 (WORKLOG 3-g). 줄이기는 prep_props.py가 한다.
        lines.append("It will be shown small in the game, so keep shapes bold and readable. Save the image at full generated resolution; do not resize it."
                     if max(w, h) < 512 else "Use a wide 16:9 landscape canvas (for example 1536x864). Save at full generated resolution.")
        run_codex("\n".join(lines), ROOT / "art" / "ref" / "props" / f"{name}.png", [style], f"prop_{name}")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
