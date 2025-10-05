// lib/main.dart

import 'package:animal_project/user_health_main.dart';
import 'package:animal_project/user_mainscreen.dart';
import 'package:flutter/material.dart';
//import 'package:flutter_naver_map/flutter_naver_map.dart';
//import 'my_hospital.dart';

// main 함수를 async로 변경하고 구형 init 로직을 추가합니다.
void main() async {
  // Flutter 위젯 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // ★★★ 포럼에서 언급된 구형 init() 메서드를 사용하여 초기화 ★★★
  //try {
    //await FlutterNaverMap().init(
      //clientId: '5zxqste0r8', // 사용자가 새로 발급받은 Client ID
      // init 메서드는 client Secret을 사용하지 않습니다.
    //);
  //} catch (e) {
    // 초기화 실패 시 에러 출력
    //print('Naver Map SDK 초기화 실패 (구형 init 방식): $e');
  //}

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 앱의 전역적인 디자인 테마 정의
      theme: ThemeData(
        fontFamily: 'NotoSansKR',
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          background: const Color(0xFFFFF7E7), // 배경색
          primary: const Color(0xFFC06362),    // 포인트 색상 (버건디)
          secondary: const Color(0xFFD9D9D9),   // 프로필 사진 배경색
          onSurface: const Color(0xFF616161),   // 차트와 그래프 텍스트 색상
        ),
      ),
      // 앱의 시작 화면을 MyHospitalPage로 설정
      home: const HealthDashboardScreen(),
    );
  }
}