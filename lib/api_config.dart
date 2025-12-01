// lib/api_config.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kReleaseMode;

class ApiConfig {
  /// ✅ 프로덕션(배포) — Render 서버
  static const String prod = 'https://curapet-backend.onrender.com';

  /// ✅ 거니 임시 터널(Cloudflare)
  static const String guniTunnel =
      'https://trustee-charms-define-upon.trycloudflare.com';

  /// ✅ 빌드 시 전달받는 오버라이드 값
  /// 예:
  /// flutter run --dart-define=API_BASE=guni
  /// flutter run --dart-define=API_BASE=https://custom-api.com
  static const String _override =
  String.fromEnvironment('API_BASE', defaultValue: '');

  /// ✅ 로컬 개발 주소 자동 분기
  static String get dev {
    // Android 에뮬레이터 → 반드시 10.0.2.2
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:4000';
    }

    // iOS Simulator → localhost 사용 가능
    if (Platform.isIOS) {
      return 'http://127.0.0.1:4000';
    }

    // macOS / Windows / Linux → 로컬 서버 그대로
    return 'http://127.0.0.1:4000';
  }

  /// ✅ 최종 baseUrl 결정 로직
  static String get baseUrl {
    // 1) --dart-define=API_BASE=guni  → 거니 터널 강제 사용
    if (_override == 'guni') return guniTunnel;

    // 2) --dart-define으로 URL 넣으면 그걸 그대로 사용
    if (_override.startsWith('http://') || _override.startsWith('https://')) {
      return _override;
    }

    // 3) 기본 정책: 운영 모드 → prod, 개발 모드 → dev
    return kReleaseMode ? prod : dev;
  }

  /// ✅ 편의: URL 조합 함수
  static Uri url(String path, [Map<String, dynamic>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalized')
        .replace(queryParameters: query);
  }
}
