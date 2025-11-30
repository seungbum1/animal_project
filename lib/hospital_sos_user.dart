// hospital_sos_user.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'login.dart';
import 'hospital_mainscreen.dart';
import 'hospital_medical_history.dart';
import 'hospital_mypage.dart';
import 'hospital_pet_care.dart'; // ✅ 환자관리 탭 이동용
import 'hospital_patient.dart';

class HospitalSosUserScreen extends StatefulWidget {
  const HospitalSosUserScreen({
    super.key,
    required this.token,
    required this.hospitalName,
    this.hospitalId,
  });

  final String token;
  final String hospitalName;
  final String? hospitalId;

  @override
  State<HospitalSosUserScreen> createState() => _HospitalSosUserScreenState();
}

class _HospitalSosUserScreenState extends State<HospitalSosUserScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  final http.Client _http = http.Client();
  final Duration _timeout = const Duration(seconds: 12);

  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<_SosUser> _users = [];

  // SOS 전송 배너
  bool _showBanner = false;
  String _bannerText = '';

  // ✅ 하단바 인덱스 (홈0 | 환자관리1 | 진료내역2 | 긴급호출3 | 마이페이지4)
  int _currentIndex = 3;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _http.close();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse('$_baseUrl/api/hospital-admin/linked-users')
          .replace(queryParameters: {
        if (widget.hospitalId != null) 'hospitalId': widget.hospitalId!,
      });

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
        final List list = jsonDecode(res.body) as List;
        _users = list.map((e) => _SosUser.fromJson(e)).toList();
      } else {
        _error = '사용자 목록 불러오기 실패 (${res.statusCode})';
      }
    } catch (e) {
      _error = '네트워크 오류: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ✅ SOS 전송만 유지
  Future<void> _sendSos(_SosUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('SOS 전송'),
        content: Text('${u.userName}/${u.petName} 환자에게 SOS를 전송할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('전송')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final uri = Uri.parse('$_baseUrl/api/hospital-admin/sos');
      final res = await _http
          .post(
        uri,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': u.userId,
          'hospitalId': widget.hospitalId,
          'message':
          '[${widget.hospitalName}] ${u.userName}/${u.petName} 환자의 응급 상황 발생. 즉시 연락 바랍니다.',
        }),
      )
          .timeout(_timeout);

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() {
          _showBanner = true;
          _bannerText = '${u.userName}/${u.petName} 환자에게 SOS 신호를 전송하였습니다.';
        });
        _toast('SOS 전송 완료');
      } else {
        _toast('SOS 전송 실패 (${res.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      _toast('네트워크 오류: $e');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 900)),
    );
  }

  // ✅ 5탭 네비게이션
  void _onTapBottom(int i) {
    if (i == _currentIndex) return;
    setState(() => _currentIndex = i);

    switch (i) {
      case 0: // 홈
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) =>
              HospitalMainScreen(token: widget.token, hospitalName: widget.hospitalName),
        ));
        break;
      case 1: // 환자관리
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => HospitalPatientManageScreen(
            token: widget.token,
            hospitalName: widget.hospitalName,
            hospitalId: widget.hospitalId,
          ),
        ));
        break;
      case 2: // 진료내역
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => HospitalMedicalHistoryScreen(
            token: widget.token,
            hospitalName: widget.hospitalName,
            hospitalId: widget.hospitalId,
          ),
        ));
        break;
      case 3: // 긴급호출 (현재)
        break;
      case 4: // 마이페이지
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) =>
              HospitalMyPageScreen(token: widget.token, hospitalName: widget.hospitalName),
        ));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.trim();
    final filtered = q.isEmpty
        ? _users
        : _users.where((u) => ('${u.userName}/${u.petName}').contains(q)).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF2B6),
        title: const Text('긴급호출 <', style: TextStyle(color: Colors.black)), // ✅ 타이틀 변경
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 검색창
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '동물/사용자 이름 검색',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _loadUsers, child: const Text('다시 불러오기')),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final u = filtered[i];
                    return ListTile(
                      leading: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      title: Text('${u.userName}/${u.petName}', overflow: TextOverflow.ellipsis),
                      // ✅ SOS만 남김
                      trailing: TextButton(
                        onPressed: () => _sendSos(u),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFE95A50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text('SOS'),
                      ),
                    );
                  },
                ),
              ),

            // SOS 배너
            if (_showBanner)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7CC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _bannerText,
                          style: const TextStyle(color: Colors.black87, height: 1.3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setState(() => _showBanner = false),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('확인'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),

      // ✅ 5개 탭: 홈 | 환자관리 | 진료내역 | 긴급호출 | 마이페이지
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
}

/// 리스트/전송에 사용하는 사용자 모델 (동일)
class _SosUser {
  final String userId;
  final String email;
  final String userName;
  final String birthDate; // YYYY-MM-DD
  final String? phone;

  // 반려
  final String petName;
  final int? petAge;
  final String? petGender;
  final String? petSpecies;

  _SosUser({
    required this.userId,
    required this.email,
    required this.userName,
    required this.birthDate,
    required this.petName,
    this.phone,
    this.petAge,
    this.petGender,
    this.petSpecies,
  });

  factory _SosUser.fromJson(Map<String, dynamic> j) {
    String s(dynamic v) => (v ?? '').toString();
    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    final pet = j['petProfile'] as Map<String, dynamic>?;

    return _SosUser(
      userId: s(j['_id'] ?? j['userId']),
      email: s(j['email']),
      userName: s(j['name'] ?? j['userName']),
      birthDate: s(j['birthDate']),
      phone: (j['phone'] ?? j['mobile'] ?? j['tel'])?.toString(),
      petName: s(pet?['name'] ?? j['petName']),
      petAge: toInt(pet?['age']),
      petGender: pet?['gender']?.toString(),
      petSpecies: pet?['species']?.toString(),
    );
  }
}
