# 작업 기록 — 숲 지키기 디펜스

> 단계별 결과, 검증, 문제와 해결, 결정 이유를 기록한다. 체크리스트: [TODO.md](TODO.md) · 계획: [plan.md](plan.md)

## 0. 기획 (2026-10-13)

### 결정과 이유

| 항목 | 결정 | 이유 |
|---|---|---|
| 엔진 | Flutter + Flame | 사용자 제안. Flutter가 이미 설치돼 있고, Flame에 그리드 배치·충돌·스프라이트 기능이 있어 2D 레인 디펜스에 맞는다. 한 코드로 Windows·웹·Android를 낸다 |
| 그래픽 | 2D 카툰 스프라이트, Codex 생성 | 원작 느낌에 가장 가깝다. 앱 아이콘 때 쓴 Codex CLI 흐름을 다시 쓴다 |
| 테마 | 동물 vs 귀여운 슬라임·정령 | 지난 프로젝트의 흰 여우를 이어 쓸 수 있고, 밝은 톤을 유지한다 |
| 자원 | 도토리 (떨어짐 + 다람쥐 생산, 클릭으로 줍기) | 원작의 햇빛 방식 그대로 |
| 유닛 | 다람쥐·여우·거북이·스컨크 4종 | 역할 네 가지를 모두 원했지만 후보가 6종이라 작은 데모 범위에 맞게 줄였다. 고슴도치·부엉이는 다음 단계 |
| 패배 규칙 | 레인별 통나무 1회 + 게임오버 | 원작의 잔디깎이 방식. 한 번의 실수는 만회할 수 있다 |
| 사운드 | 효과음만 | 데모 범위. 파이썬 합성으로 외부 음원 라이선스 문제를 피한다 |
| 진행 방식 | 여우 게임과 같게 (plan/TODO/WORKLOG, 단계별 미리보기) | 사용자 선택 |
| Git LFS | 쓰지 않음 | 스프라이트가 작은 PNG라 용량 부담이 없고, 웹 빌드를 GitHub Pages로 낼 때 LFS 파일은 서비스되지 않는다 |
| 공개 | PWA(GitHub Pages) + Microsoft Store (2026-10-13 추가) | 사용자 요청. Store에는 PWA를 포장하지 않고 네이티브 Windows 빌드를 MSIX로 낸다. 더 빠르고, 오프라인 실행과 효과음 재생이 브라우저 정책에 묶이지 않는다. PWA는 설치 없이 링크만으로 해볼 수 있는 통로로 둔다 |
| 경로 | `C:\forest_defense` | `C:\sample`은 여우 게임 저장소. Flutter 패키지 이름은 소문자와 밑줄만 쓸 수 있다 |

## 1. 프로젝트 생성 (2026-10-13)

### 결과 요약

| 항목 | 내용 |
|---|---|
| 프로젝트 | `C:\forest_defense`, `flutter create --platforms=windows,web,android --org com.notard` |
| 패키지 | flame 1.38.2, flame_audio 2.12.2, flame_test(개발용) |
| 게임 루트 | `lib/game/forest_game.dart` — `CameraComponent.withFixedResolution(1280, 720)`, 뷰파인더 앵커 왼쪽 위 |
| 수치 | `lib/game/config.dart`에 모음 |

### 검증
- `flutter analyze` 문제 없음, `flutter test` 1/1 통과 (카메라 해상도·앵커)
- `flutter build windows` → exe 실행 후 6초 동안 창이 유지됨
- `flutter build web` → 브라우저 패널(4:3)에서 16:9 필드와 위아래 레터박스 확인, 콘솔 에러 없음

### 문제와 해결
- 세션 폴더를 옮겨도 미리보기 서버는 `C:\sample\.claude\launch.json`을 읽었다. 그 파일은 git에서 제외된 로컬 파일이라 `forest-web`(8766, `build/web`)과 `forest-docs`(8767) 설정을 추가했다

## 1-1. Git 저장소 (2026-10-13)

- 사용자 승인 후 `gh repo create Notard/forest-defense --public`으로 만들고 `main`을 push했다 → https://github.com/Notard/forest-defense
- Public으로 한 이유: GitHub Pages(PWA 공개 예정)는 무료 계정에서 Public 저장소만 지원한다

## 2. 화면과 그리드 (2026-10-13)

### 결과 요약

