import 'dart:async';

import 'package:flame_audio/flame_audio.dart';

import '../platform/web_sfx.dart';

/// 효과음 (`tools/make_sfx.py`로 만든 assets/audio/*.wav). 볼륨과 같은 소리 사이 최소 간격을 함께 둔다.
enum Sfx {
  pickup('pickup', 0.7),
  place('place', 0.8),
  shot('shot', 0.45, pooled: true, minGap: 0.05),
  hit('hit', 0.5, pooled: true, minGap: 0.04),
  slimeDie('slime_die', 0.6, minGap: 0.06),
  bite('bite', 0.4, pooled: true, minGap: 0.1),
  boom('boom', 0.9),
  log('log', 0.8),
  warning('warning', 0.6),
  win('win', 0.8),
  lose('lose', 0.8),
  helmet('helmet', 0.6, minGap: 0.05),
  tick('tick', 0.7),
  go('go', 0.8),
  hoot('hoot', 0.6, minGap: 0.3),
  swipe('swipe', 0.6, minGap: 0.08),
  spine('spine', 0.35, pooled: true, minGap: 0.1),
  levelUp('levelup', 0.7);

  const Sfx(this.file, this.volume, {this.pooled = false, this.minGap = 0});

  final String file;
  final double volume;

  /// 자주 나는 소리는 플레이어를 미리 만들어 돌려 쓴다.
  final bool pooled;

  /// 같은 소리가 이 시간(초) 안에 또 나면 건너뛴다 (여러 마리가 한꺼번에 맞을 때 소리가 쌓이지 않게).
  final double minGap;

  String get path => '$file.wav';
}

/// 효과음 재생. 소리 문제(웹 첫 클릭 전 자동 재생 차단, 기기 오류 등)가 게임을 멈추지 않도록 오류는 삼킨다.
class SoundBoard {
  SoundBoard({this.enabled = true});

  /// false면 아무 소리도 내지 않는다 (테스트: 오디오 플러그인이 없다).
  final bool enabled;

  /// 소리 끄기 버튼.
  bool muted = false;

  /// 실제로 낸(또는 [enabled]가 false라 내지 않았지만 냈어야 할) 소리 순서. 테스트가 사건마다 맞는 소리인지 본다.
  final List<Sfx> played = [];

  final Map<Sfx, AudioPool> _pools = {};
  final Map<Sfx, double> _last = {};
  final _clock = Stopwatch()..start();

  Future<void> load() async {
    if (!enabled) return;
    if (WebSfx.available) {
      // 웹: 통로 하나에 미리 풀어 둔 소리 (앱에서 한 번만 받는다, 16-1단계)
      await WebSfx.load({for (final s in Sfx.values) s.file: 'assets/audio/${s.path}'});
      return;
    }
    try {
      await FlameAudio.audioCache.loadAll([for (final s in Sfx.values) s.path]);
      for (final s in Sfx.values.where((s) => s.pooled)) {
        _pools[s] = await FlameAudio.createPool(s.path, minPlayers: 1, maxPlayers: 4);
      }
    } catch (_) {
      // 소리 없이도 게임은 돈다
    }
  }

  void play(Sfx s) {
    if (muted) return;
    final now = _clock.elapsedMilliseconds / 1000;
    if (now - (_last[s] ?? -1) < s.minGap) return;
    _last[s] = now;
    played.add(s);
    if (played.length > 100) played.removeAt(0); // 기록은 최근 것만
    if (!enabled) return;
    if (WebSfx.available) {
      WebSfx.play(s.file, s.volume);
      return;
    }
    final pool = _pools[s];
    final Future<Object?> started = pool != null ? pool.start(volume: s.volume) : FlameAudio.play(s.path, volume: s.volume);
    unawaited(started.then<Object?>((v) => v, onError: (_) => null));
  }
}
