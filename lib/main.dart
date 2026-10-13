import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/forest_game.dart';

void main() {
  runApp(
    MaterialApp(
      title: '숲 지키기',
      debugShowCheckedModeBanner: false,
      home: GameWidget(game: ForestGame()),
    ),
  );
}
