import 'difficulty.dart';
import 'monsters.dart';
import 'units.dart';
import 'upgrades.dart';

/// 화면 글의 언어 (16-2단계). 설정 창에서 고르고, 처음에는 기기 언어를 따른다 (한국어가 아니면 영어).
enum Lang { ko, en }

/// 화면에 나오는 모든 문구. 글자를 고칠 때는 여기만 바꾼다.
///
/// 한국어·영어 두 벌이고 [lang]에 따라 고른다 (16-2단계). 그래서 모두 `const`가 아닌 getter다.
///
/// 폰트(Gaegu Bold)는 필요한 글자만 남긴 파일이라, 새 문구를 넣으면
/// `python tools/subset_font.py <원본 경로>`로 폰트를 다시 만들어야 한다.
/// `test/font_coverage_test.dart`가 빠진 글자를 찾아 준다.
/// Gaegu에는 `·`, `…`, `★`, `→`, 둥근 따옴표 아닌 `’` 같은 기호가 없으니 쓰지 않는다.
abstract final class Strings {
  /// 지금 언어.
  static Lang lang = Lang.ko;
  static bool get ko => lang == Lang.ko;
  static String _t(String ko, String en) => lang == Lang.ko ? ko : en;

  static String get title => _t('숲 지키기', 'Forest Keepers');

  static String wave(int current, int total) => _t('웨이브 $current / $total', 'Wave $current / $total');

  /// 웨이브가 시작될 때 가운데에 잠깐 뜨는 글자.
  static String waveBanner(int number) => _t('웨이브 $number', 'Wave $number');

  /// 판 시작 뒤 첫 웨이브까지 줄어드는 막대 옆 글자 (14-2단계).
  static String get firstWaveIn => _t('몬스터가 오기까지', 'Monsters in');
  static String seconds(int s) => _t('$s초', '${s}s');

  /// 마지막 큰 무리 웨이브 경고.
  static String get bigWave => _t('숲이 술렁여요! 마지막 무리!', 'The forest stirs! Final wave!');

  /// 보스가 있는 마지막 웨이브 경고 (13단계).
  static String get bossWave => _t('슬라임 왕이 나타났어요!', 'The Slime King appears!');

  // ── 메인 화면·카운트다운 ──
  static String get subtitle => _t('숲속 친구들과 함께 둥지를 지켜요', 'Protect the nest with your forest friends');

  /// 휴대폰을 세워 들었을 때 게임 위에 덮는 글 (15단계).
  static String get rotate => _t('휴대폰을 가로로\n돌려 주세요', 'Please turn your\nphone sideways');

  // ── 난이도 (14-4단계) ──
  static String difficultyName(Difficulty d) => switch (d) {
        Difficulty.easy => _t('쉬움', 'Easy'),
        Difficulty.normal => _t('보통', 'Normal'),
        Difficulty.hard => _t('어려움', 'Hard'),
      };
  static String difficultyLine(Difficulty d) => _t('난이도: ${difficultyName(d)}', 'Difficulty: ${difficultyName(d)}');

  // ── 책 소개 (14-3단계) ──
  // 한국어 책이라 한국어 화면에서만 띠를 보인다 (16-2단계, 사용자 결정). 그래서 한 벌만.
  /// 메인 화면 아래 띠. Gaegu에 『』가 없어 “ ”를 쓴다.
  static const bookPromo = '“작고 쓸모 있는 코딩 딴짓” 저자가 만든 게임';
  static const bookMore = '책 보기';
  static const bookTitle = '작고 쓸모 있는 코딩 딴짓';
  static const bookLines = [
    '코덱스와 시작하는 10분 바이브 코딩 프로젝트 29',
    '권경열 지음, 한빛미디어',
    '이 게임을 만든 사람이 쓴 책이에요',
  ];
  static String get start => _t('게임 시작', 'Start');
  static String get go => _t('시작!', 'Go!');
  static String get toTitle => _t('처음으로', 'Title');

