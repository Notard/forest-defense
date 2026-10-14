/// 동물 유닛 종류와 수치 (plan.md 5단계 표). 조정할 때는 여기만 바꾸고 이유를 WORKLOG에 남긴다.
enum UnitType {
  squirrel(
    sheet: 'squirrel',
    cost: 50,
    cooldown: 7.5,
    maxHp: 300,
    displayHeight: 90,
  ),
  fox(
    sheet: 'fox',
    cost: 100,
    cooldown: 7.5,
    maxHp: 300,
    displayHeight: 96,
  ),
  turtle(
    sheet: 'turtle',
    cost: 50,
    cooldown: 30,
    maxHp: 4000,
    // 거북이는 옆으로 길어서 키를 낮춰야 칸 폭(96px)에 들어간다
    displayHeight: 72,
  ),
  skunk(
    sheet: 'skunk',
    cost: 150,
    cooldown: 50,
    maxHp: 300,
    displayHeight: 84,
  ),
  // ── 10단계: 새 친구 셋 ──
  hedgehog(
    sheet: 'hedgehog',
    cost: 75,
    cooldown: 25,
    maxHp: 2500,
    // 동그랗고 옆으로 넓다
    displayHeight: 70,
  ),
  owl(
    sheet: 'owl',
    cost: 125,
    cooldown: 15,
    maxHp: 300,
    displayHeight: 88,
  ),
  bear(
    sheet: 'bear',
    cost: 175,
    cooldown: 20,
    maxHp: 800,
    displayHeight: 100,
  ),
  // ── 14-1단계: 도토리를 물어 오는 친구 ──
  magpie(
    sheet: 'magpie',
    cost: 50,
    cooldown: 12,
    maxHp: 300,
    displayHeight: 84,
  );

  const UnitType({
    required this.sheet,
    required this.cost,
    required this.cooldown,
    required this.maxHp,
    required this.displayHeight,
  });

  /// `assets/images/<sheet>/` 스프라이트 시트 폴더 이름.
  final String sheet;

  /// 놓는 데 드는 도토리.
  final int cost;

  /// 한 번 놓은 뒤 다시 놓을 수 있을 때까지 (초).
  final double cooldown;

  final int maxHp;

  /// 게임에서 그릴 키 (논리 px, 발에서 머리 끝까지). 칸 높이는 108px.
  final double displayHeight;

  /// 놓은 직후·평소에 재생하는 동작. 스컨크는 놓자마자 폭발 준비를 한다.
  String get idleAction => this == skunk ? 'arm' : 'idle';
}
