import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 플레이 기록을 받는 곳: 구글 시트에 붙인 Apps Script 웹 앱 주소 (`…/exec`, 16-4단계).
/// 비어 있으면 아무것도 보내지 않는다. 받는 쪽 스크립트와 배포 방법은 `tools/sheets/`.
const telemetryUrl = 'https://script.google.com/macros/s/AKfycbzi4ToQoEjZmZW7yC-Y4y7NPmqrrq9r78u6Hfsu3VLl1UKroibdEx8zlryp09N8rxdoxA/exec';

/// 개인정보 처리방침 (설정 창 버튼, 스토어 등록에도 쓴다).
const privacyUrl = 'https://notard.github.io/forest-defense/privacy.html';

/// 기록에 함께 적는 게임 버전 (pubspec.yaml의 version과 맞춘다).
const appVersion = '1.0.0';

/// 플레이 기록 보내기 (16-4단계). 한 사건마다 JSON 한 줄을 보내고, 시트에 한 행으로 쌓인다.
///
/// 보내는 것: 사건 이름, 기기마다 무작위로 만든 번호(이름·기기 정보 아님), 버전, 플랫폼, 언어, 그리고 판 요약.
/// 보내지 못하면(오프라인 등) 그냥 버린다. 게임은 기다리지 않는다.
class Telemetry {
  Telemetry({
    required this.playerId,
    required this.allowed,
    required this.lang,
    this.url = telemetryUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String url;
  final String playerId;

  /// 지금 보내도 되는지 (설정 창의 "기록 보내기", 확인용 판·소리 끈 실행이 아닌지).
  final bool Function() allowed;

  /// 지금 화면 언어 (ko·en).
  final String Function() lang;
  final http.Client _client;

  /// 만든 기록 (테스트·디버그용, 마지막 50개).
  final List<Map<String, Object?>> recent = [];

  bool get active => url.isNotEmpty && allowed();

  /// [event] 하나를 보낸다. 보내지 않을 때도 [recent]에는 남긴다.
  Future<void> send(String event, [Map<String, Object?> data = const {}]) async {
    final row = <String, Object?>{
      't': DateTime.now().toUtc().toIso8601String(),
      'event': event,
      'id': playerId,
      'v': appVersion,
      'plat': platformName,
      'lang': lang(),
      ...data,
    };
    recent.add(row);
    if (recent.length > 50) recent.removeAt(0);
    if (!active) return;
    try {
      // text/plain이면 브라우저가 다른 사이트로 보내기 전 확인 요청(preflight)을 하지 않는다. Apps Script는 그걸 받지 못한다
      await _client
          .post(Uri.parse(url), headers: {'Content-Type': 'text/plain;charset=utf-8'}, body: jsonEncode(row))
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('기록 보내기 실패 ($event): $e');
    }
  }

  /// 'web-android', 'web-ios', 'windows' 같은 이름.
  static String get platformName => kIsWeb ? 'web-${defaultTargetPlatform.name}' : defaultTargetPlatform.name;

  /// 기기마다 한 번 만드는 무작위 번호 (16자리 16진수). 같은 사람이 몇 판 했는지 세는 데만 쓴다.
  static String newPlayerId([Random? random]) {
    final r = random ?? Random.secure();
    return List.generate(8, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