  // ── 숲 지도 ──
  static String get map => _t('숲 지도', 'Forest Map');
  static String get dayForest => _t('낮 숲', 'Day Forest');
  static String get nightForest => _t('밤 숲', 'Night Forest');
  static String get toMap => _t('지도로', 'Map');
  static String get next => _t('다음 스테이지', 'Next Stage');
  static String get shop => _t('강화 상점', 'Upgrades');
  static String pineconesGained(int n) => _t('솔방울 +$n', 'Pinecones +$n');
  static String pinecones(int n) => _t('솔방울 $n', 'Pinecones $n');
  static String totalStars(int n, int max) => _t('별 $n / $max', 'Stars $n / $max');
  static String newFriend(UnitType t) => _t('새 친구 ${unitName(t)}: ${unitAbility(t)}', 'New friend ${unitName(t)}: ${unitAbility(t)}');

  // ── 새 친구·처음 보는 몬스터 안내 (14단계) ──
  /// 새로 열린 카드에 붙는 꼬리표 (처음 놓을 때까지).
  static String get newTag => _t('새로!', 'NEW!');
  static String newFriendHint(UnitType t) => _t('새 친구 ${unitName(t)}!', 'New friend: ${unitName(t)}!');

  /// 처음 보는 몬스터가 나오면 잠깐 멈추고 띄우는 창.
  static String get meetTitle => _t('처음 보는 몬스터!', 'A new monster!');
  static String get gotIt => _t('알겠어요!', 'Got it!');
  static String meetLine(MonsterType m) => '${monsterName(m)}: ${monsterAbility(m)}';

  /// 처음 놓을 때 쓰는 요령 (카드 아래 말풍선).
  static String unitTip(UnitType t) => switch (t) {
        UnitType.squirrel => _t('첫 칸에 놓으면 도토리가 쑥쑥', 'Put it in the first column for acorns'),
        UnitType.fox => _t('몬스터가 오는 줄에 놓아요', 'Put it in a lane where monsters come'),
        UnitType.turtle => _t('앞쪽에 놓아 몬스터를 막아요', 'Put it up front to block monsters'),
        UnitType.skunk => _t('몬스터 바로 앞 칸에 놓으면 펑!', 'Put it right in front of monsters. Poof!'),
        UnitType.hedgehog => _t('앞쪽에 놓으면 깨문 몬스터가 따끔', 'Put it up front. Biters get poked!'),
        UnitType.owl => _t('박쥐나 골렘이 오는 줄에 놓아요', 'Put it where bats or golems come'),
        UnitType.bear => _t('앞쪽에 놓아 다가온 몬스터를 쾅!', 'Put it up front to smash monsters!'),
        UnitType.magpie => _t('첫 칸에 놓으면 위아래 줄 도토리까지', 'First column: grabs acorns from 3 lanes'),
      };

  /// 처음 보는 몬스터를 막는 요령.
  static String monsterTip(MonsterType m) => switch (m) {
        MonsterType.slime => _t('여우를 같은 줄에 놓아 막아요', 'Stop it with a fox in the same lane'),
        MonsterType.helmetSlime => _t('투구가 깨질 때까지 여러 번 맞혀요', 'Keep hitting until the helmet breaks'),
        MonsterType.wisp => _t('빠르니까 여우를 미리 놓아 두어요', 'It is fast! Place foxes early'),
        MonsterType.golem => _t('여우를 여럿 모으고 레벨업해요', 'Gather foxes and level them up'),
        MonsterType.bat => _t('뒤 칸에도 여우를 놓아 두어요', 'Keep a fox in the back too'),
        MonsterType.mushroom => _t('작은 버섯은 빨라요. 뒤에도 여우를!', 'Little ones are fast. Foxes in back!'),
        MonsterType.miniMushroom => _t('작지만 빨라요. 뒤에도 여우를!', 'Small but fast. Foxes in back!'),
        MonsterType.bossSlime => _t('여우를 레벨업하고 줄마다 모아요', 'Level up foxes in every lane'),
      };

