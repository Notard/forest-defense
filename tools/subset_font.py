"""Gaegu Bold 원본(약 3 MB)에서 게임에 필요한 글자만 남겨 assets/fonts/에 저장한다.

Gaegu는 원래 한글 2,350자(KS X 1001 완성형)만 들어 있고 손글씨라 글자 하나가 무겁다.
그래서 2,350자를 다 남기면 거의 줄지 않는다 (2,893 KB → 2,891 KB, WORKLOG 2-1).
기본값은 게임에 실제로 쓰는 글자만 남긴다.

남기는 글자 (기본)
  1. lib/ 아래 .dart 파일의 문자열에 쓰인 한글·기호 전부
  2. 영문·숫자·기본 기호 (U+0020~U+007E)와 게임에 쓸 만한 몇몇 기호
`--all-hangul`을 붙이면 한글 2,350자와 호환 자모(ㄱ~ㅣ)도 모두 남긴다.

문구를 바꾸면 이 스크립트를 다시 돌려야 한다. 빠뜨리면 test/font_coverage_test.dart가 실패한다.

원본 폰트는 저장소에 넣지 않는다 (WORKLOG 2-1 참고). 받는 곳:
  https://github.com/google/fonts/tree/main/ofl/gaegu  (Gaegu-Bold.ttf, OFL.txt)

    pip install fonttools
    python tools/subset_font.py <원본 Gaegu-Bold.ttf 경로> [--all-hangul]
"""
import re
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "fonts" / "Gaegu-Bold.ttf"

EXTRA_SYMBOLS = "·…—–‘’“”×÷←↑→↓★☆♥♡♪○●◎△▲▽▼□■※～！？"


def ks_x_1001_hangul() -> set[str]:
    chars = set()
    for cp in range(0xAC00, 0xD7A4):
        ch = chr(cp)
        try:
            ch.encode("euc_kr")
        except UnicodeEncodeError:
            continue
        chars.add(ch)
    return chars


def used_in_code() -> set[str]:
    chars = set()
    for path in (ROOT / "lib").rglob("*.dart"):
        text = path.read_text(encoding="utf-8")
        # 주석은 빼고 문자열 안의 글자만 모은다.
        text = re.sub(r"//.*", "", text)
        for literal in re.findall(r"'([^'\n]*)'|\"([^\"\n]*)\"", text):
            for ch in "".join(literal):
                if ord(ch) > 0x7E:
                    chars.add(ch)
    return chars


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    all_hangul = "--all-hangul" in sys.argv
    if len(args) != 1:
        sys.exit(__doc__)
    src = Path(args[0])

    hangul = ks_x_1001_hangul() if all_hangul else set()
    jamo = {chr(cp) for cp in range(0x3131, 0x3164)} if all_hangul else set()
    ascii_ = {chr(cp) for cp in range(0x20, 0x7F)}
    code = used_in_code()
    wanted = hangul | jamo | ascii_ | set(EXTRA_SYMBOLS) | code

    font = TTFont(src)
    cmap = font.getBestCmap()
    missing = sorted(ch for ch in wanted if ord(ch) not in cmap)
    missing_in_code = sorted(ch for ch in code if ord(ch) not in cmap)
    if missing_in_code:
        sys.exit(f"게임 코드에 쓰인 글자가 원본 폰트에 없음: {''.join(missing_in_code)}")

    options = subset.Options()
    options.layout_features = ["*"]  # 커닝 등 배치 정보 유지
    options.name_IDs = ["*"]  # 폰트 이름·저작권 표기 유지
    options.notdef_outline = True
    options.drop_tables += ["DSIG"]  # 수정하면 서명이 무효가 되므로 뺀다
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=[ord(ch) for ch in wanted if ord(ch) in cmap])
    subsetter.subset(font)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    font.save(OUT)

    kept = len(TTFont(OUT).getBestCmap())
    print(f"원본 {src.stat().st_size / 1024:,.0f} KB → {OUT.relative_to(ROOT)} {OUT.stat().st_size / 1024:,.0f} KB")
    extra = " · 한글 2,350자 전부" if all_hangul else ""
    print(f"글자 {len(cmap):,}개 → {kept:,}개 (코드에서 {len(code)}개{extra} · 원본에 없어 뺀 기호 {len(missing)}개: {''.join(missing)})")


if __name__ == "__main__":
    main()
