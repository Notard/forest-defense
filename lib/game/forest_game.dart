import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'art.dart';
import 'components/acorn.dart';
import 'components/field.dart';
import 'components/ghost.dart';
import 'components/lane_background.dart';
import 'components/level_bubble.dart';
import 'components/log.dart';
import 'components/monster.dart';
import 'components/unit.dart';
import 'components/wave_runner.dart';
import 'config.dart';
import 'garden.dart';
import 'music.dart';
import 'upgrades.dart';
import 'grid.dart';
import 'hud/frozen.dart';
import 'hud/hud.dart';
import 'hud/panel.dart';
import 'hud/title.dart';
import 'monsters.dart';
import 'progress.dart';
import 'sfx.dart';
import 'stages.dart';
import 'strings.dart';
import 'units.dart';

/// 판 상태.
enum GameState { countdown, playing, paused, won, lost }

/// 판이 끝나거나 멈춘 뒤 어디로 갈지 (앱이 정한다, main.dart).
/// 소리·음악 켜기를 바꿨을 때 (앱이 저장한다).
typedef SettingsHandler = void Function({required bool sound, required bool music});

enum GameExit { retry, map, next }

/// 판이 끝났을 때 앱에 알리는 결과. 앱이 진행에 기록하고 보상을 돌려준다.
typedef FinishHandler = Reward Function({required bool won, required bool usedLog, required bool lostUnit});

/// 숲 지키기 한 판. 월드 좌표는 왼쪽 위 (0, 0) ~ 오른쪽 아래 (1280, 720).
///
/// 카메라는 움직이지 않으므로 HUD도 월드에 둔다. 화면 비율이 16:9가 아니면
/// 고정 해상도 카메라가 레터박스를 만들고, 입력 좌표도 알아서 맞춰 준다.
/// 메인 화면·숲 지도·상점은 따로 있는 메뉴 게임(menu_game.dart)이 그린다.
class ForestGame extends FlameGame {
  ForestGame({
    this.stage = demoStage,
    List<UnitType>? units,
    Random? random,
    bool? skyAcorns,
    int? startAcorns,
    this.practice = false,
    this.practiceKinds,
    bool? waves,
    this.startWave = 1,
    this.timeScale = 1,
    this.logsOn = true,
    this.onExit,
    this.onFinish,
    bool sound = true,
    this.intro = true,
    this.boosts = Boosts.none,
    this.music,
    bool muted = false,
    this.onSettings,
  })  : units = units ?? UnitType.values,
        _random = random ?? Random(),
        skyAcorns = skyAcorns ?? stage.skyAcorns,
        garden = Garden(acorns: startAcorns ?? stage.startAcorns + boosts.extraAcorns, cooldownOf: boosts.cooldownOf),
        wavesOn = waves ?? !practice,
        sfx = SoundBoard(enabled: sound)..muted = muted,
        super(
          camera: CameraComponent.withFixedResolution(
            width: GameConfig.width,
            height: GameConfig.height,
          ),
        );

  /// 이 판의 스테이지 (레인·하늘 도토리·웨이브).
  final StageDef stage;

  /// 카드로 쓸 수 있는 유닛 (해금한 것만, 순서대로).
  final List<UnitType> units;

  final Random _random;

  /// 하늘 도토리를 떨어뜨릴지 (기본은 스테이지, 테스트에서는 끈다).
  final bool skyAcorns;

  /// 확인용: 레인마다 움직이지 않는 연습 상대 몬스터를 세운다 (`?practice=1`, 5단계).
  final bool practice;

  /// 살아 있는 몬스터. 여우가 겨누고 여우불·스컨크가 맞힌다.
  final List<Monster> monsters = [];

  /// 웨이브를 돌릴지 (연습 모드와 테스트에서는 끈다).
  final bool wavesOn;

  /// 확인용: 이 웨이브부터 시작 (`?wave=5`).
  final int startWave;

  /// 확인용: 게임 시계 배속 (`?speed=2`). 애니메이션·이동·쿨다운이 모두 빨라진다.
  final double timeScale;
  WaveRunner? waveRunner;

  /// 레인마다 아직 쓰지 않은 통나무 (굴러가면 빠진다).
  final Map<int, RollingLog> logs = {};
  int _logsAtStart = 0;

