// lib/hospital_report.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'login.dart';
import 'hospital_mainscreen.dart';

/// 한국 전화번호 자동 하이픈 포매터 (010-1234-5678 / 02-1234-5678 등)
class _KrPhoneHyphenFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    String out = digits;

    if (digits.startsWith('02')) {
      // 서울 번호
      if (digits.length <= 2) {
        out = digits;
      } else if (digits.length <= 5) {
        out = '${digits.substring(0, 2)}-${digits.substring(2)}';
      } else if (digits.length <= 9) {
        out =
        '${digits.substring(0, 2)}-${digits.substring(2, digits.length - 4)}-${digits.substring(digits.length - 4)}';
      } else {
        out =
        '${digits.substring(0, 2)}-${digits.substring(2, 6)}-${digits.substring(6, 10)}';
      }
    } else {
      // 휴대폰/지역(3자리 국번)
      if (digits.length <= 3) {
        out = digits;
      } else if (digits.length <= 7) {
        out = '${digits.substring(0, 3)}-${digits.substring(3)}';
      } else if (digits.length <= 11) {
        final midLen = digits.length == 11 ? 4 : 3;
        out =
        '${digits.substring(0, 3)}-${digits.substring(3, 3 + midLen)}-${digits.substring(3 + midLen)}';
      } else {
        out =
        '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7, 11)}';
      }
    }

    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}

class HospitalReportPage extends StatefulWidget {
  final String token; // 로그인 토큰
  const HospitalReportPage({super.key, required this.token});

  @override
  State<HospitalReportPage> createState() => _HospitalReportPageState();
}

class _HospitalReportPageState extends State<HospitalReportPage> {
  final _formKey = GlobalKey<FormState>();

  // 컨트롤러
  final _nameCtrl = TextEditingController();
  final _introCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  final _http = http.Client();
  bool _submitting = false;

  // 간단 이미지 선택 상태(실제 업로드 로직은 추후 연동)
  ImageProvider? _preview;

  static String get _baseUrl => ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    // 이미 프로필이 있으면 바로 메인으로
    _guardAlreadyCompleted();
  }

  @override
  void dispose() {
    _http.close();
    _nameCtrl.dispose();
    _introCtrl.dispose();
    _addrCtrl.dispose();
    _hoursCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // 공통 스타일
  static const _bgYellow = Color(0xFFFFF8CC); // 연노랑
  static const _hintGrey = Color(0xFF9E9E9E);

  InputDecoration _fieldDecoration(String hint, {bool required = false}) {
    return InputDecoration(
      hintText: required ? '$hint *' : hint,
      hintStyle: const TextStyle(color: _hintGrey, fontSize: 16),
      filled: true,
      fillColor: _bgYellow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _bgYellow, width: 0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _bgYellow, width: 0),
      ),
    );
  }

  // 이미 병원정보를 등록한 계정이면 메인으로 보냄
  Future<void> _guardAlreadyCompleted() async {
    try {
      final uri = Uri.parse('$_baseUrl/hospital/me');
      final resp = await _http.get(uri, headers: {
        'Authorization': 'Bearer ${widget.token}',
      });
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final u = (body['user'] as Map<String, dynamic>);
        final hospName = (u['hospitalName'] as String?)?.trim() ?? '';
        final profile = (u['hospitalProfile'] as Map?) ?? {};
        final hasProfile = hospName.isNotEmpty &&
            ((profile['address']?.toString().trim().isNotEmpty ?? false) ||
                (profile['hours']?.toString().trim().isNotEmpty ?? false) ||
                (profile['phone']?.toString().trim().isNotEmpty ?? false));

        if (hasProfile && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HospitalMainScreen(
                token: widget.token,            // ✅ 추가
                hospitalName: hospName,
            ),
            ),
          );
        }
      }
    } catch (_) {
      // 무시하고 화면 계속 표시
    }
  }

  // 필드 검증
  String? _validate() {
    final name = _nameCtrl.text.trim();
    final intro = _introCtrl.text.trim();
    final addr = _addrCtrl.text.trim();
    final hours = _hoursCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    final nameOk =
    RegExp(r'^[가-힣a-zA-Z0-9\s]{2,20}$').hasMatch(name); // 2~20자
    if (!nameOk) return '병원이름은 2~20자(한글/영문/숫자/공백)로 입력해주세요.';

    if (intro.length < 5) return '병원소개를 5자 이상 입력해주세요.';
    if (addr.length < 4) return '병원장소를 정확히 입력해주세요.';
    if (hours.isEmpty) return '영업시간을 입력해주세요.';

    // 0xx-xxx(x)-xxxx
    final phoneOk =
    RegExp(r'^0\d{1,2}-\d{3,4}-\d{4}$').hasMatch(phone);
    if (!phoneOk) return '전화번호 형식을 확인해주세요. (예: 010-1234-5678)';

    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    setState(() => _submitting = true);

    try {
      final uri = Uri.parse('$_baseUrl/hospital/profile');
      final resp = await _http.put(
        uri,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          // 서버가 지원한다면 병원이름도 갱신
          'hospitalName': _nameCtrl.text.trim(),
          'photoUrl': '', // 이미지 업로드 연동 전이므로 빈값
          'intro': _introCtrl.text.trim(),
          'address': _addrCtrl.text.trim(),
          'hours': _hoursCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
        }),
      );

      if (resp.statusCode == 200) {
        await _showApprovalPopup();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패 (${resp.statusCode}) ${resp.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('요청 실패: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showApprovalPopup() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(ctx).size.width * 0.86,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEDEDED),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 6),
                  const Text(
                    '승인 요청이 완료되었습니다!\n승인은 평균 10분 이내로 완료됩니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: Colors.black12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop(); // 닫기
                        // 로그인 화면으로 복귀 (다음 로그인부터는 메인으로 분기됨)
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                              (route) => false,
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('확인', style: TextStyle(fontSize: 15)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding:
            const EdgeInsets.symmetric(horizontal: 20).copyWith(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단: 병원사진 + 타이틀
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 사진 영역
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 6, bottom: 8),
                          child: Text(
                            '병원사진',
                            style:
                            TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            // 실제 이미지 피커 연동은 추후
                            setState(() {
                              _preview = _preview == null
                                  ? const AssetImage(
                                  'assets/placeholder_hospital.png')
                                  : null;
                            });
                          },
                          child: Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: const Color(0xFFE0E0E0), width: 1),
                              image: _preview != null
                                  ? DecorationImage(
                                  image: _preview!, fit: BoxFit.cover)
                                  : null,
                            ),
                            child: _preview == null
                                ? const Center(
                              child: Text(
                                '선택',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600),
                              ),
                            )
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // 타이틀
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '병원의 개인정보를\n입력해주세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: w < 380 ? 18 : 20,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // 입력 폼들
                TextField(
                  controller: _nameCtrl,
                  decoration: _fieldDecoration('병원이름', required: true),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _introCtrl,
                  maxLines: 2,
                  decoration: _fieldDecoration('병원소개', required: true),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _addrCtrl,
                  decoration: _fieldDecoration('병원장소', required: true),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _hoursCtrl,
                  decoration: _fieldDecoration('영업시간', required: true),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _KrPhoneHyphenFormatter(),
                  ],
                  decoration: _fieldDecoration('전화번호', required: true),
                ),

                SizedBox(height: MediaQuery.of(context).size.height * 0.22),

                // 하단 승인요청 버튼
                Center(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _bgYellow,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xFFF2EFA8)),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text(
                        '승인 요청하기',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