| 파일 | 역할 |
|---|---|
| `lib/game/config.dart` | 칸 크기(100 × 110), 필드 위치(140, 110), 통나무 열, 등장 x, 색을 한곳에 모음 |
| `lib/game/grid.dart` | `Cell`(row, col) 레코드, `cellAt`(화면 → 칸), `topLeft`·`center`(칸 → 화면), `laneCenterY`, `allCells` |
| `lib/game/components/lane_background.dart` | 임시 배경: 둥지, 잔디 체크무늬, 등장 흙길, 레인 구분선 |
| `lib/game/components/field.dart` | 필드 입력: 마우스 올림 → 칸 밝게, 탭/클릭 → 노란 테두리 + `onCellTap` 콜백 |
| `lib/game/hud/hud_placeholder.dart` | HUD 슬롯 자리와 진행 바 자리, 슬롯 위치 상수 `HudLayout` |
| `preview.html`, `preview/02_*.jpg` | 세 화면 비율 캡처 |
| `README.md` | Flutter 템플릿 문구를 프로젝트 소개·실행 방법·구조·문서 목록으로 교체 |

### 진행 방식
- 좌표 변환은 Flame 컴포넌트와 분리된 순수 함수(`Grid`)로 만들어 단위 테스트를 먼저 붙였다. 4단계 배치, 6단계 몬스터 이동이 모두 이 함수를 쓴다
- 입력은 `TapCallbacks`(마우스 클릭과 터치 공통)와 `PointerMoveCallbacks`(마우스 올림)를 쓴다. 터치에는 올림이 없으므로 탭한 칸을 `selectedCell`로 남겨 눌린 칸이 보이게 했다
- 카메라가 고정이라 HUD를 따로 뷰포트 레이어에 두지 않고 월드에 우선순위(`priority`)로 겹쳤다. 화면 흔들림 같은 연출을 넣게 되면 그때 뷰포트로 옮긴다
- 진행 바를 오른쪽 아래로 옮겼다 (plan.md 2-1에 이유 기록)

### 검증
- `flutter analyze` 문제 없음
- `flutter test` **10/10** 통과
  - `grid_test.dart` 7개: 필드 모서리, 칸 경계가 오른쪽·아래 칸에 속하는지, 필드 밖 5곳(둥지·HUD·등장 구역·진행 바·음수), 칸 가운데 좌표, 레인 y, 45칸 전부 `center → cellAt` 왕복
  - `field_test.dart` 2개: 800 × 600 위젯 테스트 화면(4:3, 위아래 75px 레터박스)에서 실제로 탭해 칸 3곳이 맞게 선택되는지, HUD·둥지·등장 구역·레터박스를 탭하면 선택이 바뀌지 않는지
  - `forest_game_test.dart` 1개: 카메라 고정 해상도와 앵커
- 브라우저(웹 릴리스 빌드)에서 세 비율을 직접 확인, 콘솔 에러 없음

| 비율 | 창 크기 | 레터박스 | 확인 |
|---|---|---|---|
| 16:9 | 1280 × 720 | 없음 | (2, 4) 칸 올림 강조, (3, 6) 칸 클릭 선택 |
| 4:3 | 1024 × 768 | 위아래 | 창 크기를 바꾼 뒤에도 강조 위치 유지, (0, 8) 칸 클릭 선택 |
| 19.5:9 | 1560 × 720 | 양옆 | (4, 0) 칸 클릭 선택 |

### 발생한 문제와 해결
1. **테스트에서 `game.size`가 800 × 600이 아니라 1280 × 720이었다.** 고정 해상도 카메라를 쓰면 `FlameGame.size`가 가상 해상도를 돌려준다. 실제 화면 크기는 `canvasSize`로 확인하도록 고쳤다
2. **위젯 테스트가 "Pending timers"로 실패했다.** Flame의 탭 인식기(`MultiTapGestureRecognizer`)가 탭마다 40ms 타이머를 만든다. 탭 뒤에 `tester.pump(100ms)`로 시간을 흘려 해결했다
3. **브라우저 크기 흉내를 처음 켰을 때 화면이 2배로 확대돼 보였다.** 그 순간 기기 픽셀 비율이 1에서 2로 바뀌었는데 캔버스가 따라가지 않았다. 새로 고침하면 정상이었고, 그 뒤 일반적인 창 크기 변경(16:9 → 4:3 → 19.5:9)은 새로 고침 없이 정상이었다. 실제로는 배율이 다른 모니터로 창을 옮길 때 생길 수 있으므로 **9단계에서 다시 확인**한다
4. 브라우저 탭 제목이 로딩 중에 `forest_defense`로 보인다 (`web/index.html`의 `<title>`). 10단계에서 매니페스트를 정리할 때 함께 고친다

## 2-1. 한글 폰트: Gaegu Bold (2026-10-13)

### 왜 폰트를 넣는가
웹 빌드(CanvasKit)는 한글 글꼴이 없으면 Google 서버에서 Noto 폰트를 받아와 대신 쓴다. 오프라인 PWA에서는 그 요청이 실패해 한글이 깨지므로 폰트를 게임 안에 넣는다.

