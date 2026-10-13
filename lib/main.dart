import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/forest_game.dart';

void main() {
  // 확인용 주소 옵션 (웹에서만 주소가 있다)
  //   ?acorns=1000  도토리 1000개로 시작
  //   ?practice=1   레인마다 움직이지 않는 연습 상대 몬스터 (웨이브 없음)
  //   ?wave=5       그 웨이브부터 시작
  //   ?speed=2      게임 시계 배속 (1~4)
  final query = Uri.base.queryParameters;
  final acorns = int.tryParse(query['acorns'] ?? '');
  final wave = int.tryParse(query['wave'] ?? '') ?? 1;
  final speed = (double.tryParse(query['speed'] ?? '') ?? 1).clamp(1.0, 4.0);
  runApp(
    MaterialApp(
      title: '숲 지키기',
      debugShowCheckedModeBanner: false,
      home: GameWidget(
        game: ForestGame(
          startAcorns: acorns,
          practice: query['practice'] == '1',
          startWave: wave,
          timeScale: speed,
        ),
      ),
    ),
  );
}
