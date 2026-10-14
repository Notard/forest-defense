import 'monsters.dart';
import 'units.dart';
import 'upgrades.dart';

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

  /// 판 시작 뒤 첫 웨이브까지 줄어드는 막대 옆 글자 (14-2단계).
  static const firstWaveIn = '몬스터가 오기까지';
  static String seconds(int s) => '$s초';

  /// 마지막 큰 무리 웨이브 경고.
  static const bigWave = '숲이 술렁여요! 마지막 무리!';

  /// 보스가 있는 마지막 웨이브 경고 (13단계).
  static const bossWave = '슬라임 왕이 나타났어요!';

  // ── 메인 화면·카운트다운 ──
  static const subtitle = '숲속 친구들과 함께 둥지를 지켜요';

  // ── 책 소개 (14-3단계) ──
  /// 메인 화면 아래 띠. Gaegu에 『』가 없어 “ ”를 쓴다.
  static const bookPromo = '“작고 쓸모 있는 코딩 딴짓” 저자가 만든 게임';
  static const bookMore = '책 보기';
  static const bookTitle = '작고 쓸모 있는 코딩 딴짓';
  static const bookLines = [
    '코덱스와 시작하는 10분 바이브 코딩 프로젝트 29',
    '권경열 지음, 한빛미디어',
    '이 게임을 만든 사람이 쓴 책이에요',
  ];
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
        UnitType.magpie => '까치',
      };

  // ── 도움말 (12-4단계) ──
  static const help = '도움말';

  /// 웹에서 홈 화면·바탕화면에 앱으로 설치 (16단계).
  static const install = '앱으로 설치';
  static const close = '닫기';
  static const helpHowTo = '놀이 방법';
  static const helpFriends = '친구들';
  static const helpMonsters = '몬스터';

  /// 놀이 방법: (제목, 설명) 여섯 줄. 아이콘 순서는 help_panel.dart와 같다.
  static const howTo = [
    ('도토리 모으기', '다람쥐, 몬스터, 둥지에서 나온 도토리를 눌러요. 까치는 대신 주워요'),
    ('친구 놓기', '위 카드를 고르고 잔디 칸을 눌러요. 카드마다 도토리가 들어요'),
    ('레벨업', '놓인 친구를 누르고 말풍선을 누르면 도토리로 Lv2, Lv3'),
    ('삽', '삽을 고르고 친구를 누르면 치워요. 도토리는 돌아오지 않아요'),
    ('둥지 하트', '몬스터가 둥지에 닿으면 하트가 하나 줄어요. 셋 다 잃으면 끝!'),
    ('별 세 개', '깨면 하나, 하트를 안 잃으면 하나, 친구를 안 잃으면 하나'),
    ('솔방울과 강화', '처음 얻는 별마다 솔방울. 지도의 강화 상점에서 친구를 세게'),
  ];

  /// 친구 능력 한 줄.
  static String unitAbility(UnitType t) => switch (t) {
        UnitType.squirrel => '도토리를 만들어요',
        UnitType.fox => '여우불을 쏴요',
        UnitType.turtle => '튼튼하게 막아요',
        UnitType.skunk => '앞쪽에 방귀 구름!',
        UnitType.hedgehog => '깨물면 가시로 콕',
        UnitType.owl => '줄 전체를 느리게',
        UnitType.bear => '앞 칸을 내려쳐요',
        UnitType.magpie => '도토리를 물어 와요',
      };

  static String monsterName(MonsterType m) => switch (m) {
        MonsterType.slime => '슬라임',
        MonsterType.helmetSlime => '투구 슬라임',
        MonsterType.wisp => '도깨비불',
        MonsterType.golem => '돌 골렘',
        MonsterType.bat => '박쥐',
        MonsterType.mushroom => '버섯 포자',
        MonsterType.miniMushroom => '작은 버섯',
        MonsterType.bossSlime => '슬라임 왕',
      };

  static String monsterAbility(MonsterType m) => switch (m) {
        MonsterType.slime => '느릿느릿 다가와요',
        MonsterType.helmetSlime => '투구가 먼저 막아요',
        MonsterType.wisp => '빠르게 둥실 와요',
        MonsterType.golem => '아주 단단해요',
        MonsterType.bat => '친구를 뛰어넘어요',
        MonsterType.mushroom => '쓰러지면 둘이 돼요',
        MonsterType.miniMushroom => '작지만 빨라요',
        MonsterType.bossSlime => '슬라임을 불러내요',
      };

  static const unknown = '???';
  static String meetAt(String stageId) => '$stageId에서 만나요';

  // ── 강화 상점 (12단계) ──
  static String upgradeName(Upgrade u) => u.unit == null ? '시작 도토리' : unitName(u.unit!);

  /// 한 단계마다 오르는 것.
  static String upgradeEffect(Upgrade u) => switch (u) {
        Upgrade.squirrel => '도토리 만들기 10% 빨리',
        Upgrade.fox => '여우불 15% 세게',
        Upgrade.turtle => '체력 25% 더',
        Upgrade.hedgehog => '가시 30% 세게',
        Upgrade.skunk => '다시 놓기 15% 빨리',
        Upgrade.owl => '느리게 하기 1초 더',
        Upgrade.bear => '내려치기 20% 세게',
        Upgrade.startAcorns => '도토리 25개 더 들고 시작',
      };
  static const maxed = '다 올렸어요';
  static String unlockAt(String stageId) => '$stageId 깨면 열려요';
  static const shopHint = '솔방울은 별을 처음 얻을 때 받아요';

  // ── 결과·일시정지 화면 ──
  static const cleared = '숲을 지켰어요!';
  static const gameOver = '둥지가 뚫렸어요';
  static const paused = '잠깐 쉬어요';
  static const retry = '다시 하기';
  static const resume = '계속하기';

  /// 결과 화면 아랫줄. 숫자만 바뀐다.
  static String result({required int defeated, required int hearts}) =>
      '쓰러뜨린 몬스터 $defeated마리, 남은 하트 $hearts개';
}