  /// 통나무를 놓을지 (테스트에서 끌 수 있다).
  final bool logsOn;

  /// 쓰러뜨린 몬스터 수 (결과 화면).
  int defeated = 0;

  /// 몬스터에게 동물을 잃었는지 (★★★ 조건, 삽으로 치운 것은 빼고).
  bool lostUnit = false;

  /// 통나무를 하나라도 썼는지 (★★ 조건).
  bool get usedLog => logs.length < _logsAtStart;

  /// 지금 판 상태. 카운트다운·일시정지·클리어·게임오버면 게임 시계가 멈춘다.
  GameState state = GameState.playing;
  bool get frozen => state != GameState.playing;

  /// 판 밖으로 나가기 (다시 하기·지도로·다음 스테이지). 앱이 새 화면을 만든다.
  final void Function(GameExit)? onExit;

  /// 판이 끝났을 때 앱이 진행에 기록하고 보상을 돌려준다. 없으면(테스트·데모) 별만 셈한다.
  final FinishHandler? onFinish;

  /// 이번 판 결과 (끝난 뒤에만).
  Reward? reward;

  /// 시작할 때 카운트다운을 보일지 (테스트·`?intro=0`에서는 바로 시작).
  final bool intro;

  /// 효과음 (테스트에서는 끈다).
  final SoundBoard sfx;

  /// 앱 전체의 배경음악 (없으면 음악 없음, 12-3단계).
  final Jukebox? music;

  /// 소리·음악 버튼을 눌렀을 때 앱이 설정을 저장한다.
  final SettingsHandler? onSettings;

  void toggleSound() {
    sfx.muted = !sfx.muted;
    _settingsChanged();
  }

  void toggleMusic() {
    final m = music;
    if (m == null) return;
    m.muted = !m.muted;
    _settingsChanged();
  }

  void _settingsChanged() => onSettings?.call(sound: !sfx.muted, music: !(music?.muted ?? false));

  /// 내보내기로 했지만 그림을 읽느라 아직 목록에 들어오지 않은 몬스터 수 (클리어 판정용).
  int _pendingSpawns = 0;

  /// 도토리·쿨다운·칸 점유 규칙.
  final Garden garden;

  /// 강화 상점에서 산 영구 강화 (12단계). 유닛 능력이 이것을 보고 수치를 고친다.
  final Boosts boosts;

  late final Field field;
  late final Hud hud;

  /// 칸에 놓인 유닛 컴포넌트.
  final Map<Cell, UnitComponent> unitComponents = {};

  /// 고른 카드 (없으면 null). 삽과 동시에 고를 수 없다.
  UnitType? selectedUnit;
  bool shovelMode = false;

  /// 이 레인을 쓰는지 (1-1처럼 일부 레인만 쓰는 스테이지).
  bool laneOpen(int row) => stage.lanes.contains(row);

  @override
  Color backgroundColor() => GameConfig.backgroundColor;

  @override
  Future<void> onLoad() async {
    CharacterArt.clearCache();
    camera.viewfinder.anchor = Anchor.topLeft;
    field = Field(onCellTap: onCellTapped);
    hud = Hud();
    // 효과 그림은 미리 읽어 둔다. 첫 여우불·첫 연기에서 그림을 읽느라 한 박자 늦지 않게.
    await sfx.load();
    await images.loadAll(const ['fx/acorn.webp', 'fx/fireball.webp', 'fx/smoke.webp', 'fx/helmet.webp', 'fx/log.webp']);
    await world.addAll([
      LaneBackground(closedLanes: [for (var r = 0; r < GameConfig.rows; r++) if (!laneOpen(r)) r]),
      field,
      PlacementGhost(),
      hud,
      if (skyAcorns) SkyAcornSpawner(random: _random, lanes: stage.lanes),
    ]);
    if (practice) await _addPracticeTargets();
    if (wavesOn) {
      await world.add(waveRunner = WaveRunner(random: _random, startWave: startWave, waves: stage.waves, lanes: stage.lanes));
    }
    if (logsOn) {
      for (final row in stage.lanes) {
        final log = RollingLog(row);
        logs[row] = log;
        await world.add(log);
      }
      _logsAtStart = logs.length;
    }
    if (intro) startCountdown();
    music?.play(Track.forStage(stage));
  }

