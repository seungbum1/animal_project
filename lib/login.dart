// login.dart
import 'dart:convert';
import 'dart:io' show Platform;

import 'api_config.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'splash_screen.dart';
import 'join.dart';
import 'user_pet_report.dart';
import 'user_mainscreen.dart';
import 'hospital_mainscreen.dart';
import 'hospital_report.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loggingIn = false;

  // 에뮬레이터별 서버 주소
  String get baseUrl => ApiConfig.baseUrl;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  InputDecoration _filledNoBorder(String label) {
    final radius = BorderRadius.circular(18);
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.yellow.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
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
      final uri = Uri.parse('$baseUrl/auth/login');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': pw}),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final role = (data['user'] as Map<String, dynamic>)['role'] as String? ?? 'USER';
        final token = data['token'] as String;

        // ── 병원 관리자: 최초 로그인이면 병원정보 입력 화면 → 이후엔 메인 ──
        if (role == 'HOSPITAL_ADMIN') {
          final userMap = (data['user'] as Map<String, dynamic>);
          final hospName = (userMap['hospitalName'] as String?)?.trim() ?? '';
          final profile = (userMap['hospitalProfile'] as Map?) ?? {};

          // 병원정보가 비어있으면 최초 로그인으로 간주
          final needsProfile = hospName.isEmpty ||
              (profile['address']?.toString().trim().isEmpty ?? true) ||
              (profile['hours']?.toString().trim().isEmpty ?? true) ||
              (profile['phone']?.toString().trim().isEmpty ?? true);

          if (!mounted) return;

          if (needsProfile) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => HospitalReportPage(token: token), // 병원정보 입력 화면
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => HospitalMainScreen(
                  token: token,                       // ✅ 필수 추가
                  hospitalName: hospName.isEmpty ? '내 병원' : hospName,
                ),
              ),
            );
          }
          return;
        }

        // ── USER(또는 기본): 프로필 여부 확인 후 라우팅 ──
        await _routeUserAfterLogin(token);
      } else {
        final text = (resp.statusCode == 401)
            ? '아이디/비밀번호를 다시 확인해주세요.'
            : '로그인에 실패했습니다. 잠시 후 다시 시도해주세요.';
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

  /// 로그인 응답 or /users/me 에서 병원 이름을 안전하게 찾아서 반환 (현재는 미사용)
  Future<String> _resolveHospitalName(
      Map<String, dynamic> loginData,
      String token,
      ) async {
    try {
      // 1) 로그인 응답에 바로 들어온 경우
      final user = (loginData['user'] as Map<String, dynamic>);
      final fromLogin =
          (user['hospitalName'] as String?) ??
              (user['hospital'] is Map ? (user['hospital']['name'] as String?) : null);
      if (fromLogin != null && fromLogin.trim().isNotEmpty) {
        return fromLogin.trim();
      }

      // 2) 없으면 /users/me 조회해서 가져오기
      final meUri = Uri.parse('$baseUrl/users/me');
      final meResp = await http.get(meUri, headers: {'Authorization': 'Bearer $token'});
      if (meResp.statusCode == 200) {
        final me = jsonDecode(meResp.body) as Map<String, dynamic>;
        final mu = (me['user'] as Map<String, dynamic>);
        final fromMe =
            (mu['hospitalName'] as String?) ??
                (mu['hospital'] is Map ? (mu['hospital']['name'] as String?) : null);
        if (fromMe != null && fromMe.trim().isNotEmpty) {
          return fromMe.trim();
        }
      }
    } catch (_) {
      // ignore - 아래 기본값 리턴
    }
    return '병원'; // 기본 표시(미지정 시)
  }

  /// 로그인 성공 후 현재 사용자 정보를 불러서 petProfile 유무로 라우팅
  Future<void> _routeUserAfterLogin(String token) async {
    try {
      final meUri = Uri.parse('$baseUrl/users/me');
      final meResp = await http.get(
        meUri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (meResp.statusCode == 200) {
        final me = jsonDecode(meResp.body) as Map<String, dynamic>;
        final user = (me['user'] as Map<String, dynamic>);
        final pet = (user['petProfile'] as Map?) ?? {};

        final hasProfile = (pet['name'] is String && (pet['name'] as String).trim().isNotEmpty) ||
            (pet['age'] is int && (pet['age'] as int) > 0) ||
            (pet['gender'] is String && (pet['gender'] as String).trim().isNotEmpty) ||
            (pet['species'] is String && (pet['species'] as String).trim().isNotEmpty) ||
            (pet['avatarUrl'] is String && (pet['avatarUrl'] as String).trim().isNotEmpty);

        if (!mounted) return;

        if (hasProfile) {
          // 이미 프로필 있음 → 홈으로 직행
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => PetHomeScreen(token: token)),
          );
        } else {
          // 프로필 없음 → 프로필 입력 화면
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
        // 조회 실패 시 기본적으로 프로필 입력 화면로 보냄
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => UserPetReportPage(token: token)),
        );
      }
    } catch (e) {
      // 오류 시에도 일단 프로필 입력 화면로
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => UserPetReportPage(token: token)),
      );
    }
  }

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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
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
                              'lib/images/app_icon.png', // ← lib 아래 images 경로
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                              const Icon(Icons.pets, color: Colors.white, size: 28),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        const Text(
                          '큐라펫',
                          style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // 탭 (UI만; 실제 역할 분기는 서버 응답 role로 처리)
                    const TabBar(
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.black,
                      indicatorSize: TabBarIndicatorSize.label,
                      tabs: [
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
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
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
                          child: CircularProgressIndicator(strokeWidth: 2),
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
                              MaterialPageRoute(builder: (_) => const Join()),
                            );
                          },
                          child: const Text(
                            '회원가입',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
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
