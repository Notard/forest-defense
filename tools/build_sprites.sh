#!/usr/bin/env bash
# 캐릭터 하나의 스프라이트 시트를 처음부터 다시 만든다 (2D 컷아웃, plan.md 3단계).
#   bash tools/build_sprites.sh fox
# 순서: 기준 그림 자르기 → Blender 렌더 → 시트 묶기 → art_preview.html
# 로그: logs/03_cutout_<캐릭터>.log
set -euo pipefail
cd "$(dirname "$0")/.."
NAME="${1:?캐릭터 이름 (예: fox)}"
BLENDER="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
mkdir -p logs

python tools/cut_parts.py "$NAME"
"$BLENDER" --background --python tools/blender_cutout.py -- "$NAME" > "logs/03_cutout_${NAME}.log" 2>&1 \
  || { echo "Blender 실패: logs/03_cutout_${NAME}.log"; exit 1; }
grep "\[cutout\]" "logs/03_cutout_${NAME}.log"
python tools/pack_sheets.py "$NAME"
python tools/make_art_preview.py
