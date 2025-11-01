import 'package:flutter/material.dart';
// 1. 서버 깨우기 함수를 사용하기 위해 파일을 import 합니다.
// 'curapet' 부분은 실제 프로젝트 이름에 맞게 수정해주세요.
import 'package:animal_project/api_service.dart';
import 'login.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp(); // 2. 초기화 함수를 호출합니다.
  }

  // 3. 초기화 로직을 별도의 함수로 분리하여 관리합니다.
  Future<void> _initializeApp() async {
    // ✅ 앱이 시작되자마자 서버를 깨우는 요청을 먼저 보냅니다.
    ApiService.wakeUpServer();

    // 기존의 4초 대기 로직은 그대로 유지합니다.
    await Future.delayed(const Duration(seconds: 4));

    // 위젯이 화면에 아직 마운트되어 있는지 확인 후 화면을 전환합니다.
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5C3),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFFD2CCFF),
                  child: Icon(Icons.pets, color: Colors.white, size: 28),
                ),
                SizedBox(width: 15),
                Text('큐라펫',
                    style:
                    TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}