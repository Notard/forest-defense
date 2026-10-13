import 'dart:async';

import 'package:flame_audio/bgm.dart';
import 'package:flame_audio/flame_audio.dart';

import 'stages.dart';

/// 배경음악 4곡 (`tools/make_bgm.py`로 만든 assets/audio/music/*.mp3, 12-3단계).
enum Track {
  /// 메인 화면·숲 지도·강화 상점: 숲속 아침 (F장조 왈츠).
  title('title'),

  /// 낮 숲 전투: 도토리 행진.
  day('day'),

  /// 밤 숲 전투: 달빛 숲.
  night('night'),

  /// 보스 스테이지: 왕 슬라임.
  boss('boss');

  const Track(this.file);

  final String file;

  String get path => 'music/$file.mp3';

  /// 스테이지에 맞는 곡.
  static Track forStage(StageDef s) => s.boss ? boss : (s.region == Region.night ? night : day);
}

/// 앱 전체에서 하나만 쓰는 배경음악 재생기. 화면(메뉴 게임·판 게임)이 바뀌어도 같은 곡이면 끊지 않고 이어 간다.
///
/// 웹은 사용자가 화면을 한 번 누르기 전에는 소리를 막는다. 그래서 메인 화면이 뜰 때 한 번,
/// "게임 시작"을 누를 때 한 번 더 [play]를 부른다 (이미 나오고 있으면 아무 일도 안 함).
class Jukebox {
  Jukebox({this.enabled = true});

  /// false면 실제로 소리를 내지 않는다 (테스트: 오디오 플러그인이 없다). [log]는 그대로 남긴다.
  final bool enabled;

  static const double volume = 0.45;

  /// 지금 나와야 하는 곡 (꺼 두었거나 멈춘 동안에도 기억한다). 판이 끝나면 null.
  Track? current;

  /// 실제로 재생을 시작한 곡.
  Track? _playing;
  bool _paused = false;
  bool _muted = false;

  /// 일어난 일 순서 (테스트용): 'play title', 'pause', 'resume', 'stop', 'mute', 'unmute'.
  final List<String> log = [];

  Bgm? _bgm;
  Bgm get _player => _bgm ??= Bgm(audioCache: FlameAudio.audioCache)..initialize();

  bool get muted => _muted;
  set muted(bool value) {
    if (value == _muted) return;
    _muted = value;
    log.add(value ? 'mute' : 'unmute');
    if (value) {
      _run(() => _player.pause());
    } else if (current != null && !_paused) {
      _playing == current ? _run(() => _player.resume()) : _start(current!);
    }
  }

  /// [track]을 반복 재생한다. 이미 그 곡이 나오고 있으면 그대로 둔다.
  void play(Track track) {
    _paused = false;
    final same = current == track && _playing == track;
    current = track;
    if (_muted) return;
    if (same && (!enabled || _player.audioPlayer.state == PlayerState.playing)) return;
    _start(track);
  }

  void _start(Track track) {
    _playing = track;
    log.add('play ${track.file}');
    _run(() => _player.play(track.path, volume: volume), onError: () => _playing = null);
  }

  /// 일시정지 판.
  void pause() {
    if (current == null || _paused) return;
    _paused = true;
    log.add('pause');
    _run(() => _player.pause());
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    if (_muted || current == null) return;
    log.add('resume');
    if (_playing == current) {
      _run(() => _player.resume());
    } else {
      _start(current!);
    }
  }

  /// 판이 끝났을 때 (이기거나 지면 효과음만).
  void stop() {
    if (current == null) return;
    current = null;
    _playing = null;
    _paused = false;
    log.add('stop');
    _run(() => _player.stop());
  }

  /// 소리 문제(웹 자동 재생 차단, 기기 오류)가 게임을 멈추지 않도록 오류는 삼킨다.
  void _run(Future<void> Function() action, {void Function()? onError}) {
    if (!enabled) return;
    try {
      unawaited(action().catchError((Object _) => onError?.call()));
    } catch (_) {
      onError?.call();
    }
  }
}
