import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ✅ 관리자 페이지 import
import '../admin/admin_main_page.dart';

import 'join.dart';
import 'user_pet_report.dart';
import 'user_mainscreen.dart';
import 'hospital_mainscreen.dart';
import 'hospital_report.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
    );
  }
}

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
  late TabController _tabController;

  // ✅ 서버 주소 (Node.js 포트 5000)
  String get baseUrl =>
      Platform.isAndroid ? 'http://10.0.2.2:5000' : 'http://localhost:5000';

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
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border:
      OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      enabledBorder:
      OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      focusedBorder:
      OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
    );
  }

  Future<void> _login() async {
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
      // ✅ 현재 탭 인덱스 (0: 사용자, 1: 병원 관리자, 2: 관리자)
      final tabIndex = _tabController.index;

      // ✅ 관리자 로그인 처리
      if (tabIndex == 2) {
        final uri = Uri.parse('$baseUrl/admin/login');
        final resp = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id': email, 'password': pw}),
        );

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          if (data['success'] == true) {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminMainPage()),
            );
            return;
          } else {
            _showError(data['message'] ?? '로그인 실패');
          }
        } else {
          _showError('서버 오류 (${resp.statusCode})');
        }

        setState(() => _loggingIn = false);
        return; // ✅ 관리자 처리 후 종료
      }

      // ✅ 사용자 및 병원 관리자 로그인 처리
      final uri = Uri.parse('$baseUrl/auth/login');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': pw}),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final role =
            (data['user'] as Map<String, dynamic>)['role'] as String? ?? 'USER';
        final token = data['token'] as String;

        // ── 병원 관리자 ──
        if (role == 'HOSPITAL_ADMIN') {
          final userMap = (data['user'] as Map<String, dynamic>);
          final hospName = (userMap['hospitalName'] as String?)?.trim() ?? '';
          final profile = (userMap['hospitalProfile'] as Map?) ?? {};

          final needsProfile = hospName.isEmpty ||
              (profile['address']?.toString().trim().isEmpty ?? true) ||
              (profile['hours']?.toString().trim().isEmpty ?? true) ||
              (profile['phone']?.toString().trim().isEmpty ?? true);

          if (!mounted) return;

          if (needsProfile) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => HospitalReportPage(token: token)),
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

        // ── 일반 사용자 ──
        await _routeUserAfterLogin(token);
      } else {
        final text = (resp.statusCode == 401)
            ? '아이디/비밀번호를 다시 확인해주세요.'
            : '로그인에 실패했습니다. 잠시 후 다시 시도해주세요.';
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(text)));
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

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _routeUserAfterLogin(String token) async {
    try {
      final meUri = Uri.parse('$baseUrl/users/me');
      final meResp =
      await http.get(meUri, headers: {'Authorization': 'Bearer $token'});

      if (meResp.statusCode == 200) {
        final me = jsonDecode(meResp.body) as Map<String, dynamic>;
        final user = (me['user'] as Map<String, dynamic>);
        final pet = (user['petProfile'] as Map?) ?? {};

        final hasProfile = (pet['name'] is String &&
            (pet['name'] as String).trim().isNotEmpty) ||
            (pet['age'] is int && (pet['age'] as int) > 0) ||
            (pet['gender'] is String &&
                (pet['gender'] as String).trim().isNotEmpty) ||
            (pet['species'] is String &&
                (pet['species'] as String).trim().isNotEmpty) ||
            (pet['avatarUrl'] is String &&
                (pet['avatarUrl'] as String).trim().isNotEmpty);

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
      } else if (meResp.statusCode == 401) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('세션이 만료되었습니다. 다시 로그인해주세요.')),
        );
      } else {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => UserPetReportPage(token: token)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => UserPetReportPage(token: token)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        child: const Icon(Icons.pets,
                            color: Colors.white, size: 28),
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

                  // ✅ TabBar → controller 연결
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.black,
                    indicatorSize: TabBarIndicatorSize.label,
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
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email
                      ],
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
                      enableSuggestions: false,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                      autofillHints: const [AutofillHints.password],
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
                        elevation: 0,
                        backgroundColor: Colors.yellow.shade100,
                        foregroundColor: Colors.grey.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _loggingIn
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                        CircularProgressIndicator(strokeWidth: 2),
                      )
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
                            MaterialPageRoute(
                                builder: (_) => const Join()),
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
    );
  }
}
