import 'units.dart';

/// 화면에 나오는 모든 문구. 글자를 고칠 때는 여기만 바꾼다.
///
/// 폰트(Gaegu Bold)는 필요한 글자만 남긴 파일이라, 새 문구를 넣으면
/// `python tools/subset_font.py <원본 경로>`로 폰트를 다시 만들어야 한다.
/// `test/font_coverage_test.dart`가 빠진 글자를 찾아 준다.
/// Gaegu에는 `·`, `…`, `★`, `→` 같은 기호가 없으니 쓰지 않는다.
abstract final class Strings {
  static const title = '숲 지키기';

  static String wave(int current, int total) => '웨이브 $current / $total';

  /// 웨이브가 시작될 때 가운데에 잠깐 뜨는 글자.
  static String waveBanner(int number) => '웨이브 $number';

  /// 마지막 큰 무리 웨이브 경고.
  static const bigWave = '큰 무리가 몰려와요!';

  // ── 메인 화면·카운트다운 ──
  static const subtitle = '숲속 친구들과 함께 둥지를 지켜요';
  static const start = '게임 시작';
  static const go = '시작!';
  static const toTitle = '처음으로';

  // ── 숲 지도 ──
  static const map = '숲 지도';
  static const dayForest = '낮 숲';
  static const nightForest = '밤 숲';
  static const toMap = '지도로';
  static const next = '다음 스테이지';
  static const shop = '강화 상점';
  static String pineconesGained(int n) => '솔방울 +$n';
  static String pinecones(int n) => '솔방울 $n';
  static String totalStars(int n, int max) => '별 $n / $max';
  static String newFriend(UnitType t) => '새 친구: ${unitName(t)}!';

  static String unitName(UnitType t) => switch (t) {
        UnitType.squirrel => '다람쥐',
        UnitType.fox => '여우',
        UnitType.turtle => '거북이',
        UnitType.skunk => '스컨크',
        UnitType.hedgehog => '고슴도치',
        UnitType.owl => '부엉이',
        UnitType.bear => '곰',
      };

  // ── 결과·일시정지 화면 ──
  static const cleared = '숲을 지켰어요!';
  static const gameOver = '둥지가 뚫렸어요';
  static const paused = '잠깐 쉬어요';
  static const retry = '다시 하기';
  static const resume = '계속하기';

  /// 결과 화면 아랫줄. 숫자만 바뀐다.
  static String result({required int defeated, required int logsLeft}) =>
      '쓰러뜨린 몬스터 $defeated마리, 남은 통나무 $logsLeft개';
}
