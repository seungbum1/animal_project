// lib/api_config.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kReleaseMode, kIsWeb, debugPrint;

class ApiConfig {
  /// ✅ 프로덕션(배포) — Render 서버
  static const String prod = 'https://curapet-backend.onrender.com';

  /// ✅ 거니 임시 터널(Cloudflare)
  static const String guniTunnel =
      'https://trustee-charms-define-upon.trycloudflare.com';

  /// ✅ 빌드 시 전달받는 오버라이드 값
  /// 예)
  /// flutter run --dart-define=API_BASE=guni
  /// flutter run --dart-define=API_BASE=https://custom-api.com
  static const String _override =
  String.fromEnvironment('API_BASE', defaultValue: '');

  /// ✅ 로컬 개발용 기본 주소 (iOS 시뮬레이터, 웹, 데스크탑)
  static String get dev {
    if (kIsWeb) return 'http://127.0.0.1:4000';

    if (Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows ||
        Platform.isLinux) {
      return 'http://127.0.0.1:4000';
    }

    // 안드로이드는 어차피 아래 baseUrl에서 따로 처리
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

    // 3) 실제 안드로이드 핸드폰에서 디버그 중이면 → 무조건 Render 서버 사용
    if (!kReleaseMode && Platform.isAndroid) {
      return prod;
    }

    // 4) 그 외: 운영 모드 → prod, 개발 모드 → dev
    return kReleaseMode ? prod : dev;
  }

  /// ✅ 편의: URL 조합 함수
  static Uri url(String path, [Map<String, dynamic>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri =
    Uri.parse('$baseUrl$normalized').replace(queryParameters: query);

    debugPrint('🛰 API 요청: $uri');
    return uri;
  }
}