  /// 3 · 2 · 1 · 시작! 동안 게임 시계는 멈춰 있다.
  void startCountdown() {
    state = GameState.countdown;
    world.add(Countdown(onDone: () => state = GameState.playing));
  }

  /// 몬스터가 둥지 앞에 닿았다. 그 레인 통나무가 남아 있으면 굴리고, 없으면 게임오버.
  /// (통나무는 몬스터가 더 앞에서 닿을 때 이미 굴러가므로, 여기 오는 건 통나무를 쓴 레인이다.)
  void onMonsterReachedHome(Monster m) {
    final log = logs[m.row];
    if (log != null) {
      log.roll();
      return;
    }
    lose();
  }

  Reward _finish(bool won) =>
      reward = onFinish?.call(won: won, usedLog: usedLog, lostUnit: lostUnit) ??
          Reward(stars: won ? 1 + (usedLog ? 0 : 1) + (lostUnit ? 0 : 1) : 0, newStars: 0, pinecones: 0);

  void lose() {
    if (state == GameState.lost || state == GameState.won) return;
    _closePanel();
    state = GameState.lost;
    music?.stop();
    sfx.play(Sfx.lose);
    _finish(false);
    _showPanel(CenterPanel(
      title: Strings.gameOver,
      lines: [Strings.result(defeated: defeated, logsLeft: logs.length)],
      buttons: [PanelButton(Strings.toMap, () => exit(GameExit.map)), PanelButton(Strings.retry, restart)],
    ));
  }

  void win() {
    if (state != GameState.playing) return;
    state = GameState.won;
    music?.stop();
    sfx.play(Sfx.win);
    final r = _finish(true);
    final hasNext = nextStage(stage) != null && onFinish != null;
    _showPanel(CenterPanel(
      title: Strings.cleared,
      titleColor: const Color(0xFFFFE066),
      stars: r.stars,
      lines: [
        Strings.result(defeated: defeated, logsLeft: logs.length),
        if (r.pinecones > 0) Strings.pineconesGained(r.pinecones),
        if (r.unlocked != null) Strings.newFriend(r.unlocked!),
      ],
      buttons: [
        PanelButton(Strings.toMap, () => exit(GameExit.map)),
        PanelButton(Strings.retry, restart),
        if (hasNext) PanelButton(Strings.next, () => exit(GameExit.next)),
      ],
    ));
  }

  /// 일시정지 버튼: 진행 중이면 멈추고 판을 띄우고, 멈춰 있으면 판을 닫고 이어 한다.
  void togglePause() {
    if (state == GameState.playing) {
      state = GameState.paused;
      music?.pause();
      _showPanel(CenterPanel(
        title: Strings.paused,
        buttons: [
          PanelButton(Strings.resume, togglePause),
          PanelButton(Strings.retry, restart),
          PanelButton(Strings.toMap, () => exit(GameExit.map)),
        ],
      ));
    } else if (state == GameState.paused) {
      _closePanel();
      state = GameState.playing;
      music?.resume();
    }
  }

  /// 지금 떠 있는(또는 다음 프레임에 붙을) 가운데 판.
  CenterPanel? _panel;

  void _showPanel(CenterPanel panel) {
    _closePanel();
    world.add(_panel = panel);
  }

  /// 판을 닫는다. Flame은 add를 다음 프레임에 처리하므로, 같은 프레임에 띄웠다 닫으면
  /// world.children에는 아직 없다 → 들고 있는 참조로 지운다 (안 그러면 보이지 않는 판이 누름을 막는다, 12-3단계).
  void _closePanel() {
    final panel = _panel;
    _panel = null;
    if (panel != null && panel.parent != null) panel.removeFromParent();
  }

  /// 같은 스테이지를 카운트다운부터 다시.
  void restart() => exit(GameExit.retry);

  void exit(GameExit to) => onExit?.call(to);

  /// 모든 웨이브를 내보냈고 살아 있는 몬스터가 없으면 클리어.
  bool get _cleared =>
      wavesOn && (waveRunner?.director.allSpawned ?? false) && monsters.isEmpty && _pendingSpawns == 0;

  /// 연습 상대 종류 (레인 순서대로 돌려 쓴다). 없으면 슬라임·투구·도깨비불 (`?enemy=golem,bat`).
  final List<MonsterType>? practiceKinds;

