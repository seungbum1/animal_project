// user_pet_report.dart.
import 'dart:convert';
import 'dart:io' show Platform;

import 'api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'login.dart';            // (뒤로가기용)
import 'user_mainscreen.dart';  // 저장 후 이동

class UserPetReportPage extends StatefulWidget {
  final String token; // 로그인에서 받은 JWT
  const UserPetReportPage({super.key, required this.token});

  @override
  State<UserPetReportPage> createState() => _UserPetReportPageState();
}

class _UserPetReportPageState extends State<UserPetReportPage> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();

  String _gender = '남성'; // 기본값
  String _species = '포메라니안';
  String _avatarUrl = ''; // 이미지 업로드 붙이기 전까지 임시 문자열

  bool _submitting = false;

  final _speciesList = <String>[
    '포메라니안',
    '말티즈',
    '푸들',
    '치와와',
    '시바',
    '코리안숏헤어',
    '러시안블루',
  ];

  static String get _baseUrl => ApiConfig.baseUrl;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  OutlineInputBorder _outline(Color c, [double w = 1.2]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );

  InputDecoration _outlinedBox(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade600),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: _outline(Colors.black87, 1.2),
    focusedBorder: _outline(Colors.black, 1.6),
    filled: false,
    isDense: false,
  );

  Widget _smallLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w500),
    ),
  );

  Future<void> _saveAndGoHome() async {
    final name = _nameCtrl.text.trim();
    final age = int.tryParse(_ageCtrl.text.trim()) ?? 0;

    if (name.isEmpty || age <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름과 나이를 올바르게 입력해주세요.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final uri = Uri.parse('$_baseUrl/users/me/pet');
      final resp = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'name': name,
          'age': age,
          'gender': _gender,
          'species': _species,
          'avatarUrl': _avatarUrl, // 이미지 붙이면 여기 채워주세요
        }),
      );

      if (!mounted) return;

      if (resp.statusCode == 200) {
        // 저장 성공 → 홈으로 이동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PetHomeScreen(token: widget.token),
          ),
        );
      } else if (resp.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 세션이 만료되었습니다. 다시 로그인 해주세요.')),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패 (${resp.statusCode}) ${resp.body}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 중 오류: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const double avatarSize = 110; // 아바타(원형) 지름

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(25, 10, 25, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 뒤로가기
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text('<',
                      style:
                      TextStyle(fontSize: 25, fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(height: 12),

              // 프로필(라벨+아바타) | 안내문
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 왼쪽: 라벨 + 아바타
                  SizedBox(
                    width: avatarSize,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('프로필',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        _ProfileWithGear(
                          size: avatarSize,
                          onTapAvatar: () {
                            // TODO: 이미지 선택 후 _avatarUrl 설정
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('프로필 이미지 선택 기능을 연결하세요.')),
                            );
                          },
                          onTapGear: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('프로필 설정(편집) 기능을 연결하세요.')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                  // 오른쪽: 안내문
                  SizedBox(
                    height: avatarSize,
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '보호자님의 반려동물\n정보를 입력해주세요.',
                        maxLines: 2,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                            fontSize: 23,
                            height: 1.35,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 이름
              _smallLabel(''),
              SizedBox(
                height: 56,
                child: TextField(
                  controller: _nameCtrl,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: _outlinedBox('이름 *'),
                ),
              ),
              const SizedBox(height: 14),

              // 나이
              _smallLabel(''),
              SizedBox(
                height: 56,
                child: TextField(
                  controller: _ageCtrl,
                  keyboardType: TextInputType.number,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: _outlinedBox('나이 *'),
                ),
              ),
              const SizedBox(height: 18),

              // 성별
              _smallLabel('성별'),
              _GenderSegment(
                value: _gender,
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 18),

              // 종
              _smallLabel('종'),
              SizedBox(
                height: 56,
                child: DropdownButtonFormField<String>(
                  value: _species,
                  items: _speciesList
                      .map((e) =>
                      DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _species = v ?? _species),
                  decoration: _outlinedBox('종'),
                  icon: const Icon(Icons.arrow_drop_down),
                ),
              ),

              const Spacer(),

              // 시작하기 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _saveAndGoHome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  child: _submitting
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                    CircularProgressIndicator(strokeWidth: 2.2),
                  )
                      : const Text('시작하기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileWithGear extends StatelessWidget {
  final double size; // 프로필 원 지름(px)
  final VoidCallback onTapAvatar;
  final VoidCallback onTapGear;

  const _ProfileWithGear({
    this.size = 72,
    required this.onTapAvatar,
    required this.onTapGear,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = size / 2;
    final double petIconSize = size * 0.42;
    final double gearSize = size * 0.30;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onTapAvatar,
            child: Ink(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black87, width: 1.2),
                color: Colors.white,
              ),
              child: Center(
                child: Icon(Icons.pets,
                    size: petIconSize, color: Colors.black87),
              ),
            ),
          ),
          Positioned(
            right: -size * 0.04,
            bottom: -size * 0.04,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTapGear,
              child: Ink(
                width: gearSize,
                height: gearSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black87,
                ),
                child: Center(
                  child: Icon(Icons.settings,
                      size: gearSize * 0.55, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderSegment extends StatelessWidget {
  final String value; // '남성' or '여성'
  final ValueChanged<String> onChanged;

  const _GenderSegment({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isMale = value == '남성';

    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black87, width: 1.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              onTap: () => onChanged('남성'),
              child: Center(
                child: Text(
                  '남성',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isMale ? Colors.blue : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
          Container(width: 1, color: Colors.black87),
          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              onTap: () => onChanged('여성'),
              child: Center(
                child: Text(
                  '여성',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color:
                    isMale ? Colors.grey.shade600 : Colors.blue,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
