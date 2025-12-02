// login.dart
import 'dart:convert';
// import 'dart:io' show Platform;

import 'api_config.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'splash_screen.dart';
import 'join.dart';
import 'user_pet_report.dart';
import 'user_mainscreen.dart';
import 'hospital_mainscreen.dart';
import 'hospital_report.dart';

import 'admin/admin_main_page.dart';// ✅ 관리자 메인화면 import

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loggingIn = false;

  late TabController _tabController; // ⭐ 현재 탭 관리 (사용자/병원/관리자)

  String get baseUrl => ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  InputDecoration _filledNoBorder(String label) {
    final radius = BorderRadius.circular(18);
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.yellow.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border:
      OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      enabledBorder:
      OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      focusedBorder:
      OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
    );
  }

  // =====================================================
  //  ⭐ 로그인 처리 함수
  // =====================================================
  Future<void> _login() async {
    final prefs = await SharedPreferences.getInstance();

    final email = _emailController.text.trim();
    final pw = _passwordController.text.trim();

    if (email.isEmpty || pw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이디와 비밀번호를 입력해주세요.')),
      );
      return;
    }

    setState(() => _loggingIn = true);

    try {
      // =======================================================
      //  ① ⭐ 관리자 로그인(admin/admin)
      // =======================================================
      if (_tabController.index == 2) {
        // (3번째 탭 = 관리자)
        final uri = Uri.parse("$baseUrl/auth/admin-login");

        final resp = await http.post(
          uri,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"id": email, "password": pw}),
        );

        if (resp.statusCode == 200) {
          // 관리자 로그인 성공 → 관리자 메인 이동
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminMainPage()),
          );
          return;
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("관리자 로그인 실패: ${resp.body}")),
          );
          return;
        }
      }

      // =======================================================
      //  ② ⭐ 기존 로그인 (사용자 / 병원 관리자)
      // =======================================================
      final uri = Uri.parse("$baseUrl/auth/login");
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': pw}),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final userMap = data['user'] as Map<String, dynamic>;

        final role  = userMap['role']?.toString() ?? 'USER';
        final token = data['token'] as String;

        // 🔥 id / _id 둘 다 대응 (실제 응답은 id로 오고 있을 가능성이 큼)
        final userId = (userMap['id'] ?? userMap['_id'] ?? '').toString();

        // ⭐ SharedPreferences 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", token);
        await prefs.setString("userId", userId);
        await prefs.setString("role", role);

        print("⭐ 로그인 성공 후 userId 저장 완료: $userId");

        // ================ 병원 관리자 로그인 ================
        if (role == 'HOSPITAL_ADMIN') {
          final userMap = (data['user'] as Map<String, dynamic>);
          final hospName = (userMap['hospitalName'] as String?)?.trim() ?? '';
          final profile = (userMap['hospitalProfile'] as Map?) ?? {};

          final needsProfile = hospName.isEmpty ||
              (profile['address']?.toString().trim().isEmpty ?? true) ||
              (profile['hours']?.toString().trim().isNotEmpty == false) ||
              (profile['phone']?.toString().trim().isEmpty ?? true);

          if (!mounted) return;

          if (needsProfile) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => HospitalReportPage(token: token),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => HospitalMainScreen(
                  token: token,
                  hospitalName: hospName.isEmpty ? '내 병원' : hospName,
                ),
              ),
            );
          }
          return;
        }

        // ================ 일반 사용자 로그인 ================
        await _routeUserAfterLogin(token);
      } else {
        final text = (resp.statusCode == 401)
            ? '아이디/비밀번호를 다시 확인해주세요.'
            : '로그인에 실패했습니다.';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 오류: $e')),
      );
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  /// 사용자 로그인 후 프로필 여부에 따라 이동
  Future<void> _routeUserAfterLogin(String token) async {
    try {
      final meUri = Uri.parse('$baseUrl/users/me');
      final meResp =
      await http.get(meUri, headers: {'Authorization': 'Bearer $token'});

      if (meResp.statusCode == 200) {
        final me = jsonDecode(meResp.body);
        final user = me['user'];
        final pet = (user['petProfile'] ?? {});

        final hasProfile =
            pet['name'] != null && pet['name'].toString().trim().isNotEmpty;

        if (!mounted) return;

        if (hasProfile) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => PetHomeScreen(token: token)),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => UserPetReportPage(token: token)),
          );
        }
      } else {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => UserPetReportPage(token: token)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => UserPetReportPage(token: token)),
      );
    }
  }

  // =====================================================

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 로고 + 타이틀
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD2CCFF),
                            shape: BoxShape.circle,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Image.asset(
                              'lib/images/app_icon.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.pets,
                                  color: Colors.white,
                                  size: 28),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        const Text(
                          '큐라펫',
                          style: TextStyle(
                              fontSize: 40, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // 탭
                    TabBar(
                      controller: _tabController,
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.black,
                      tabs: const [
                        Tab(text: '사용자'),
                        Tab(text: '병원 관리자'),
                        Tab(text: '관리자'),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // 아이디
                    SizedBox(
                      width: 350,
                      child: TextField(
                        controller: _emailController,
                        decoration: _filledNoBorder('아이디'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 비밀번호
                    SizedBox(
                      width: 350,
                      child: TextField(
                        controller: _passwordController,
                        decoration: _filledNoBorder('비밀번호'),
                        obscureText: true,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // 로그인 버튼
                    SizedBox(
                      width: 130,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loggingIn ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _loggingIn
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : const Text('로그인'),
                      ),
                    ),

                    const SizedBox(height: 100),

                    // 회원가입 링크
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('계정이 없으신가요?  '),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const Join()),
                            );
                          },
                          child: const Text(
                            '회원가입',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}