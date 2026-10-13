/// 몬스터 종류와 수치 (plan.md 6단계 표). 이동·갉아먹기는 6단계에서 쓴다.
enum MonsterType {
  // 7-1단계에서 쉽게: 속도 4.7 → 5.5초/칸(도깨비불 2.3 → 3.0), 갉아먹기 100 → 70(도깨비불 60 → 45), 투구 370 → 280
  slime(sheet: 'slime', hp: 200, secondsPerCell: 5.5, biteDps: 70, displayHeight: 68),
  helmetSlime(sheet: 'slime_helmet', hp: 200, helmetHp: 280, secondsPerCell: 5.5, biteDps: 70, displayHeight: 68),
  wisp(sheet: 'wisp', hp: 120, secondsPerCell: 3.0, biteDps: 45, displayHeight: 76, floatHeight: 16);

  const MonsterType({
    required this.sheet,
    required this.hp,
    required this.secondsPerCell,
    required this.biteDps,
    required this.displayHeight,
    this.helmetHp = 0,
    this.floatHeight = 0,
  });

  final String sheet;
  final int hp;

  /// 투구 HP. 투구가 다 깨지면 일반 슬라임 시트로 바뀐다.
  final int helmetHp;

  /// 한 칸 이동에 걸리는 시간 (초).
  final double secondsPerCell;

  /// 갉아먹을 때 초당 피해.
  final double biteDps;

  /// 몸의 키 (논리 px). 투구 슬라임은 몸이 슬라임과 같은 크기가 되도록 슬라임 키로 배율을 정한다.
  final double displayHeight;

  /// 땅에서 떠 있는 높이 (도깨비불).
  final double floatHeight;
}
