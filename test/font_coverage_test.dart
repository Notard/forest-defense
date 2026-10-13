import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:forest_defense/game/strings.dart';

/// 게임 폰트는 쓰는 글자만 남긴 파일이다 (tools/subset_font.py).
/// 문구를 바꾸고 폰트를 다시 만들지 않으면 그 글자가 네모로 깨지므로 여기서 잡는다.
void main() {
  final font = File('assets/fonts/Gaegu-Bold.ttf').readAsBytesSync();
  final covered = _cmapCodePoints(ByteData.sublistView(font));

  test('폰트에 영문·숫자가 모두 있다', () {
    final missing = [
      for (var cp = 0x20; cp <= 0x7E; cp++)
        if (cp != 0x60 && !covered.contains(cp)) String.fromCharCode(cp),
    ];
    // 백틱(`)은 원본 Gaegu에도 없다.
    expect(missing, isEmpty);
  });

  test('Strings의 문구가 모두 폰트에 있다', () {
    final texts = [Strings.title, Strings.wave(10, 99)];
    expect(_missing(texts.join(), covered), isEmpty);
  });

  test('lib/ 문자열에 쓰인 한글·기호가 모두 폰트에 있다', () {
    // '작은따옴표' 또는 "큰따옴표" 문자열 (tools/subset_font.py와 같은 규칙).
    final literal = RegExp(r"'([^'\n]*)'" '|' r'"([^"\n]*)"');
    final problems = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final code = file
          .readAsLinesSync()
          .map((line) => line.replaceFirst(RegExp(r'//.*'), ''))
          .join('\n');
      for (final m in literal.allMatches(code)) {
        final missing = _missing((m[1] ?? '') + (m[2] ?? ''), covered);
        if (missing.isNotEmpty) problems.add('${file.path}: $missing');
      }
    }
    expect(problems, isEmpty,
        reason: 'python tools/subset_font.py <원본 Gaegu-Bold.ttf>로 폰트를 다시 만드세요');
  });
}

String _missing(String text, Set<int> covered) => String.fromCharCodes(
    text.runes.where((cp) => cp > 0x7E && !covered.contains(cp)).toSet());

/// TrueType `cmap` 표의 format 4(유니코드 BMP) 부분에서 글자 목록을 읽는다.
Set<int> _cmapCodePoints(ByteData d) {
  final numTables = d.getUint16(4);
  var cmap = -1;
  for (var i = 0; i < numTables; i++) {
    final rec = 12 + i * 16;
    final tag = String.fromCharCodes([
      for (var j = 0; j < 4; j++) d.getUint8(rec + j),
    ]);
    if (tag == 'cmap') cmap = d.getUint32(rec + 8);
  }
  if (cmap < 0) throw StateError('cmap 표가 없습니다');

  final subtables = d.getUint16(cmap + 2);
  for (var i = 0; i < subtables; i++) {
    final platform = d.getUint16(cmap + 4 + i * 8);
    final encoding = d.getUint16(cmap + 6 + i * 8);
    final offset = cmap + d.getUint32(cmap + 8 + i * 8);
    if (platform == 3 && encoding == 1 && d.getUint16(offset) == 4) {
      return _format4(d, offset);
    }
  }
  throw StateError('Windows 유니코드 BMP(format 4) 표가 없습니다');
}

Set<int> _format4(ByteData d, int t) {
  final segCount = d.getUint16(t + 6) ~/ 2;
  final ends = t + 14;
  final starts = ends + segCount * 2 + 2;
  final deltas = starts + segCount * 2;
  final rangeOffsets = deltas + segCount * 2;
  final result = <int>{};
  for (var s = 0; s < segCount; s++) {
    final end = d.getUint16(ends + s * 2);
    final start = d.getUint16(starts + s * 2);
    final delta = d.getInt16(deltas + s * 2);
    final ro = d.getUint16(rangeOffsets + s * 2);
    for (var c = start; c <= end && c != 0xFFFF; c++) {
      int glyph;
      if (ro == 0) {
        glyph = (c + delta) & 0xFFFF;
      } else {
        final at = rangeOffsets + s * 2 + ro + (c - start) * 2;
        final g = d.getUint16(at);
        glyph = g == 0 ? 0 : (g + delta) & 0xFFFF;
      }
      if (glyph != 0) result.add(c);
    }
  }
  return result;
}
