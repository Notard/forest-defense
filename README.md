# 🌰 숲 지키기 (Forest Keepers)

숲속 동물들이 레인을 따라 몰려오는 귀여운 슬라임·정령으로부터 숲을 지키는 2D 레인 디펜스 게임이에요.
도토리를 모아 다람쥐·여우·거북이·스컨크를 칸에 배치하고, 몬스터가 왼쪽 둥지에 닿지 못하게 막아요.

> **개발 중** — 6단계까지 끝났어요. 웨이브 5개 동안 몬스터가 몰려오고, 동물이 막아요. 다음은 7단계(통나무·승패)예요. 진행 상황은 [TODO.md](TODO.md)에서 볼 수 있어요.

| | |
|---|---|
| 엔진 | Flutter 3.44 + [Flame](https://flame-engine.org) 1.38 |
| 플랫폼 | Windows · 웹 · Android |
| 공개 예정 | PWA(GitHub Pages) · Microsoft Store |

![게임 화면: 다람쥐, 여우, 거북이, 스컨크를 놓은 모습](preview/04_place.jpg)

![여우 애니메이션: 기본, 공격, 피격, 쓰러짐](preview/03_fox_all.gif)

## 실행하기

Flutter 3.44 이상이 필요해요.

```bash
flutter pub get
```

```bash
flutter run -d windows
```

```bash
flutter run -d chrome
```

```bash
flutter test
```

확인용 주소 옵션 (웹 빌드):

- `?acorns=1000` 도토리 1000개로 시작
- `?practice=1` 레인마다 움직이지 않는 연습 상대 몬스터 (웨이브 없음)
- `?wave=5` 그 웨이브부터 시작
- `?speed=2` 게임 시계 배속 (1~4)
- 둘 다: `?acorns=1000&practice=1`

## 조작

- 위쪽 카드를 누르고 잔디 칸을 누르면 동물을 놓아요. 같은 카드를 다시 누르면 취소예요.
- 하늘에서 떨어지는 도토리를 눌러 모아요 (하나에 25개).
- 삽을 누르고 동물을 누르면 치워요 (도토리는 돌려받지 못해요).

## 폴더 구조

```
lib/
  main.dart                 앱 진입점 (GameWidget)
  game/
    forest_game.dart        게임 루트, 1280×720 고정 해상도 카메라
    config.dart             모든 수치 (칸 크기, 위치, 색, 폰트)
    strings.dart            화면에 나오는 모든 문구
    grid.dart               칸 ↔ 화면 좌표 변환
    components/             배경, 필드 입력, (예정) 유닛·몬스터·투사체
    hud/                    HUD (지금은 자리 표시)
test/                       좌표 변환·입력 경로·빠진 글자 테스트
assets/images/<캐릭터>/      동작별 스프라이트 시트(WebP) + <캐릭터>.json
assets/images/fx/           효과(도토리·통나무·연기·여우불·투구)와 배경
assets/fonts/               Gaegu Bold (게임에 쓰는 글자만 남긴 78 KB) + OFL.txt
tools/make_todo_html.py     TODO.md·WORKLOG.md → HTML
tools/subset_font.py        폰트에서 게임에 쓰는 글자만 남기기
tools/gen_art.py            Codex CLI로 캐릭터 기준 그림 그리기
tools/rigs/<캐릭터>.json     컷아웃 리그: 부위 자르는 선, 기준점, 동작 키프레임
tools/build_sprites.sh      기준 그림 → 부위 조각 → Blender 렌더 → 스프라이트 시트 → 미리보기
tools/prep_props.py         효과·배경 정지 그림 정리 (배경 잔디 줄무늬 지우기 포함)
art/ref/                    캐릭터 기준 그림
preview/                    단계별 캡처 (preview.html에서 모아 봄)
```

## 문서

| 문서 | 내용 |
|---|---|
| [plan.md](plan.md) | 개발 계획서: 레이아웃, 유닛·몬스터 수치, 단계별 완료 기준 |
| [TODO.md](TODO.md) | 체크리스트와 진행률 |
| [WORKLOG.md](WORKLOG.md) | 단계별 결과, 검증, 문제와 해결, 결정 이유 |
| [preview.html](preview.html) | 단계별 화면 캡처 |
| [art_preview.html](art_preview.html) | 스프라이트 시트를 실제 속도로 재생 |

## 문구를 바꿀 때

게임 폰트는 쓰는 글자만 남긴 파일이라, `lib/game/strings.dart`에 새 글자를 넣으면 폰트를 다시 만들어야 해요.
원본은 [google/fonts의 ofl/gaegu](https://github.com/google/fonts/tree/main/ofl/gaegu)에서 받아요. 다시 만들지 않으면 `flutter test`가 빠진 글자를 알려 줘요.

```bash
pip install fonttools
```

```bash
python tools/subset_font.py <원본 Gaegu-Bold.ttf 경로>
```

## 스프라이트 다시 만들기

캐릭터 기준 그림(`art/ref/`)과 리그(`tools/rigs/`)에서 스프라이트 시트를 다시 만들어요. [Blender](https://www.blender.org/) 5.2와 파이썬 `pillow`, `opencv-python`, `numpy`가 필요해요.

```bash
bash tools/build_sprites.sh fox
```

새 기준 그림은 [Codex CLI](https://github.com/openai/codex)(ChatGPT 계정 로그인)로 그려요.

```bash
python tools/gen_art.py ref fox
```

## 라이선스

- 폰트: [Gaegu](https://github.com/google/fonts/tree/main/ofl/gaegu) — Copyright 2018 The Gaegu Project Authors, SIL Open Font License 1.1 ([assets/fonts/OFL.txt](assets/fonts/OFL.txt))
