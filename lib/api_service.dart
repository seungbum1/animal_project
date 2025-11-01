import 'package:http/http.dart' as http;
import 'dart:async';

// API 관련 함수들을 모아두는 클래스
class ApiService {
  // 서버 주소는 한 곳에서만 관리하도록 상수로 선언
  static const String _serverUrl = 'https://curapet-backend.onrender.com';

  // ✅ Render 서버 깨우기 함수 (static으로 선언)
  static Future<void> wakeUpServer() async {
    final uri = Uri.parse(_serverUrl);
    try {
      print('⏰ Render 서버 깨우는 중...');
      // 타임아웃을 짧게 주어 너무 오래 기다리지 않게 함
      await http.get(uri).timeout(const Duration(seconds: 10));
      print('✅ Render 서버 깨우기 완료');
    } catch (e) {
      // 타임아웃 등이 발생해도 앱이 죽지 않도록 예외 처리
      print('⚠️ Render 서버 깨우기 실패 (괜찮음, 다음 요청에서 다시 시도됨): $e');
    }
  }

// 나중에 로그인, 회원가입 같은 다른 API 함수들도 여기에 추가하면 좋습니다.
// static Future<bool> login(String id, String password) async { ... }
}