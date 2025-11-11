import 'dart:io';

class ApiConfig {
  /// ✅ 플랫폼별 자동 서버 주소 설정
  static String get baseUrl {
    if (Platform.isAndroid) {
      // 👉 Android 에뮬레이터에서 Node 서버에 접근
      return "http://10.0.2.2:5000";
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // 👉 Flutter 데스크탑 환경
      return "http://127.0.0.1:5000";
    } else {
      // 👉 iOS 시뮬레이터 or 외부 배포 환경 (Cloudflare / 서버)
      return "https://trustee-charms-define-upon.trycloudflare.com";
    }
  }
}
