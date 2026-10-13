import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/forest_game.dart';

void main() {
  // 확인용 주소 옵션 (웹에서만 주소가 있다)
  //   ?acorns=1000  도토리 1000개로 시작
  //   ?practice=1   레인마다 움직이지 않는 연습 상대 몬스터
  final query = Uri.base.queryParameters;
  final acorns = int.tryParse(query['acorns'] ?? '');
  runApp(
    MaterialApp(
      title: '숲 지키기',
      debugShowCheckedModeBanner: false,
      home: GameWidget(game: ForestGame(startAcorns: acorns, practice: query['practice'] == '1')),
    ),
  );
}
