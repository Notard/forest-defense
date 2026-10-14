import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/config.dart';
import 'game/forest_game.dart';
import 'game/monsters.dart';
import 'game/music.dart';
import 'game/progress.dart';
import 'game/stages.dart';
import 'menu/menu_game.dart';

void main() {
  runApp(const ForestApp());
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
class ForestApp extends StatefulWidget {
  const ForestApp({super.key});

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
  static const _devKeys = ['acorns', 'practice', 'wave', 'speed', 'intro', 'stage', 'enemy'];
  bool get _devPlay => _devKeys.any(_query.containsKey);

  @override
  void initState() {
    super.initState();
    Progress.load().then((p) {
      _progress = p;
      _music.muted = !p.musicOn;
      if (_devPlay) {
        _play(stageById(_query['stage'] ?? 'demo'), dev: true);
      } else {
        _menu(MenuPage.title);
      }
    });
  }

  void _show(FlameGame game) => setState(() {
        _round++;
        _screen = game;
      });

  void _menu(MenuPage page) => _show(MenuGame(progress: _progress!, onPlay: _play, startPage: page, music: _music));

  void _saveSettings({required bool sound, required bool music}) {
    final p = _progress!;
    p.soundOn = sound;
    p.musicOn = music;
    p.save();
  }

  void _play(StageDef stage, {bool dev = false}) {
    final p = _progress!;
    _show(ForestGame(
      stage: stage,
      units: dev ? null : p.unlockedUnits,
      startAcorns: int.tryParse(_query['acorns'] ?? ''),
      practice: _query['practice'] == '1',
      practiceKinds: _query['enemy']?.split(',').map((n) => MonsterType.values.where((m) => m.name == n.trim()).firstOrNull).nonNulls.toList(),
      startWave: int.tryParse(_query['wave'] ?? '') ?? 1,
      timeScale: (double.tryParse(_query['speed'] ?? '') ?? 1).clamp(1.0, 4.0),
      intro: _query['intro'] != '0',
      boosts: p.boosts,
      music: _music,
      muted: !p.soundOn,
      onSettings: _saveSettings,
      onFinish: stage == demoStage
          ? null
          : ({required won, required lostHeart, required lostUnit}) {
              final r = p.record(stage, won: won, lostHeart: lostHeart, lostUnit: lostUnit);
              p.save();
              return r;
            },
      onExit: (to) => switch (to) {
        GameExit.retry => _play(stage, dev: dev),
        GameExit.next => _play(nextStage(stage) ?? stage, dev: dev),
        GameExit.map => dev ? _play(stage, dev: dev) : _menu(MenuPage.map),
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screen = _screen;
    return MaterialApp(
      title: '숲 지키기',
      debugShowCheckedModeBanner: false,
      home: screen == null
          ? const ColoredBox(color: GameConfig.backgroundColor)
          : GameWidget(key: ValueKey(_round), game: screen),
    );
  }
}
