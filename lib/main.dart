import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

// ✅ hospital_list_page.dart import
import 'hospital_list_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 구형 init 방식 (친구 방식)
  try {
    await FlutterNaverMap().init(
      clientId: "pigyieafae", // 👉 네가 발급받은 Client ID
    );
    print("✅ Naver Map SDK 초기화 성공 (구형 방식)");
  } catch (e) {
    print("❌ Naver Map SDK 초기화 실패: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // ✅ 실행 시 첫 화면을 hospital_list_page로 설정
      home: HospitalListPage(),
    );
  }
}
