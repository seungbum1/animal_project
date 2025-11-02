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
  String _intro = ''; // 한줄소개

  int _currentIndex = 3; // 하단바: 마이페이지 선택

  @override
  void initState() {
    super.initState();
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
        // 유연 파싱
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

  Future<void> _editIntro() async {
    final ctrl = TextEditingController(text: _intro);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
                child: Text('병원 소개 수정',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLength: 80,
                decoration: InputDecoration(
                  hintText: '한 줄 소개를 입력하세요 (예: "반려동물을 가족처럼 생각하는 병원")',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('취소')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, ctrl.text),
                        child: const Text('저장')),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );

    if (!mounted || result == null) return;

    // 서버 PATCH
    try {
      final uri = Uri.parse('$_baseUrl/api/hospital-admin/profile');
      final res = await _http
          .patch(uri,
          headers: {
            'Authorization': 'Bearer ${widget.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'intro': result}))
          .timeout(_timeout);

      if (res.statusCode == 200) {
        setState(() => _intro = result);
        _toast('소개가 수정되었습니다.');
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

  void _onTapBottom(int i) {
    if (i == _currentIndex) return;
    setState(() => _currentIndex = i);
    switch (i) {
      case 0:
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => HospitalMainScreen(
            token: widget.token,
            hospitalName: widget.hospitalName,
          ),
        ));
        break;
      case 1:
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => HospitalMedicalHistoryScreen(
            token: widget.token,
            hospitalName: widget.hospitalName,
            hospitalId: widget.hospitalId,
          ),
        ));
        break;
      case 2:
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => HospitalSosUserScreen(
            token: widget.token,
            hospitalName: widget.hospitalName,
            hospitalId: widget.hospitalId,
          ),
        ));
        break;
      case 3:
      // 현재 화면
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.hospitalName; // 병원명은 전달값 사용(화면마다 자동 반영)
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF2B6),
        title: const Text('마이페이지', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          ElevatedButton(
              onPressed: _loadProfile, child: const Text('다시 불러오기')),
        ]),
      )
          : ListView(
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
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey,
                  ),
                  alignment: Alignment.center,
                  child: const Text('프로필',
                      style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        _intro.isEmpty
                            ? '""'
                            : '\"$_intro\"', // 따옴표 형태 유지
                        style: const TextStyle(color: Colors.black87),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '소개 수정',
                  onPressed: _editIntro,
                  icon: const Icon(Icons.edit, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 섹션들
          _Section(
            title: '진료내역',
            items: [
              _SectionItem(
                label: '진료 확인',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HospitalMedicalHistoryScreen(
                      token: widget.token,
                      hospitalName: widget.hospitalName,
                      hospitalId: widget.hospitalId,
                    ),
                  ),
                ),
              ),
              _SectionItem(
                label: '진료 작성',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HospitalMedicalHistoryScreen(
                      token: widget.token,
                      hospitalName: widget.hospitalName,
                      hospitalId: widget.hospitalId,
                    ),
                  ),
                ),
              ),
              _SectionItem(
                label: '예약 일정',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HospitalMedicalAppointmentScreen(
                      token: widget.token,
                      hospitalName: widget.hospitalName,
                    ),
                  ),
                ),
              ),
            ],
          ),
          _Section(
            title: 'SOS',
            initiallyExpanded: true,
            items: [
              _SectionItem(
                label: '긴급 호출',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HospitalSosUserScreen(
                      token: widget.token,
                      hospitalName: widget.hospitalName,
                      hospitalId: widget.hospitalId,
                    ),
                  ),
                ),
              ),
            ],
          ),
          _Section(
            title: '공지사항',
            initiallyExpanded: true,
            items: [
              _SectionItem(
                label: '공지사항 작성',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HospitalNoticeScreen(
                      token: widget.token,
                      hospitalName: widget.hospitalName,
                      hospitalId: widget.hospitalId,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _PlainTile(
            label: '고객센터',
            onTap: () => _toast('고객센터 준비 중'),
          ),
          _PlainTile(
            label: '로그아웃',
            onTap: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
                ),
                    (_) => false,
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTapBottom,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined), label: '진료내역'),
          BottomNavigationBarItem(icon: Icon(Icons.sos_outlined), label: '긴급호출'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: '마이페이지'),
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
          title: Text(widget.title,
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          ...widget.items.map((e) => Column(
            children: [
              const Divider(height: 1),
              ListTile(
                dense: true,
                title: Text(e.label),
                onTap: e.onTap,
              ),
            ],
          )),
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