  static String unitName(UnitType t) => switch (t) {
        UnitType.squirrel => _t('다람쥐', 'Squirrel'),
        UnitType.fox => _t('여우', 'Fox'),
        UnitType.turtle => _t('거북이', 'Turtle'),
        UnitType.skunk => _t('스컨크', 'Skunk'),
        UnitType.hedgehog => _t('고슴도치', 'Hedgehog'),
        UnitType.owl => _t('부엉이', 'Owl'),
        UnitType.bear => _t('곰', 'Bear'),
        UnitType.magpie => _t('까치', 'Magpie'),
      };

  // ── 도움말 (12-4단계) ──
  static String get help => _t('도움말', 'Help');

  /// 웹에서 홈 화면·바탕화면에 앱으로 설치 (16단계).
  static String get install => _t('앱으로 설치', 'Install app');
  static String get close => _t('닫기', 'Close');
  static String get helpHowTo => _t('놀이 방법', 'How to Play');
  static String get helpFriends => _t('친구들', 'Friends');
  static String get helpMonsters => _t('몬스터', 'Monsters');

  /// 놀이 방법: (제목, 설명) 일곱 줄. 아이콘 순서는 help_panel.dart와 같다.
  static List<(String, String)> get howTo => ko ? _howToKo : _howToEn;
  static const _howToKo = [
    ('도토리 모으기', '다람쥐, 몬스터, 둥지에서 나온 도토리를 눌러요. 까치는 대신 주워요'),
    ('친구 놓기', '위 카드를 고르고 잔디 칸을 눌러요. 카드마다 도토리가 들어요'),
    ('레벨업', '놓인 친구를 누르고 말풍선을 누르면 도토리로 Lv2, Lv3'),
    ('삽', '삽을 고르고 친구를 누르면 치워요. 도토리는 돌아오지 않아요'),
    ('둥지 하트', '몬스터가 둥지에 닿으면 하트가 하나 줄어요. 셋 다 잃으면 끝!'),
    ('별 세 개', '깨면 하나, 하트를 안 잃으면 하나, 친구를 안 잃으면 하나'),
    ('솔방울과 강화', '처음 얻는 별마다 솔방울. 지도의 강화 상점에서 친구를 세게'),
  ];
  static const _howToEn = [
    ('Collect acorns', 'Tap acorns from squirrels, monsters and the nest. Magpies help'),
    ('Place friends', 'Pick a card at the top, then tap a grass cell. Cards cost acorns'),
    ('Level up', 'Tap a placed friend, then the bubble, for Lv2 and Lv3'),
    ('Shovel', 'Pick the shovel and tap a friend to remove it. No refund'),
    ('Nest hearts', 'A monster at the nest takes a heart. Lose them all and it is over!'),
    ('Three stars', 'One for winning, one for no lost hearts, one for no lost friends'),
    ('Pinecones', 'You get them for new stars. Spend them in the upgrade shop'),
  ];

  /// 친구 능력 한 줄.
  static String unitAbility(UnitType t) => switch (t) {
        UnitType.squirrel => _t('도토리를 만들어요', 'Makes acorns'),
        UnitType.fox => _t('여우불을 쏴요', 'Shoots fox fire'),
        UnitType.turtle => _t('튼튼하게 막아요', 'Blocks the way'),
        UnitType.skunk => _t('앞쪽에 방귀 구름!', 'Stink cloud ahead!'),
        UnitType.hedgehog => _t('깨물면 가시로 콕', 'Bite it, get poked'),
        UnitType.owl => _t('줄 전체를 느리게', 'Slows the whole lane'),
        UnitType.bear => _t('앞 칸을 내려쳐요', 'Smashes the cell ahead'),
        UnitType.magpie => _t('도토리를 물어 와요', 'Fetches acorns'),
      };

  static String monsterName(MonsterType m) => switch (m) {
        MonsterType.slime => _t('슬라임', 'Slime'),
        MonsterType.helmetSlime => _t('투구 슬라임', 'Helmet Slime'),
        MonsterType.wisp => _t('도깨비불', 'Wisp'),
        MonsterType.golem => _t('돌 골렘', 'Stone Golem'),
        MonsterType.bat => _t('박쥐', 'Bat'),
        MonsterType.mushroom => _t('버섯 포자', 'Spore Shroom'),
        MonsterType.miniMushroom => _t('작은 버섯', 'Little Shroom'),
        MonsterType.bossSlime => _t('슬라임 왕', 'Slime King'),
      };

