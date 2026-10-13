import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/forest_game.dart';

void main() {
  runApp(const ForestApp());
}

/// 앱 루트. "다시 하기"는 카운트다운부터, "처음으로"는 메인 화면부터 게임을 새로 만든다.
class ForestApp extends StatefulWidget {
  const ForestApp({super.key});

  @override
  State<ForestApp> createState() => _ForestAppState();
}

class _ForestAppState extends State<ForestApp> {
  late ForestGame _game = _newGame(title: true);
  int _round = 0;

  ForestGame _newGame({required bool title}) {
    // 확인용 주소 옵션 (웹에서만 주소가 있다)
    //   ?acorns=1000  도토리 1000개로 시작
    //   ?practice=1   레인마다 움직이지 않는 연습 상대 몬스터 (웨이브 없음)
    //   ?wave=5       그 웨이브부터 시작
    //   ?speed=2      게임 시계 배속 (1~4)
    //   ?intro=0      메인 화면·카운트다운 없이 바로 시작
    final query = Uri.base.queryParameters;
    return ForestGame(
      startAcorns: int.tryParse(query['acorns'] ?? ''),
      practice: query['practice'] == '1',
      startWave: int.tryParse(query['wave'] ?? '') ?? 1,
      timeScale: (double.tryParse(query['speed'] ?? '') ?? 1).clamp(1.0, 4.0),
      intro: query['intro'] != '0',
      showTitle: title,
      onRestart: _restart,
    );
  }

  void _restart({required bool title}) => setState(() {
        _round++;
        _game = _newGame(title: title);
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '숲 지키기',
      debugShowCheckedModeBanner: false,
      home: GameWidget(key: ValueKey(_round), game: _game),
    );
  }
}
