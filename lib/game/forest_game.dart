import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'art.dart';
import 'components/acorn.dart';
import 'components/field.dart';
import 'components/ghost.dart';
import 'components/lane_background.dart';
import 'components/log.dart';
import 'components/monster.dart';
import 'components/unit.dart';
import 'components/wave_runner.dart';
import 'config.dart';
import 'garden.dart';
import 'grid.dart';
import 'hud/hud.dart';
import 'hud/frozen.dart';
import 'hud/panel.dart';
import 'hud/title.dart';
import 'monsters.dart';
import 'sfx.dart';
import 'strings.dart';
import 'units.dart';

/// 판 상태.
enum GameState { title, countdown, playing, paused, won, lost }

/// 숲 지키기 게임 루트. 월드 좌표는 왼쪽 위 (0, 0) ~ 오른쪽 아래 (1280, 720).
///
/// 카메라는 움직이지 않으므로 HUD도 월드에 둔다. 화면 비율이 16:9가 아니면
/// 고정 해상도 카메라가 레터박스를 만들고, 입력 좌표도 알아서 맞춰 준다.
class ForestGame extends FlameGame {
  ForestGame({
    Random? random,
    this.skyAcorns = true,
    int? startAcorns,
    this.practice = false,
    bool? waves,
    this.startWave = 1,
    this.timeScale = 1,
    this.logsOn = true,
    this.onRestart,
    bool sound = true,
    this.intro = true,
    this.showTitle = true,
  })
      : _random = random ?? Random(),
        garden = Garden(acorns: startAcorns ?? Garden.startAcorns),
        wavesOn = waves ?? !practice,
        sfx = SoundBoard(enabled: sound),
        super(
          camera: CameraComponent.withFixedResolution(
            width: GameConfig.width,
            height: GameConfig.height,
          ),
        );

  final Random _random;

  /// 하늘 도토리를 떨어뜨릴지 (테스트에서는 끈다).
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

  /// 통나무를 놓을지 (테스트에서 끌 수 있다).
  final bool logsOn;

  /// 쓰러뜨린 몬스터 수 (결과 화면).
  int defeated = 0;

  /// 지금 판 상태. 일시정지·클리어·게임오버면 게임 시계가 멈춘다.
  GameState state = GameState.playing;
  bool get frozen => state != GameState.playing;

  /// 다시 하기·처음으로: 앱이 게임을 새로 만든다 (main.dart). [title]이면 메인 화면부터.
  final void Function({required bool title})? onRestart;

  /// 시작할 때 메인 화면·카운트다운을 보일지 (테스트·`?intro=0`에서는 바로 시작).
  final bool intro;

  /// intro일 때 메인 화면부터 보일지 (다시 하기는 카운트다운부터).
  final bool showTitle;

  /// 효과음 (테스트에서는 끈다).
  final SoundBoard sfx;

  /// 내보내기로 했지만 그림을 읽느라 아직 목록에 들어오지 않은 몬스터 수 (클리어 판정용).
  int _pendingSpawns = 0;

  /// 도토리·쿨다운·칸 점유 규칙.
  final Garden garden;

  late final Field field;
  late final Hud hud;

  /// 칸에 놓인 유닛 컴포넌트.
  final Map<Cell, UnitComponent> unitComponents = {};

  /// 고른 카드 (없으면 null). 삽과 동시에 고를 수 없다.
  UnitType? selectedUnit;
  bool shovelMode = false;

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
      LaneBackground(),
      field,
      PlacementGhost(),
      hud,
      if (skyAcorns) SkyAcornSpawner(random: _random),
    ]);
    if (practice) await _addPracticeTargets();
    if (wavesOn) await world.add(waveRunner = WaveRunner(random: _random, startWave: startWave));
    if (logsOn) {
      for (var row = 0; row < GameConfig.rows; row++) {
        final log = RollingLog(row);
        logs[row] = log;
        await world.add(log);
      }
    }
    if (intro && showTitle) {
      state = GameState.title;
      await world.add(TitleScreen());
    } else if (intro) {
      startCountdown();
    }
  }

  /// 메인 화면의 게임 시작 버튼.
  void startGame() {
    if (state != GameState.title) return;
    for (final t in world.children.whereType<TitleScreen>().toList()) {
      t.removeFromParent();
    }
    startCountdown();
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

  void lose() {
    if (state == GameState.lost || state == GameState.won) return;
    _closePanel();
    state = GameState.lost;
    sfx.play(Sfx.lose);
    world.add(CenterPanel(
      title: Strings.gameOver,
      subtitle: Strings.result(defeated: defeated, logsLeft: logs.length),
      buttons: [PanelButton(Strings.retry, restart), toTitleButton(this)],
    ));
  }

  void win() {
    if (state != GameState.playing) return;
    state = GameState.won;
    sfx.play(Sfx.win);
    world.add(CenterPanel(
      title: Strings.cleared,
      titleColor: const Color(0xFFFFE066),
      subtitle: Strings.result(defeated: defeated, logsLeft: logs.length),
      buttons: [PanelButton(Strings.retry, restart), toTitleButton(this)],
    ));
  }

  /// 일시정지 버튼: 진행 중이면 멈추고 판을 띄우고, 멈춰 있으면 판을 닫고 이어 한다.
  void togglePause() {
    if (state == GameState.playing) {
      state = GameState.paused;
      world.add(CenterPanel(
        title: Strings.paused,
        buttons: [PanelButton(Strings.resume, togglePause), PanelButton(Strings.retry, restart), toTitleButton(this)],
      ));
    } else if (state == GameState.paused) {
      _closePanel();
      state = GameState.playing;
    }
  }

  void _closePanel() {
    for (final p in world.children.whereType<CenterPanel>().toList()) {
      p.removeFromParent();
    }
  }

  /// [title]이면 메인 화면부터, 아니면 카운트다운부터 새 게임.
  void restart({bool title = false}) => onRestart?.call(title: title);

  /// 모든 웨이브를 내보냈고 살아 있는 몬스터가 없으면 클리어.
  bool get _cleared =>
      wavesOn && (waveRunner?.director.allSpawned ?? false) && monsters.isEmpty && _pendingSpawns == 0;

  Future<void> _addPracticeTargets() async {
    const kinds = [MonsterType.slime, MonsterType.helmetSlime, MonsterType.wisp, MonsterType.slime, MonsterType.helmetSlime];
    for (var row = 0; row < GameConfig.rows; row++) {
      await addMonster(kinds[row], row: row, x: Grid.center((row: row, col: 7)).x, moving: false);
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
      // 게임은 멈추고(붙이기·떼기만 처리) 메인 화면·카운트다운·판만 실제 시간으로 돌린다
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
  bool selectCard(UnitType type) {
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
    shovelMode = !shovelMode;
    if (shovelMode) selectedUnit = null;
  }

  /// 칸을 누름: 삽 모드면 치우고, 카드를 골랐으면 놓는다.
  Future<void> onCellTapped(Cell cell) async {
    if (shovelMode) {
      if (garden.remove(cell) != null) unitComponents.remove(cell)?.removeFromParent();
      shovelMode = false;
      return;
    }
    final type = selectedUnit;
    if (type == null) return;
    if (garden.place(type, cell) != PlaceResult.placed) return;
    selectedUnit = null;
    sfx.play(Sfx.place);
    final unit = UnitComponent(type: type, cell: cell, art: await CharacterArt.load(this, type.sheet));
    unitComponents[cell] = unit;
    await world.add(unit);
  }
}
