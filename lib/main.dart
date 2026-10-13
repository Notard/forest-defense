import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/forest_game.dart';

void main() {
  // 확인용 주소 옵션: ?acorns=1000 이면 도토리 1000개로 시작한다 (웹에서만 주소가 있다)
  final acorns = int.tryParse(Uri.base.queryParameters['acorns'] ?? '');
  runApp(
    MaterialApp(
      title: '숲 지키기',
      debugShowCheckedModeBanner: false,
      home: GameWidget(game: ForestGame(startAcorns: acorns)),
    ),
  );
}
