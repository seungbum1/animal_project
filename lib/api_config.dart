// lib/api_config.dart

import 'dart:io'; // ✅ Platform 확인을 위해 추가
import 'package:flutter/foundation.dart' show kReleaseMode;

class ApiConfig {
  /// ✅ 프로덕션(배포) — Render
  static const String prod = 'https://curapet-backend.onrender.com';

  /// ✅ 로컬 개발 주소 (스마트한 분기 처리)
  static String get dev {
    const String localIp = 'http://192.168.45.173:4000';

    // 실제 기기에서도 이 IP를 사용하도록 변경합니다.
    return localIp;

    // 윈도우, iOS 시뮬레이터 등에서는 localhost 사용
    return 'http://127.0.0.1:4000';
  }

  /// ✅ 거니 임시 터널(Cloudflare)
  static const String guniTunnel = 'https://trustee-charms-define-upon.trycloudflare.com';

  static const String _override =
  String.fromEnvironment('API_BASE', defaultValue: '');

  /// 최종 baseUrl 결정 로직
  static String get baseUrl {
    if (_override == 'guni') return guniTunnel;

    if (_override.startsWith('http://') || _override.startsWith('https://')) {
      return _override;
    }

    // 배포 모드면 prod, 개발 모드면 dev(4000번)를 사용
    return kReleaseMode ? prod : dev;
  }

  static Uri url(String path, [Map<String, dynamic>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalized').replace(queryParameters: query);
  }
}