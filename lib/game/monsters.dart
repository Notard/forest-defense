/// 몬스터 종류와 수치 (plan.md 6단계 표). 이동·갉아먹기는 6단계에서 쓴다.
enum MonsterType {
  // 7-1단계에서 쉽게: 속도 4.7 → 5.5초/칸(도깨비불 2.3 → 3.0), 갉아먹기 100 → 70(도깨비불 60 → 45), 투구 370 → 280
  slime(sheet: 'slime', hp: 200, secondsPerCell: 5.5, biteDps: 70, displayHeight: 68),
  helmetSlime(sheet: 'slime_helmet', hp: 200, helmetHp: 280, secondsPerCell: 5.5, biteDps: 70, displayHeight: 68),
  wisp(sheet: 'wisp', hp: 120, secondsPerCell: 3.0, biteDps: 45, displayHeight: 76, floatHeight: 16),

  // ── 11단계: 새 적 (plan.md 확장 "새 적" 표) ──
  /// 느리고 아주 단단하다. 크게 그린다.
  golem(sheet: 'golem', hp: 900, secondsPerCell: 8.0, biteDps: 90, displayHeight: 112, hitHalfWidth: 46, biteReach: 64),

  /// 처음 만나는 동물 하나를 뛰어넘는다 (부엉이로 느려지면 못 넘는다).
  bat(sheet: 'bat', hp: 100, secondsPerCell: 2.8, biteDps: 40, displayHeight: 64, floatHeight: 30, jumpsOver: true),

  /// 쓰러지면 작은 버섯 둘로 나뉜다.
  mushroom(sheet: 'mushroom', hp: 160, secondsPerCell: 5.5, biteDps: 60, displayHeight: 78, splitsInto: 2),

  /// 버섯 포자가 나뉘어 생긴다 (같은 시트를 작게).
  miniMushroom(sheet: 'mushroom', hp: 60, secondsPerCell: 4.5, biteDps: 30, displayHeight: 46, hitHalfWidth: 22, biteReach: 44),

  /// 보스: 슬라임의 2.2배 몸. HP가 25%씩 줄 때마다 슬라임 둘, 통나무는 1000만 받고 통나무가 부서진다.
  /// 밤 숲(2-5)에서는 HP [nightBossHp].
  bossSlime(sheet: 'boss_slime', hp: 3000, secondsPerCell: 10.0, biteDps: 200, displayHeight: 156, hitHalfWidth: 66, biteReach: 90, boss: true);

  /// 밤 숲 보스 HP.
  static const int nightBossHp = 4500;

  /// 통나무가 보스에게 주는 피해 (보스는 한 번에 쓰러지지 않고 통나무가 부서진다).
  static const double logDamageToBoss = 1000;

  const MonsterType({
    required this.sheet,
    required this.hp,
    required this.secondsPerCell,
    required this.biteDps,
    required this.displayHeight,
    this.helmetHp = 0,
    this.floatHeight = 0,
    this.hitHalfWidth = 30,
    this.biteReach = 52,
    this.jumpsOver = false,
    this.splitsInto = 0,
    this.boss = false,
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

  /// 땅에서 떠 있는 높이 (도깨비불, 박쥐).
  final double floatHeight;

  /// 맞는 범위의 반폭 (논리 px). 여우불이 발 x − 이 값에 닿으면 맞는다. 몸이 큰 적은 넓다.
  final double hitHalfWidth;

  /// 동물 발 x에서 이만큼 오른쪽까지 다가오면 멈춰 갉아먹는다. 몸이 큰 적은 멀리서 멈춘다.
  final double biteReach;

  /// 처음 만나는 동물을 뛰어넘는지 (박쥐).
  final bool jumpsOver;

  /// 쓰러지면 작은 버섯 몇으로 나뉘는지 (버섯 포자).
  final int splitsInto;

  /// 보스 (소환, 통나무에 버팀, 크게).
  final bool boss;
}
