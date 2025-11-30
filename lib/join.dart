// lib/join.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'login.dart';

class _BirthHyphenFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final b = StringBuffer();
    for (int i = 0; i < digits.length && i < 8; i++) {
      b.write(digits[i]);
      if (i == 3 || i == 5) b.write('-');
    }
    final txt = b.toString();
    return TextEditingValue(text: txt, selection: TextSelection.collapsed(offset: txt.length));
  }
}

class Join extends StatefulWidget {
  const Join({super.key});
  @override
  State<Join> createState() => _JoinState();
}

class _JoinState extends State<Join> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static String get _baseUrl => ApiConfig.baseUrl;

  final _http = http.Client();
  Duration _timeout = const Duration(seconds: 8);

  static const double _fieldHeight = 56;

  // 사용자
  final _userIdCtrl = TextEditingController();
  final _userPwCtrl = TextEditingController();
  final _userNameCtrl = TextEditingController();
  final _userBirthCtrl = TextEditingController();
  bool _userChecking = false;
  bool _userDupChecked = false;
  bool _userIdAvailable = false;
  bool _userSubmitting = false;

  // 병원 관리자 (병원이름은 최초 로그인 후 입력)
  final _adminIdCtrl = TextEditingController();
  final _adminPwCtrl = TextEditingController();
  final _adminNameCtrl = TextEditingController();
  final _adminInviteCtrl = TextEditingController();
  bool _adminChecking = false;
  bool _adminDupChecked = false;
  bool _adminIdAvailable = false;
  bool _adminSubmitting = false;

  final RegExp _idReg = RegExp(r'^[a-zA-Z0-9._-]+$');
  bool _isValidUsername(String s) => s.isNotEmpty && _idReg.hasMatch(s);
  final RegExp _birthReg = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  InputDecoration _filledNoBorder(String label, {String? helper}) => InputDecoration(
    labelText: label,
    helperText: helper,
    filled: true,
    fillColor: const Color(0xFFFFF5C3),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _userPwCtrl.addListener(() => setState(() {}));
    _adminPwCtrl.addListener(() => setState(() {}));
    _userNameCtrl.addListener(() => setState(() {}));
    _userBirthCtrl.addListener(() => setState(() {}));
    _adminNameCtrl.addListener(() => setState(() {}));
    _adminInviteCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _http.close();
    _tabController.dispose();
    _userIdCtrl.dispose();
    _userPwCtrl.dispose();
    _userNameCtrl.dispose();
    _userBirthCtrl.dispose();
    _adminIdCtrl.dispose();
    _adminPwCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminInviteCtrl.dispose();
    super.dispose();
  }

  // ✅ 전역 중복확인(사용자/병원관리자 공통) — 서버가 두 컬렉션 다 검사
  Future<void> _checkUserIdDuplicate({required bool isAdmin}) async {
    final ctrl = isAdmin ? _adminIdCtrl : _userIdCtrl;
    final id = ctrl.text.trim();

    if (!isAdmin) {
      if (!_isValidUsername(id)) {
        _toast('아이디는 영문/숫자/._- 만 사용 가능합니다.');
        return;
      }
    } else {
      if (id.isEmpty) {
        _toast('아이디를 입력해주세요.');
        return;
      }
    }

    setState(() {
      if (isAdmin) {
        _adminChecking = true;
      } else {
        _userChecking = true;
      }
    });

    try {
      final uri = Uri.parse('$_baseUrl/auth/check-id').replace(queryParameters: {
        // 어느 쿼리키를 써도 되도록 서버가 처리, 안전하게 둘 다 보냄
        'email': id,
        'username': id,
      });
      final resp = await _http.get(uri).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final available = (data['available'] == true);
        setState(() {
          if (isAdmin) {
            _adminDupChecked = true;
            _adminIdAvailable = available;
          } else {
            _userDupChecked = true;
            _userIdAvailable = available;
          }
        });
        _toast(available ? '사용 가능한 아이디입니다.' : '이미 사용 중인 아이디입니다.');
      } else {
        _toast('중복확인 실패 (${resp.statusCode})');
      }
    } catch (e) {
      _toast('중복확인 중 오류: $e');
    } finally {
      setState(() {
        if (isAdmin) {
          _adminChecking = false;
        } else {
          _userChecking = false;
        }
      });
    }
  }

  Future<void> _submitUserSignup() async {
    final username = _userIdCtrl.text.trim();
    final password = _userPwCtrl.text.trim();
    final name = _userNameCtrl.text.trim();
    final birthDate = _userBirthCtrl.text.trim();

    if (!_userDupChecked || !_userIdAvailable) {
      _toast('아이디 중복확인을 먼저 해주세요.');
      return;
    }
    if (!_isValidUsername(username)) {
      _toast('아이디는 영문/숫자/._- 만 사용 가능합니다.');
      return;
    }
    if (password.length < 4) {
      _toast('비밀번호는 최소 4자 이상 입력해주세요.');
      return;
    }
    if (name.isEmpty) {
      _toast('이름을 입력해주세요.');
      return;
    }
    if (!_birthReg.hasMatch(birthDate)) {
      _toast('생년월일을 YYYY-MM-DD 형태로 입력해주세요.');
      return;
    }

    setState(() => _userSubmitting = true);
    try {
      final uri = Uri.parse('$_baseUrl/auth/signup');
      final resp = await _http
          .post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'name': name,
          'birthDate': birthDate,
        }),
      )
          .timeout(_timeout);

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        _toast('가입 완료! 로그인 화면으로 이동합니다.');
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      } else if (resp.statusCode == 409) {
        _toast('이미 가입된 아이디입니다.');
      } else {
        _toast('가입 실패 (${resp.statusCode}) ${resp.body}');
      }
    } catch (e) {
      _toast('가입 중 오류: $e');
    } finally {
      setState(() => _userSubmitting = false);
    }
  }

  Future<void> _submitAdminSignup() async {
    if (!_adminDupChecked || !_adminIdAvailable) {
      _toast('아이디 중복확인을 먼저 해주세요.');
      return;
    }
    final email = _adminIdCtrl.text.trim();
    final password = _adminPwCtrl.text.trim();
    final adminName = _adminNameCtrl.text.trim();
    final invite = _adminInviteCtrl.text.trim();

    if (email.isEmpty) {
      _toast('아이디(이메일)를 입력해주세요.');
      return;
    }
    if (password.length < 4) {
      _toast('비밀번호는 최소 4자 이상 입력해주세요.');
      return;
    }
    if (adminName.isEmpty) {
      _toast('이름을 입력해주세요.');
      return;
    }
    if (invite.isEmpty) {
      _toast('초대코드를 입력해주세요.');
      return;
    }

    setState(() => _adminSubmitting = true);
    try {
      final uri = Uri.parse('$_baseUrl/auth/signup-with-invite');
      final resp = await _http
          .post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': adminName,
          'inviteCode': invite,
        }),
      )
          .timeout(_timeout);

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        _toast('관리자 가입 완료! 로그인 화면으로 이동합니다.');
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      } else if (resp.statusCode == 409) {
        _toast('이미 가입된 아이디입니다.');
      } else if (resp.statusCode == 400 &&
          resp.body.toLowerCase().contains('invalid invite')) {
        _toast('초대코드가 올바르지 않습니다.');
      } else {
        _toast('가입 실패 (${resp.statusCode}) ${resp.body}');
      }
    } catch (e) {
      _toast('가입 중 오류: $e');
    } finally {
      setState(() => _adminSubmitting = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final bool userPwReady = _userPwCtrl.text.trim().length >= 4;
    final bool adminPwReady = _adminPwCtrl.text.trim().length >= 4;
    const heightForTabs = 620.0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: const Offset(0, -60),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFD2CCFF),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.asset(
                            'lib/images/app_icon.png', // lib 아래 images 경로
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                            const Icon(Icons.pets, color: Colors.white, size: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        '큐라펫',
                        style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 0),


                TabBar(
                  controller: _tabController,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.black,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: const [Tab(text: '사용자'), Tab(text: '병원 관리자')],
                ),
                const SizedBox(height: 28),

                SizedBox(
                  height: heightForTabs,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUserJoinForm(context, userPwReady),
                      _buildHospitalJoinForm(context, adminPwReady),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserJoinForm(BuildContext context, bool userPwReady) {
    final bool nameReady = _userNameCtrl.text.trim().isNotEmpty;
    final bool birthReady = _birthReg.hasMatch(_userBirthCtrl.text.trim());
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: _fieldHeight,
                child: TextField(
                  controller: _userIdCtrl,
                  decoration: _filledNoBorder('아이디'),
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._-]'))],
                  onChanged: (_) => setState(() { _userDupChecked = false; _userIdAvailable = false; }),
                ),
              ),
            ),
            const SizedBox(width: 20),
            SizedBox(
              height: _fieldHeight,
              child: ElevatedButton(
                onPressed: _userChecking ? null : () => _checkUserIdDuplicate(isAdmin: false),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFFFFF5C3),
                  foregroundColor: Colors.grey.shade800,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  minimumSize: const Size(100, _fieldHeight),
                ),
                child: _userChecking
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('중복확인'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _userDupChecked
                  ? (_userIdAvailable ? '사용 가능한 아이디입니다.' : '이미 사용 중인 아이디입니다.')
                  : '아이디 입력 후 중복확인을 눌러주세요.',
              style: TextStyle(color: _userDupChecked ? (_userIdAvailable ? Colors.green : Colors.red) : Colors.grey[700]),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(height: _fieldHeight, child: TextField(controller: _userPwCtrl, decoration: _filledNoBorder('비밀번호 (최소 4자)'), obscureText: true)),
        const SizedBox(height: 20),
        SizedBox(height: _fieldHeight, child: TextField(controller: _userNameCtrl, decoration: _filledNoBorder('이름'), textInputAction: TextInputAction.next)),
        const SizedBox(height: 20),
        SizedBox(
          height: _fieldHeight,
          child: TextField(
            controller: _userBirthCtrl,
            decoration: _filledNoBorder('생년월일 8자리 (예: XXXX-YY-DD)'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, _BirthHyphenFormatter()],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          width: 180,
          child: ElevatedButton(
            onPressed: (_userSubmitting || !_userDupChecked || !_userIdAvailable || !userPwReady || !nameReady || !birthReady)
                ? null
                : _submitUserSignup,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFFFFF5C3),
              foregroundColor: Colors.grey.shade800,
              disabledBackgroundColor: const Color(0xFFFFF5C3).withOpacity(0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: _userSubmitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('가입하기'),
          ),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('이미 계정이 있으신가요?  '),
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
              child: const Text('로그인', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHospitalJoinForm(BuildContext context, bool adminPwReady) {
    final bool nameReady = _adminNameCtrl.text.trim().isNotEmpty;
    final bool inviteReady = _adminInviteCtrl.text.trim().isNotEmpty;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: _fieldHeight,
                child: TextField(
                  controller: _adminIdCtrl,
                  decoration: _filledNoBorder('아이디'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() { _adminDupChecked = false; _adminIdAvailable = false; }),
                ),
              ),
            ),
            const SizedBox(width: 20),
            SizedBox(
              height: _fieldHeight,
              child: ElevatedButton(
                onPressed: _adminChecking ? null : () => _checkUserIdDuplicate(isAdmin: true),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFFFFF5C3),
                  foregroundColor: Colors.grey.shade800,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  minimumSize: const Size(100, _fieldHeight),
                ),
                child: _adminChecking
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('중복확인'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _adminDupChecked
                  ? (_adminIdAvailable ? '사용 가능한 아이디입니다.' : '이미 사용 중인 아이디입니다.')
                  : '아이디 입력 후 중복확인을 눌러주세요.',
              style: TextStyle(color: _adminDupChecked ? (_adminIdAvailable ? Colors.green : Colors.red) : Colors.grey[700]),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(height: _fieldHeight, child: TextField(controller: _adminPwCtrl, decoration: _filledNoBorder('비밀번호 (최소 4자)'), obscureText: true)),
        const SizedBox(height: 20),
        SizedBox(height: _fieldHeight, child: TextField(controller: _adminNameCtrl, decoration: _filledNoBorder('이름'), textInputAction: TextInputAction.next)),
        const SizedBox(height: 20),
        SizedBox(height: _fieldHeight, child: TextField(controller: _adminInviteCtrl, decoration: _filledNoBorder('초대코드 (필수)'))),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          width: 180,
          child: ElevatedButton(
            onPressed: (_adminSubmitting || !_adminDupChecked || !_adminIdAvailable || !adminPwReady || !nameReady || !inviteReady)
                ? null
                : _submitAdminSignup,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFFFFF5C3),
              foregroundColor: Colors.grey.shade800,
              disabledBackgroundColor: const Color(0xFFFFF5C3).withOpacity(0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: _adminSubmitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('가입하기'),
          ),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('이미 계정이 있으신가요?  '),
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
              child: const Text('로그인', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }
}
