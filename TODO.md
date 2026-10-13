# 할 일 목록 — 숲 지키기 디펜스

> 상세 내용: [plan.md](plan.md) · 작업이 끝날 때마다 `[ ]` → `[x]`로 체크하고 완료 날짜를 적는다.
> 체크 후 `python tools/make_todo_html.py` 실행 → 진행률 갱신 + [todo.html](todo.html) 재생성.
> 작업별 상세 결과: [WORKLOG.md](WORKLOG.md)

**진행률: 24 / 83**

---

## 0. 기획
- [x] 장르·엔진·테마·범위 결정 (Flutter + Flame, 동물 vs 슬라임, 작은 데모)
- [x] 유닛 4종 확정 (다람쥐·여우·거북이·스컨크), 고슴도치·부엉이는 다음으로
- [x] 계획서 [plan.md](plan.md) 작성

## 1. 프로젝트 생성
- [x] `C:\forest_defense`에 Flutter 프로젝트 생성 (windows · web · android)
- [x] `flame`, `flame_audio` 패키지 추가
- [x] `flame_test` 개발 의존성 추가
- [x] 폴더 구조 생성 (`lib/game`, `assets/images`, `assets/audio`, `tools`)
- [x] `main.dart`를 빈 `ForestGame`(1280×720 고정 카메라)으로 교체
- [x] Windows와 웹에서 빈 화면이 에러 없이 뜨는지 확인 ✅ 완료 기준

## 1-1. Git 저장소
- [x] `git init` (기본 브랜치 `main`), `.gitignore` 확인
- [x] 첫 커밋
- [x] GitHub 저장소 `Notard/forest-defense` 생성 후 push (사용자 확인 후) ✅ 완료 기준

## 2. 화면과 그리드
- [x] `config.dart`: 그리드 크기, 칸 크기, 필드 위치 상수
- [x] `grid.dart`: 칸 ↔ 화면 좌표 변환 + 단위 테스트
- [x] 임시 배경(레인 줄무늬)과 HUD·진행 바 자리 그리기
- [x] 마우스 올림/탭 시 칸 강조
- [x] 레터박스 확인 (16:9, 4:3, 19.5:9)
- [x] 미리보기: 웹 빌드 캡처 → [preview.html](preview.html) ✅ 완료 기준

## 2-1. 한글 폰트 (Gaegu Bold)
- [x] 후보 3종(Noto Sans KR · Jua · Gaegu) 비교 페이지 [font_preview.html](font_preview.html), 라이선스 확인 (모두 OFL 1.1)
- [x] Noto Sans KR(10.4 MB) 대신 Gaegu Bold 하나로 결정 (사용자)
- [x] `tools/subset_font.py`: 게임 코드에 쓰인 글자 + 영문·숫자·기호만 남기기 → 2,893 KB → 78 KB
- [x] `assets/fonts/`에 폰트와 `OFL.txt`, pubspec 등록, 문구는 `strings.dart`에 모음
- [x] HUD 자리에 임시 글자(도토리 수, 웨이브)로 웹 빌드 표시 확인
- [x] 빠진 글자 검사 테스트 `font_coverage_test.dart` (일부러 글자를 넣어 실패하는 것도 확인) ✅ 완료 기준

## 3. 아트 (Codex 생성)
- [ ] `tools/gen_art.sh`: 공통 스타일 프롬프트 + 스프라이트별 프롬프트
- [ ] 배경 `bg_forest.png` 생성
- [ ] 유닛 4종 생성 (다람쥐, 여우, 거북이, 스컨크)
- [ ] 몬스터 3종 생성 (슬라임, 투구 슬라임, 도깨비불)
- [ ] 소품 생성 (도토리, 여우불, 통나무, 폭발 구름, 카드 틀)
- [ ] `tools/prep_sprites.py`: 여백 자르기·크기 맞추기 → `assets/images/`
- [ ] 미리보기 [art_preview.html](art_preview.html), 사용자 톤 승인 ✅ 완료 기준

## 4. 자원과 유닛 배치
- [ ] 하늘에서 떨어지는 도토리 (주기, 수명, 줍기 애니메이션)
- [ ] HUD 도토리 수 표시 (시작 150)
- [ ] 카드 바: 비용, 쿨다운, 사용 불가 시 어둡게
- [ ] 카드 선택 → 빈 칸에 배치, 같은 칸 중복 금지
- [ ] 삽으로 유닛 제거
- [ ] 단위 테스트: 비용 차감, 쿨다운, 중복 배치 거부
- [ ] 미리보기 갱신, 네 유닛 모두 배치·제거 확인 ✅ 완료 기준

