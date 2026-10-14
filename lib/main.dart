import 'dart:ui' show PlatformDispatcher;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/difficulty.dart';
import 'game/config.dart';
import 'game/forest_game.dart';
import 'game/monsters.dart';
import 'game/music.dart';
import 'game/progress.dart';
import 'game/stages.dart';
import 'game/strings.dart';
import 'game/telemetry.dart';
import 'menu/menu_game.dart';
import 'platform/window.dart' as window;
import 'portrait_guard.dart';

/// Windows·Android 실행 인자: `--mute`면 소리·음악 없이 (자동 확인용, 15단계). 저장된 소리 설정은 바꾸지 않는다.
void main(List<String> args) {
  runApp(ForestApp(mute: args.contains('--mute')));
}

/// 앱 루트: 저장된 진행을 읽고, 메뉴(메인 화면·숲 지도)와 판(ForestGame)을 오간다.
///
/// 확인용 주소 옵션 (웹에서만 주소가 있다). 하나라도 있으면 메뉴 없이 바로 판을 시작한다.
///   ?acorns=1000  도토리 1000개로 시작
///   ?practice=1   레인마다 움직이지 않는 연습 상대 몬스터 (웨이브 없음)
///   ?wave=5       그 웨이브부터 시작
///   ?speed=2      게임 시계 배속 (1~4)
///   ?intro=0      카운트다운 없이 바로 시작
///   ?stage=1-3    그 스테이지 (없으면 예전 데모 한 판). 이때는 모든 유닛을 쓸 수 있다
///   ?enemy=golem,bat  연습 상대 종류 (?practice=1과 함께, MonsterType 이름)
///   ?level=easy   난이도 (easy·normal·hard, 없으면 메인 화면에서 고른 것)
///   ?lang=en      언어 (ko·en, 없으면 설정 창에서 고른 것, 그것도 없으면 기기 언어)
///   ?fresh=1      처음 하는 사람처럼: 몬스터 소개 창·"새로!" 꼬리표가 나온다 (저장하지 않음)
class ForestApp extends StatefulWidget {
  const ForestApp({super.key, this.mute = false});

  /// 소리·음악을 모두 끈 채로 (실행 인자 `--mute`).
  final bool mute;

  @override
  State<ForestApp> createState() => _ForestAppState();
}

class _ForestAppState extends State<ForestApp> {
  Progress? _progress;

  /// 화면이 바뀌어도 이어지는 배경음악.
  final _music = Jukebox();
  FlameGame? _screen;
  int _round = 0;

  static final _query = Uri.base.queryParameters;

  /// 플레이 기록 (16-4단계). 진행을 읽은 뒤에 만든다.
  Telemetry? _telemetry;

