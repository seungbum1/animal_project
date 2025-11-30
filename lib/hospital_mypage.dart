// ======================= hospital_mypage.dart =======================
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'login.dart';
import 'hospital_mainscreen.dart';
import 'hospital_medical_history.dart';
import 'hospital_medical_appointment.dart';
import 'hospital_sos_user.dart';
import 'hospital_notice.dart';
import 'hospital_pet_care.dart';
import 'hospital_patient.dart';
import 'hospital_chat_user.dart'; // ✅ 문의채팅

class HospitalMyPageScreen extends StatefulWidget {
  const HospitalMyPageScreen({
    super.key,
    required this.token,
    required this.hospitalName,
    this.hospitalId,
  });

  final String token;
  final String hospitalName;
  final String? hospitalId;

  @override
  State<HospitalMyPageScreen> createState() => _HospitalMyPageScreenState();
}

class _HospitalMyPageScreenState extends State<HospitalMyPageScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  final http.Client _http = http.Client();
  final Duration _timeout = const Duration(seconds: 10);

  bool _loading = true;
  String? _error;

  // 화면 표시에 쓰는 병원명/소개(서버에서 가져오고, 편집으로 갱신)
  late String _name;
  String _intro = '';

  int _currentIndex = 4; // ✅ 하단바: 마이페이지

  @override
  void initState() {
    super.initState();
    _name = widget.hospitalName;
    _loadProfile();
  }

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse('$_baseUrl/api/hospital-admin/profile');
      final res = await _http
          .get(uri, headers: {'Authorization': 'Bearer ${widget.token}'})
          .timeout(_timeout);

      if (res.statusCode == 401) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
        return;
      }

      if (res.statusCode == 200) {
        final map = jsonDecode(res.body);
        final data = map is Map<String, dynamic> ? (map['data'] ?? map) : map;
        _name = _pick(data, ['name', 'hospitalName', 'title']) ?? _name;
        _intro = _pick(data, ['intro', 'introduction', 'bio', 'oneLine']) ?? '';
      } else {
        _error = '프로필 불러오기 실패 (${res.statusCode})';
      }
    } catch (e) {
      _error = '네트워크 오류: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 병원명/소개 수정
  Future<void> _editProfile() async {
    final nameCtrl = TextEditingController(text: _name);
    final introCtrl = TextEditingController(text: _intro);

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  '프로필 수정',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                maxLength: 30,
                decoration: InputDecoration(
                  labelText: '병원명',
                  hintText: '병원명을 입력하세요',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: introCtrl,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: '한 줄 소개',
                  hintText: '예) 반려동물을 가족처럼 생각하는 병원',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop<Map<String, String>>(
                        context,
                        {
                          'name': nameCtrl.text.trim(),
                          'intro': introCtrl.text.trim(),
                        },
                      ),
                      child: const Text('저장'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || result == null) return;

    try {
      final uri = Uri.parse('$_baseUrl/api/hospital-admin/profile');
      final body = <String, dynamic>{
        'name': result['name'],
        'intro': result['intro'],
      };
      final res = await _http
          .patch(
        uri,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
          .timeout(_timeout);

      if (res.statusCode == 200) {
        setState(() {
          _name = result['name'] ?? _name;
          _intro = result['intro'] ?? _intro;
        });
        _toast('프로필이 수정되었습니다.');
      } else if (res.statusCode == 401) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
      } else {
        _toast('수정 실패: ${res.statusCode}');
      }
    } catch (e) {
      _toast('네트워크 오류: $e');
    }
  }

  // 하단 네비
  void _onTapBottom(int i) {
    if (i == _currentIndex) return;
    setState(() => _currentIndex = i);
    switch (i) {
      case 0:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HospitalMainScreen(
              token: widget.token,
              hospitalName: _name,
            ),
          ),
        );
        break;
      case 1: // 환자관리
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HospitalPatientManageScreen(
              token: widget.token,
              hospitalName: widget.hospitalName,
              hospitalId: widget.hospitalId,
            ),
          ),
        );
        break;
      case 2: // 진료내역
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HospitalMedicalHistoryScreen(
              token: widget.token,
              hospitalName: _name,
              hospitalId: widget.hospitalId,
            ),
          ),
        );
        break;
      case 3: // 긴급호출
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HospitalSosUserScreen(
              token: widget.token,
              hospitalName: _name,
              hospitalId: widget.hospitalId,
            ),
          ),
        );
        break;
      case 4: // 마이페이지(현재)
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _loading
          ? const SafeArea(child: Center(child: CircularProgressIndicator()))
          : _error != null
          ? SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loadProfile,
                child: const Text('다시 불러오기'),
              ),
            ],
          ),
        ),
      )
          : SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            // 상단 프로필 카드
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7CC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey,
                    ),
                    alignment: Alignment.center,
                    child: const Text('프로필', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                          _intro.isEmpty ? '""' : '\"$_intro\"',
                          style: const TextStyle(color: Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '프로필 수정',
                    onPressed: _editProfile,
                    icon: const Icon(Icons.edit, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ✅ 운영(관리) 섹션: 환자관리 / 문의채팅
            _Section(
              title: '운영',
              initiallyExpanded: true,
              items: [
                _SectionItem(
                  label: '환자관리',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HospitalPatientManageScreen(
                          token: widget.token,
                          hospitalName: _name,
                          hospitalId: widget.hospitalId,
                        ),
                      ),
                    );
                  },
                ),
                _SectionItem(
                  label: '문의채팅',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HospitalChatUserListScreen(
                          token: widget.token,
                          hospitalName: _name,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            // ✅ 진료 섹션: 예약/내역 (입원 케어는 이동)
            _Section(
              title: '진료',
              initiallyExpanded: true,
              items: [
                _SectionItem(
                  label: '진료예약 신청',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HospitalMainScreen(
                          token: widget.token,
                          hospitalName: _name,
                        ),
                      ),
                    );
                  },
                ),
                _SectionItem(
                  label: '진료내역 작성',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HospitalMedicalHistoryScreen(
                          token: widget.token,
                          hospitalName: _name,
                          hospitalId: widget.hospitalId,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            // ✅ 입원/케어 섹션: 입원 케어 일지 작성
            _Section(
              title: '입원/케어',
              initiallyExpanded: true,
              items: [
                _SectionItem(
                  label: '입원 케어 일지 작성',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HospitalPetCareListScreen(
                          token: widget.token,
                          hospitalName: _name,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            _Section(
              title: 'SOS',
              initiallyExpanded: true,
              items: [
                _SectionItem(
                  label: '환자 긴급호출',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HospitalSosUserScreen(
                          token: widget.token,
                          hospitalName: _name,
                          hospitalId: widget.hospitalId,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            _Section(
              title: '공지사항',
              initiallyExpanded: true,
              items: [
                _SectionItem(
                  label: '공지사항 작성',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HospitalNoticeScreen(
                          token: widget.token,
                          hospitalName: _name,
                          hospitalId: widget.hospitalId,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 6),
            _PlainTile(label: '고객센터', onTap: () => _toast('고객센터 준비 중')),
            _PlainTile(label: '로그아웃', onTap: _confirmLogout),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTapBottom,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), label: '환자관리'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: '진료내역'),
          BottomNavigationBarItem(icon: Icon(Icons.sos_outlined), label: '긴급호출'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '마이페이지'),
        ],
      ),
    );
  }

  String? _pick(Map<String, dynamic> j, List<String> keys) {
    for (final k in keys) {
      final v = j[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return null;
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('아니오')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('예')),
        ],
      ),
    );

    if (ok == true && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
      );
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 900)),
    );
  }
}

class _Section extends StatefulWidget {
  const _Section({
    required this.title,
    required this.items,
    this.initiallyExpanded = false,
  });

  final String title;
  final List<_SectionItem> items;
  final bool initiallyExpanded;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          dense: true,
          title: Text(
            widget.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          ...widget.items.map(
                (e) => Column(
              children: [
                const Divider(height: 1),
                ListTile(
                  dense: true,
                  title: Text(e.label),
                  onTap: e.onTap,
                ),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

class _SectionItem {
  final String label;
  final VoidCallback onTap;
  _SectionItem({required this.label, required this.onTap});
}

class _PlainTile extends StatelessWidget {
  const _PlainTile({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(dense: true, title: Text(label), onTap: onTap),
        const Divider(height: 1),
      ],
    );
  }
}
