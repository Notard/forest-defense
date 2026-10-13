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
