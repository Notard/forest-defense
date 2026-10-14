/// 난이도 (메인 화면에서 고른다). 별·솔방울은 난이도와 상관없이 같다.
enum Difficulty {
  easy(hp: 0.6, speed: 0.85, extraAcorns: 150, hearts: 5),
  normal(hp: 1, speed: 1, extraAcorns: 0, hearts: 3),
  hard(hp: 1.6, speed: 1.15, extraAcorns: 0, hearts: 3);

  const Difficulty({required this.hp, required this.speed, required this.extraAcorns, required this.hearts});

  /// 몬스터 HP(투구 포함) 배수.
  final double hp;

  /// 몬스터 걷는 빠르기 배수.
  final double speed;

  /// 시작 도토리에 더하는 수.
  final int extraAcorns;

  /// 둥지 하트 수.
  final int hearts;
}