## 5. 유닛 능력
- [ ] 공통: 숨쉬기 트윈, 피격 깜빡임, HP
- [ ] 다람쥐: 도토리 생산
- [ ] 여우: 레인에 몬스터가 있을 때 여우불 발사
- [ ] 거북이: 높은 HP 방어벽
- [ ] 스컨크: 1.2초 뒤 3×3 폭발
- [ ] 단위 테스트: 생산 주기, 발사 조건, 폭발 범위 ✅ 완료 기준

## 6. 몬스터와 웨이브
- [ ] 공통: 통통 튀며 이동, 유닛 앞에서 멈추고 갉아먹기
- [ ] 슬라임 · 투구 슬라임(투구 깨짐) · 도깨비불
- [ ] `waves.dart`: 웨이브 5개 정의, "큰 무리" 경고
- [ ] 웨이브 진행 바
- [ ] 단위 테스트: 웨이브 순서, 투구 HP 처리
- [ ] 미리보기 갱신 ✅ 완료 기준

## 7. 전투·통나무·승패
- [ ] 여우불 ↔ 몬스터 충돌, 쓰러짐 연출
- [ ] 레인별 통나무 (1회)
- [ ] GAME OVER / CLEAR 화면, 다시 하기
- [ ] 일시정지 버튼
- [ ] 처음부터 끝까지 플레이: 승리와 패배 모두 확인 ✅ 완료 기준

## 8. 효과음
- [ ] `tools/make_sfx.py`: 효과음 11종 합성 → `assets/audio/`
- [ ] 사건별 재생 연결, 소리 켜기/끄기
- [ ] 웹에서 첫 클릭 이후 재생 확인 ✅ 완료 기준

## 9. 플랫폼 빌드
- [ ] 앱 이름 "숲 지키기", Codex 아이콘 원본 생성
- [ ] 아이콘 크기별 생성 (앱, 파비콘, PWA 192·512·마스커블)
- [ ] `tools/build_all.sh` (Windows · 웹 · APK)
- [ ] Windows exe 실행 확인
- [ ] 배율이 다른 모니터로 창을 옮겨도 화면이 확대되지 않는지 확인 (2단계 문제 3)
- [ ] Android APK 설치·터치 확인 (사용자 기기)
- [ ] 사용자 플레이 테스트 ✅ 완료 기준

## 10. 배포: PWA · Microsoft Store
- [ ] `web/manifest.json` 정리 (이름, fullscreen, 가로, scope `/forest-defense/`, 아이콘)
- [ ] `web/index.html` 제목·설명을 "숲 지키기"로 (2단계 문제 4)
- [ ] Flutter 3.44 기본 서비스 워커 여부 확인, 없으면 `tools/make_sw.py`로 오프라인 캐시 서비스 워커 생성
- [ ] 시작 화면 "앱으로 설치" 버튼 (지원 브라우저에서만)
- [ ] 로컬에서 매니페스트·서비스 워커·오프라인 새로 고침 확인
- [ ] GitHub Pages 배포 (사용자 확인 후)
- [ ] Edge·Chrome 데스크톱 설치, 안드로이드 홈 화면 추가 확인
- [ ] PWA 오프라인 플레이 확인 ✅ PWA 완료 기준
- [ ] `msix` 패키지 추가, `msix_config` 작성 (최소 권한)
- [ ] 테스트 인증서 MSIX 로컬 설치·실행·삭제 확인
- [ ] 개인정보 처리방침 페이지 (GitHub Pages)
- [ ] 스토어 등록 정보: 설명(한·영), 스크린샷 4장 이상, 키워드
- [ ] Partner Center 계정·앱 이름 예약 (사용자), Identity 값 반영
- [ ] 연령 등급(IARC) 설문 (사용자와 함께)
- [ ] `dart run msix:create --store` → 제출 (사용자)
- [ ] 인증 통과, Store에서 받은 앱 실행 확인 ✅ Store 완료 기준

## 11. 마무리
- [ ] README (소개, 플레이 GIF, 조작법, 빌드 방법, PWA 주소, Store 링크)
- [ ] 결과 보고서 REPORT.md ✅ 완료 기준

---

## 완료 기록

| 날짜 | 단계 | 메모 |
|---|---|---|
| 2026-10-13 | 0. 기획 | 질문으로 방향 결정, plan.md 작성 |
| 2026-10-13 | 계획 변경 | 10단계 배포(PWA · Microsoft Store) 추가, 마무리는 11단계로 |
| 2026-10-13 | 1. 프로젝트 생성 | Flame 1.38 빈 게임, Windows exe·웹 빌드 실행 확인, 테스트 1/1 |
| 2026-10-13 | 1-1. Git 저장소 | Public 저장소 Notard/forest-defense 생성, push |
| 2026-10-13 | 2. 화면과 그리드 | 좌표 변환·필드 입력·HUD 자리, 테스트 10/10, 세 비율 브라우저 확인 |
| 2026-10-13 | 2-1. 한글 폰트 | Gaegu Bold 78 KB, 빠진 글자 테스트, 테스트 13/13 |