  Future<void> _addPracticeTargets() async {
    final custom = practiceKinds;
    final kinds = custom != null && custom.isNotEmpty ? custom : const [MonsterType.slime, MonsterType.helmetSlime, MonsterType.wisp, MonsterType.slime, MonsterType.helmetSlime];
    for (final row in stage.lanes) {
      await addMonster(kinds[row % kinds.length], row: row, x: Grid.center((row: row, col: 7)).x, moving: false);
    }
  }

  /// 몬스터를 레인 [row]의 x 위치에 세운다.
  Future<Monster> addMonster(MonsterType type, {required int row, required double x, bool moving = true}) async {
    _pendingSpawns++;
    final Monster m;
    try {
      m = await Monster.create(this, type, row: row, x: x, moving: moving);
    } finally {
      _pendingSpawns--;
    }
    monsters.add(m);
    await world.add(m);
    return m;
  }

  @override
  void update(double dt) {
    if (frozen) {
      // 게임은 멈추고(붙이기·떼기만 처리) 카운트다운·판만 실제 시간으로 돌린다
      super.update(0);
      for (final c in world.children.whereType<RunsWhileFrozen>().toList()) {
        c.updateTree(dt);
      }
      return;
    }
    final scaled = dt * timeScale;
    super.update(scaled);
    garden.tick(scaled);
    if (_cleared) win();
  }

  /// 카드를 누름. 이미 고른 카드면 취소. 누를 수 없는 카드면 false (카드가 흔들린다).
  // ── 판 안 레벨업 (12-2단계) ──
  /// 지금 떠 있는 레벨업 말풍선.
  LevelBubble? bubble;

  /// 다음 레벨 값: Lv2는 친구 값, Lv3는 1.5배 (5 단위로 반올림).
  int levelCost(UnitComponent u) => costToLevel(u.type, u.level);

  /// [from]레벨에서 한 단계 올리는 값.
  static int costToLevel(UnitType t, int from) => from == 1 ? t.cost : ((t.cost * 1.5) / 5).round() * 5;

  /// 도토리를 내고 레벨을 올린다. 올릴 수 없거나 도토리가 모자라면 false.
  bool levelUp(UnitComponent u) {
    if (!u.canLevel || garden.acorns < levelCost(u)) return false;
    garden.acorns -= levelCost(u);
    u.levelUp();
    sfx.play(Sfx.levelUp);
    closeBubble();
    return true;
  }

  void openBubble(UnitComponent u) {
    closeBubble();
    world.add(bubble = LevelBubble(u));
  }

  void closeBubble() {
    final b = bubble;
    bubble = null;
    if (b != null && b.parent != null) b.removeFromParent();
  }

  bool selectCard(UnitType type) {
    closeBubble();
    if (selectedUnit == type) {
      selectedUnit = null;
      return true;
    }
    if (!garden.isReady(type)) return false;
    selectedUnit = type;
    shovelMode = false;
    return true;
  }

  void toggleShovel() {
    closeBubble();
    shovelMode = !shovelMode;
    if (shovelMode) selectedUnit = null;
  }

  /// 칸을 누름: 삽 모드면 치우고, 카드를 골랐으면 놓는다. 쓰지 않는 레인은 무시한다.
  Future<void> onCellTapped(Cell cell) async {
    if (!laneOpen(cell.row)) return;
    if (shovelMode) {
      if (garden.remove(cell) != null) unitComponents.remove(cell)?.removeFromParent();
      shovelMode = false;
      return;
    }
    final type = selectedUnit;
    if (type == null) {
      // 아무것도 고르지 않고 친구를 누르면 레벨업 말풍선 (다시 누르면 닫기)
      final unit = unitComponents[cell];
      if (unit != null && unit.canLevel && bubble?.unit != unit) {
        openBubble(unit);
      } else {
        closeBubble();
      }
      return;
    }
    if (garden.place(type, cell) != PlaceResult.placed) return;
    selectedUnit = null;
    sfx.play(Sfx.place);
    final unit = UnitComponent(type: type, cell: cell, art: await CharacterArt.load(this, type.sheet), boosts: boosts);
    unitComponents[cell] = unit;
    await world.add(unit);
  }
}