  static String monsterAbility(MonsterType m) => switch (m) {
        MonsterType.slime => _t('느릿느릿 다가와요', 'Creeps in slowly'),
        MonsterType.helmetSlime => _t('투구가 먼저 막아요', 'Its helmet takes hits'),
        MonsterType.wisp => _t('빠르게 둥실 와요', 'Floats in fast'),
        MonsterType.golem => _t('아주 단단해요', 'Very tough'),
        MonsterType.bat => _t('친구를 뛰어넘어요', 'Jumps over friends'),
        MonsterType.mushroom => _t('쓰러지면 둘이 돼요', 'Splits in two'),
        MonsterType.miniMushroom => _t('작지만 빨라요', 'Small but fast'),
        MonsterType.bossSlime => _t('슬라임을 불러내요', 'Calls in slimes'),
      };

  static const unknown = '???';
  static String meetAt(String stageId) => _t('$stageId에서 만나요', 'Meet in $stageId');

  // ── 강화 상점 (12단계) ──
  static String upgradeName(Upgrade u) => u.unit == null ? _t('시작 도토리', 'Start Acorns') : unitName(u.unit!);

  /// 한 단계마다 오르는 것.
  static String upgradeEffect(Upgrade u) => switch (u) {
        Upgrade.squirrel => _t('도토리 만들기 10% 빨리', 'Acorns 10% faster'),
        Upgrade.fox => _t('여우불 15% 세게', 'Fox fire 15% stronger'),
        Upgrade.turtle => _t('체력 25% 더', 'HP 25% more'),
        Upgrade.hedgehog => _t('가시 30% 세게', 'Spines 30% stronger'),
        Upgrade.skunk => _t('다시 놓기 15% 빨리', 'Ready 15% sooner'),
        Upgrade.owl => _t('느리게 하기 1초 더', 'Slow lasts 1s longer'),
        Upgrade.bear => _t('내려치기 20% 세게', 'Smash 20% stronger'),
        Upgrade.startAcorns => _t('도토리 25개 더 들고 시작', 'Start with 25 more acorns'),
      };
  static String get maxed => _t('다 올렸어요', 'Maxed out');
  static String unlockAt(String stageId) => _t('$stageId 깨면 열려요', 'Clear $stageId to unlock');
  static String get shopHint => _t('솔방울은 별을 처음 얻을 때 받아요', 'You get pinecones for new stars');

  // ── 결과·일시정지 화면 ──
  static String get cleared => _t('숲을 지켰어요!', 'Forest saved!');
  static String get gameOver => _t('둥지가 뚫렸어요', 'The nest was reached');
  static String get paused => _t('잠깐 쉬어요', 'Paused');
  static String get retry => _t('다시 하기', 'Retry');
  static String get resume => _t('계속하기', 'Resume');

  /// 결과 화면 아랫줄. 숫자만 바뀐다.
  static String result({required int defeated, required int hearts}) =>
      _t('쓰러뜨린 몬스터 $defeated마리, 남은 하트 $hearts개', 'Defeated $defeated, hearts left $hearts');

  // ── 설정 (16-2단계) ──
  static String get settings => _t('설정', 'Settings');
  static String get language => _t('언어', 'Language');

  /// 언어 이름은 늘 그 언어로 쓴다.
  static String langName(Lang l) => switch (l) {
        Lang.ko => '한국어',
        Lang.en => 'English',
      };
  static String get soundFx => _t('효과음', 'Sound');
  static String get music => _t('배경음악', 'Music');
  static String get on => _t('켜기', 'On');
  static String get off => _t('끄기', 'Off');
  static String get screen => _t('화면', 'Screen');
  static String get windowed => _t('창', 'Window');
  static String get fullscreen => _t('전체화면', 'Full');

  /// 플레이 기록 보내기 (16-4단계).
  static String get sendStats => _t('기록 보내기', 'Send stats');
  static String get privacy => _t('개인정보', 'Privacy');
}
