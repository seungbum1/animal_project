// lib/main.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // ✅ 추가


// ✅ 네이버 지도 SDK
import 'package:flutter_naver_map/flutter_naver_map.dart';

// ✅ 로컬라이제이션/Intl
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// ✅ 스플래시/로그인
import 'package:animal_project/splash_screen.dart';
import 'login.dart';

/// ✅ Render 서버 깨우기 (짧게 대기: 2초)
Future<void> warmUpBackend() async {
  final uri = Uri.parse('https://curapet-backend-1.onrender.com/healthz');
  try {
    await http.get(uri).timeout(const Duration(seconds: 2));
    // ignore: avoid_print
    print('✅ Render 백엔드 웜업 성공');
  } catch (e) {
    // ignore: avoid_print
    print('⚠️ 백엔드 웜업 실패(무시 가능): $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) 백엔드 웜업 (앱 시작 지연 최소화)
  await warmUpBackend();

  // 2) 네이버 지도 SDK 초기화 (iOS/Android 공통, Client ID만 사용)
  try {
    await FlutterNaverMap().init(
      clientId: 'pigyieafae', // ✅ 친구가 준 Client ID
      onAuthFailed: (ex) {
        // ignore: avoid_print
        print('❌ NaverMap 인증 실패: $ex');
      },
    );
    // ignore: avoid_print
    print('✅ Naver Map SDK 초기화 성공');
  } catch (e) {
    // ignore: avoid_print
    print('❌ Naver Map SDK 초기화 실패: $e');
  }

  // 3) 한국어 로케일 초기화
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
      debugShowCheckedModeBanner: false,

      // ✅ 로케일/현지화 설정
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

      // ✅ 테마
      theme: ThemeData(
        fontFamily: 'NotoSansKR',
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          background: const Color(0xFFFFF7E7),
          primary: const Color(0xFFC06362),
          secondary: const Color(0xFFD9D9D9),
          onSurface: const Color(0xFF616161),
        ),
      ),

      // ✅ 시작 화면
      home: const SplashScreen(),

      // ✅ 라우팅
      routes: {
        '/login': (context) => const LoginScreen(),
        // '/hospitalList': (context) => const HospitalListPage(),
      },
    );
  }
}
