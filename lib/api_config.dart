// lib/api_config.dart
import 'package:flutter/foundation.dart' show kReleaseMode;

class ApiConfig {
  /// ✅ 프로덕션(배포) — Render
  static const String prod = 'https://curapet-backend.onrender.com';

  /// ✅ 로컬 개발
  static const String dev = 'http://127.0.0.1:4000';

  /// ✅ 거니 임시 터널(Cloudflare)
  static const String guniTunnel = 'https://trustee-charms-define-upon.trycloudflare.com';

  /// ✅ 빌드 시 전달받는 오버라이드 값 (없으면 빈 문자열)
  /// 예) --dart-define=API_BASE=guni  또는  --dart-define=API_BASE=https://my-api.com
  static const String _override =
  String.fromEnvironment('API_BASE', defaultValue: '');

  /// 최종 baseUrl 결정 로직
  static String get baseUrl {
    // 1) --dart-define로 정확히 "guni"를 넘기면 거니 터널 사용
    if (_override == 'guni') return guniTunnel;

    // 2) --dart-define에 완전한 URL을 넘긴 경우 (http/https)
    if (_override.startsWith('http://') || _override.startsWith('https://')) {
      return _override;
    }

    // 3) 그 외: 기본 정책 (운영/공유 모드는 prod 고정)
    //    개발 중에도 현재는 prod로 붙게 해둠. 필요시 아래 한 줄을 dev로 바꿔.
    return kReleaseMode ? prod : prod;
    // 개발 때만 로컬 서버로 붙이고 싶으면 위 한 줄을 아래처럼 바꿔:
    // return kReleaseMode ? prod : dev;
  }

  /// 편의: 엔드포인트 조합
  static Uri url(String path, [Map<String, dynamic>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalized').replace(queryParameters: query);
  }
}
