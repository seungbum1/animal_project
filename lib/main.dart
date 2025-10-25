import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'hospital_list_page.dart'; // 필요시 유지
import 'user/login.dart'; // ✅ 경로 수정 (여기가 핵심!)
import 'api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await FlutterNaverMap().init(
      clientId: "pigyieafae", // 네이버 지도 Client ID
    );
    print("✅ Naver Map SDK 초기화 성공");
  } catch (e) {
    print("❌ Naver Map SDK 초기화 실패: $e");
  }

  runApp(MyApp()); // ✅ const 제거
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // ✅ const 제거
      home: LoginScreen(),
    );
  }
}