### 결정 경과

| 순서 | 내용 |
|---|---|
| 1 | 후보 3종을 실제 게임 문구로 비교하는 [font_preview.html](font_preview.html)을 만들었다 |
| 2 | 라이선스를 google/fonts 저장소의 OFL.txt 원문으로 확인: 셋 다 **SIL OFL 1.1**. 게임에 넣어 무료·유료 배포 가능, 조건은 라이선스 전문·저작권 표기 동봉과 폰트 단독 판매 금지 |
| 3 | 사용자가 Noto Sans KR을 골랐지만 원본이 **10.4 MB**라 Gaegu로 바꿨다 |
| 4 | Gaegu도 굵기당 약 3 MB라는 점을 알리고 방식을 다시 물었다 → **Bold 하나, 글자 줄이기**로 결정 |

### 결과 요약

| 항목 | 내용 |
|---|---|
| 원본 | `Gaegu-Bold.ttf` 2,893 KB, 글자 2,593개 (google/fonts `ofl/gaegu`). 저장소에는 넣지 않음 |
| 게임용 | `assets/fonts/Gaegu-Bold.ttf` **78 KB**, 글자 107개 + `assets/fonts/OFL.txt` |
| 남긴 글자 | `lib/` 문자열에 쓰인 한글·기호 + 영문·숫자·기본 기호 |
| 스크립트 | `python tools/subset_font.py <원본 경로> [--all-hangul]` |
| 문구 | `lib/game/strings.dart`에 모음. 지금은 `숲 지키기`, `웨이브 n / m` |
| 연결 | pubspec `fonts: Gaegu (weight 700)`, `GameConfig.fontFamily`, HUD 자리에 임시 글자(150, 웨이브 1 / 5) |

### 진행 방식
- 처음에는 자주 쓰는 한글 2,350자(KS X 1001)를 남기려 했다. 그런데 **Gaegu에는 원래 그 2,350자만 들어 있어서** 2,893 KB → 2,891 KB로 거의 줄지 않았다. 손글씨라 글자 하나의 윤곽 데이터가 크다(`glyf` 표가 파일의 99%)
- 그래서 게임에 실제로 쓰는 글자만 남기도록 바꿨다. 게임 문구는 정해져 있고 바뀌는 것은 숫자뿐이라 이 방식이 맞다. 2,350자가 다시 필요하면 `--all-hangul`을 쓴다
- 스크립트는 코드에 쓰인 글자가 원본 폰트에 없으면 멈춘다. 원본 Gaegu에는 `·`, `…`, `★`, `→` 같은 기호와 백틱(`)이 없어서 게임 문구에 쓰면 안 된다
- 원본 Gaegu에는 예약 폰트 이름(Reserved Font Name)이 없어 줄인 파일도 이름을 Gaegu로 둘 수 있다. 수정하면 무효가 되는 전자 서명 표(`DSIG`)만 뺐다

### 검증
- `flutter test` **13/13** 통과 (`font_coverage_test.dart` 3개 추가)
  - 영문·숫자(U+0020~007E, 백틱 제외)가 모두 있는지
  - `Strings`의 문구가 모두 있는지
  - `lib/` 아래 모든 `.dart` 문자열의 한글·기호가 폰트에 있는지. 폰트 파일의 `cmap` 표를 테스트가 직접 읽는다 (fonttools로 센 107자와 일치)
- 일부러 `title`을 `숲 지키기 다람쥐`로 바꾸자 두 테스트가 실패했고, 되돌린 뒤 통과했다
- 웹 빌드: `FontManifest.json`에 Gaegu 등록, 네트워크 요청은 로컬 `Gaegu-Bold.ttf` 하나뿐(Google 폰트 서버 요청 없음), 화면에 손글씨로 표시 → `preview/02-1_font.jpg`

### 발생한 문제와 해결
1. **2,350자 기준으로는 크기가 줄지 않았다** → 위 "진행 방식"대로 쓰는 글자만 남기는 방식으로 바꿨다
2. **스크립트 출력이 Windows 콘솔(cp949)에서 깨지고 `–` 같은 기호에서 멈췄다** → `sys.stdout.reconfigure(encoding="utf-8")`
3. **파이썬 3.11에서는 f-string 안에 같은 종류의 따옴표를 쓸 수 없어** 문법 오류가 났다 → 변수로 빼서 해결
4. **`dart:ui`와 `flutter/painting.dart`의 `TextStyle` 이름이 겹쳤다** → HUD 파일은 `flutter/painting.dart`만 쓰도록 정리
5. **테스트의 정규식을 raw 삼중 따옴표로 쓰다가 문자열이 닫히지 않았다** → 두 raw 문자열을 이어 붙이는 방식으로 바꿨다