  /// 기록을 보내지 않는 실행: 확인용 주소 옵션, `--mute`(자동 확인), 내 컴퓨터에서 띄운 웹.
  bool get _quietRun =>
      _devPlay || widget.mute || (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1');
  static const _devKeys = ['acorns', 'practice', 'wave', 'speed', 'intro', 'stage', 'enemy'];
  bool get _devPlay => _devKeys.any(_query.containsKey);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    Progress.load().then((p) {
      _progress = p;
      Strings.lang = Lang.values.where((l) => l.name == _query['lang']).firstOrNull ?? p.lang ?? _deviceLang();
      window.setupWindow(fullscreen: p.fullscreen, title: Strings.title);
      final firstRun = p.playerId == null;
      if (firstRun) {
        p.playerId = Telemetry.newPlayerId();
        p.save();
      }
      _telemetry = Telemetry(playerId: p.playerId!, allowed: () => p.statsOn && !_quietRun, lang: () => Strings.lang.name)
        ..send('open', {'first': firstRun, 'stars': p.totalStars, 'diff': p.difficulty.name});
      _music.muted = widget.mute || !p.musicOn;
      if (_devPlay) {
        _play(stageById(_query['stage'] ?? 'demo'), dev: true);
      } else {
        _menu(MenuPage.title);
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// 기기 언어가 한국어면 한국어, 아니면 영어 (16-2단계).
  static Lang _deviceLang() => PlatformDispatcher.instance.locale.languageCode == 'ko' ? Lang.ko : Lang.en;

  /// 설정 창에서 언어를 바꿈: 저장하고 창 제목을 바꾼 뒤 메인 화면을 새 언어로 다시 그린다 (설정 창은 연 채로).
  void _setLang(Lang l) {
    final p = _progress!;
    p.lang = l;
    p.save();
    Strings.lang = l;
    window.setTitle(Strings.title);
    _menu(MenuPage.title, settings: true);
  }

  /// Windows 전체화면 바꾸기 (설정 창, F11, Alt+Enter).
  void _setFullscreen(bool on) {
    final p = _progress;
    if (p == null) return;
    p.fullscreen = on;
    p.save();
    final s = _screen;
    if (s is ForestGame) s.fullscreen = on;
    window.setFullscreen(on);
  }

  /// F11·Alt+Enter: 전체화면 ↔ 창 (Windows만).
  bool _onKey(KeyEvent e) {
    if (!window.canFullscreen || e is! KeyDownEvent || _progress == null) return false;
    final altEnter = e.logicalKey == LogicalKeyboardKey.enter && HardwareKeyboard.instance.isAltPressed;
    if (e.logicalKey != LogicalKeyboardKey.f11 && !altEnter) return false;
    _setFullscreen(!_progress!.fullscreen);
    return true;
  }

  void _show(FlameGame game) => setState(() {
        _round++;
        _screen = game;
      });

  void _menu(MenuPage page, {bool settings = false}) => _show(MenuGame(
        progress: _progress!,
        onPlay: _play,
        startPage: page,
        sound: !widget.mute,
        music: widget.mute ? null : _music,
        onLang: _setLang,
        onFullscreen: window.canFullscreen ? _setFullscreen : null,
        settingsOpen: settings,
      ));

  void _saveSettings({required bool sound, required bool music}) {
    final p = _progress!;
    p.soundOn = sound;
    p.musicOn = music;
    p.save();
  }

  void _play(StageDef stage, {bool dev = false}) {
    final p = _progress!;
    late final ForestGame game;
    _show(game = ForestGame(
      stage: stage,
      units: dev ? null : p.unlockedUnits,
      startAcorns: int.tryParse(_query['acorns'] ?? ''),
      practice: _query['practice'] == '1',
      practiceKinds: _query['enemy']?.split(',').map((n) => MonsterType.values.where((m) => m.name == n.trim()).firstOrNull).nonNulls.toList(),
      startWave: int.tryParse(_query['wave'] ?? '') ?? 1,
      timeScale: (double.tryParse(_query['speed'] ?? '') ?? 1).clamp(1.0, 4.0),
      intro: _query['intro'] != '0',
      boosts: p.boosts,
      music: widget.mute ? null : _music,
      sound: !widget.mute,
      muted: !p.soundOn,
      onSettings: _saveSettings,
      fullscreen: p.fullscreen,
      onFullscreen: window.canFullscreen ? _setFullscreen : null,
      // 처음 보는 몬스터 소개·새 친구 안내 (14단계). 확인용 판은 `?fresh=1`일 때만 (저장하지 않는 빈 기록으로)
      seenMonsters: dev ? (_query['fresh'] == '1' ? <MonsterType>{} : null) : p.seenMonsters,
      usedUnits: dev ? (_query['fresh'] == '1' ? {...Progress.startUnits} : null) : p.usedUnits,
      onLearned: dev ? null : p.save,
      difficulty: Difficulty.values.where((d) => d.name == _query['level']).firstOrNull ?? p.difficulty,
      onFinish: stage == demoStage
          ? null
          : ({required won, required lostHeart, required lostUnit}) {
              final r = p.record(stage, won: won, lostHeart: lostHeart, lostUnit: lostUnit);
              p.save();
              _telemetry?.send('end', {...game.playSummary(), 'result': won ? 'won' : 'lost', 'stars': r.stars});
              return r;
            },
      onExit: (to) {
        // 끝나기 전에 나감: 어디서 그만두는지 (다시 하기·지도로)
        if (!game.finished) _telemetry?.send('end', {...game.playSummary(), 'result': 'quit-${to.name}'});
        switch (to) {
          case GameExit.retry:
            _play(stage, dev: dev);
          case GameExit.next:
            _play(nextStage(stage) ?? stage, dev: dev);
          case GameExit.map:
            dev ? _play(stage, dev: dev) : _menu(MenuPage.map);
        }
      },
    ));
    // 판 시작: 끝 기록이 없는 판은 창을 닫은 것 (시트 요약에서 시작 수 - 끝 수)
    _telemetry?.send('start', {'stage': stage.id, 'diff': game.difficulty.name});
  }

  /// 판 도중에 휴대폰을 세우면 일시정지 (돌아와서 "이어 하기"를 누른다).
  void _pauseForPortrait() {
    final s = _screen;
    if (s is ForestGame && s.state == GameState.playing) s.togglePause();
  }

  @override
  Widget build(BuildContext context) {
    final screen = _screen;
    return MaterialApp(
      title: Strings.title,
      debugShowCheckedModeBanner: false,
      home: screen == null
          ? const ColoredBox(color: GameConfig.backgroundColor)
          : PortraitGuard(onPortrait: _pauseForPortrait, child: GameWidget(key: ValueKey(_round), game: screen)),
    );
  }
}
