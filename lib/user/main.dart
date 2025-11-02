import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // ✅ 추가
import 'login.dart'; // MyApp이 정의된 곳

// ✅ Render 서버 깨우기 함수
Future<void> wakeUpServer() async {
  final uri = Uri.parse('https://curapet-backend.onrender.com'); // 친구가 배포한 Render 주소
  try {
    print('⏰ Render 서버 깨우는 중...');
    await http.get(uri).timeout(const Duration(seconds: 8));
    print('✅ Render 서버 깨우기 완료');
  } catch (e) {
    print('⚠️ Render 서버 깨우기 실패: $e');
  }
}

// ✅ main 함수 수정
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 비동기 초기화 필수
  await wakeUpServer(); // 서버 미리 깨우기 실행
  runApp(const MyApp());
}
