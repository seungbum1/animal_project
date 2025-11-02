// lib/main.dart
import 'package:flutter/material.dart';

// ✅ 네이버 지도 SDK (거니 코드에서 필요한 부분만)
import 'package:flutter_naver_map/flutter_naver_map.dart';

// ✅ 로컬라이제이션/Intl (내 코드 유지)
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// ✅ 내 스플래시 화면
import 'package:animal_project/splash_screen.dart';

// ✅ 로그인 화면 (거니 경로 반영)
import 'user/login.dart';

// (필요시) 다른 화면: import 'hospital_list_page.dart';
// (필요시) API 클라이언트: import 'api_client.dart';

Future<void> main() async {
  // 네이티브 바인딩 준비
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ (거니) 네이버 지도 SDK 초기화
  try {
    await FlutterNaverMap().init(
      clientId: "pigyieafae", // TODO: 실제 Client ID로 교체
    );
    // ignore: avoid_print
    print("✅ Naver Map SDK 초기화 성공");
  } catch (e) {
    // ignore: avoid_print
    print("❌ Naver Map SDK 초기화 실패: $e");
  }

  // ✅ (내 코드) 한국어 로케일 초기화
  await initializeDateFormatting('ko', null);
  await initializeDateFormatting('ko_KR', null);
  Intl.defaultLocale = 'ko_KR';

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 디버그 배너 비활성화 (거니 코드 반영)
      debugShowCheckedModeBanner: false,

      // ✅ (내 코드) 로케일/현지화 설정
      locale: const Locale('ko', 'KR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],

      // ✅ (내 코드) 테마 유지
      theme: ThemeData(
        fontFamily: 'NotoSansKR',
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          background: const Color(0xFFFFF7E7), // Background
          primary: const Color(0xFFC06362),    // Primary (burgundy)
          secondary: const Color(0xFFD9D9D9),  // Profile bg
          onSurface: const Color(0xFF616161),  // Chart text
        ),
      ),

      // ✅ (내 코드) 앱 시작 화면은 스플래시로
      home: const SplashScreen(),

      // ✅ (거니) 로그인 화면 등으로 라우팅 필요 시
      routes: {
        '/login': (context) => const LoginScreen(),
        // '/hospitalList': (context) => const HospitalListPage(),
      },
    );
  }
}
