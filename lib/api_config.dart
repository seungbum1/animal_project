// lib/api_config.dart
import 'package:flutter/foundation.dart' show kReleaseMode;

class ApiConfig {
  // ✅ 배포된 Render 백엔드 주소
  static const String prod = 'https://curapet-backend.onrender.com';

  // (선택) 로컬 개발용
  static const String dev = 'http://127.0.0.1:4000';

  // 운영/공유 모드에선 항상 prod 사용을 권장
  static String get baseUrl => kReleaseMode ? prod : prod;
// 개발 때만 로컬 서버로 붙이고 싶으면 위 한 줄을 아래처럼 바꿔 써:
// static String get baseUrl => kReleaseMode ? prod : dev;
}
