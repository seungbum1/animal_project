// hospital_pet_care.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'login.dart';
import 'hospital_mainscreen.dart';
import 'hospital_medical_history.dart';
import 'hospital_sos_user.dart';
import 'hospital_mypage.dart';

/// 환자관리 리스트 화면 (SOS 삭제 버전)
class HospitalPatientManageScreen extends StatefulWidget {
  const HospitalPatientManageScreen({
    super.key,
    required this.token,
    required this.hospitalName,
    this.hospitalId,
  });

  final String token;
  final String hospitalName;
  final String? hospitalId;

  @override
  State<HospitalPatientManageScreen> createState() => _HospitalPatientManageScreenState();
}

class _HospitalPatientManageScreenState extends State<HospitalPatientManageScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  final http.Client _http = http.Client();
  final Duration _timeout = const Duration(seconds: 12);

  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<_Patient> _users = [];

  // 하단바 인덱스: [홈 0 | 환자관리 1 | 진료내역 2 | 긴급호출 3 | 마이페이지 4]
  int _currentIndex = 1;

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
      final uri = Uri.parse('$_baseUrl/api/hospital-admin/linked-users').replace(
        queryParameters: {
          if (widget.hospitalId != null) 'hospitalId': widget.hospitalId!,
        },
      );

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
        _users = list.map((e) => _Patient.fromJson(e)).toList();
      } else {
        _error = '사용자 목록 불러오기 실패 (${res.statusCode})';
      }
    } catch (e) {
      _error = '네트워크 오류: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 하단 네비게이션
  void _onTapBottom(int i) {
    if (i == _currentIndex) return;
    setState(() => _currentIndex = i);
    switch (i) {
      case 0: // 홈
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => HospitalMainScreen(
            token: widget.token,
            hospitalName: widget.hospitalName,
          ),
        ));
        break;
      case 1: // 환자관리 (현재 화면)
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
      case 3: // 긴급호출
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => HospitalSosUserScreen(
            token: widget.token,
            hospitalName: widget.hospitalName,
            hospitalId: widget.hospitalId,
          ),
        ));
        break;
      case 4: // 마이페이지
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => HospitalMyPageScreen(
            token: widget.token,
            hospitalName: widget.hospitalName,
          ),
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
        title: const Text('환자관리', style: TextStyle(color: Colors.black)),
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
                      ElevatedButton(
                        onPressed: _loadUsers,
                        child: const Text('다시 불러오기'),
                      ),
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
                      title: Text('${u.userName}/${u.petName}',
                          overflow: TextOverflow.ellipsis),
                      trailing: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => HospitalPatientDetailScreen(
                              token: widget.token,
                              hospitalName: widget.hospitalName,
                              user: u,
                            ),
                          ));
                        },
                        child: const Text('환자정보'),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),

      // ✅ 5개 탭 구성: 홈 | 환자관리 | 진료내역 | 긴급호출 | 마이페이지
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

/// 리스트/상세에 공용으로 쓰는 환자 모델
class _Patient {
  final String userId;
  final String email;
  final String userName;
  final String birthDate; // YYYY-MM-DD
  final String? phone;

  // 반려 정보
  final String petName;
  final int? petAge;
  final String? petGender;
  final String? petSpecies;

  _Patient({
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

  factory _Patient.fromJson(Map<String, dynamic> j) {
    String s(dynamic v) => (v ?? '').toString();
    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    final pet = j['petProfile'] as Map<String, dynamic>?;

    return _Patient(
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

/// 환자 상세
class HospitalPatientDetailScreen extends StatelessWidget {
  const HospitalPatientDetailScreen({
    super.key,
    required this.token,
    required this.hospitalName,
    required this.user,
  });

  final String token;
  final String hospitalName;
  final _Patient user;

  @override
  Widget build(BuildContext context) {
    final rows = <_KV>[
      _KV('이름', user.userName),
      _KV('생년월일', user.birthDate),
      if ((user.phone ?? '').isNotEmpty) _KV('전화번호', user.phone!),
      _KV('아이디(이메일)', user.email),
      _KV('반려동물 이름', user.petName),
      if (user.petAge != null) _KV('반려견 나이', '${user.petAge}살'),
      if ((user.petGender ?? '').isNotEmpty) _KV('성별', user.petGender!),
      if ((user.petSpecies ?? '').isNotEmpty) _KV('종', user.petSpecies!),
      _KV('병원 연동', hospitalName),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF2B6),
        title: const Text('환자정보', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final kv = rows[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(kv.k, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(kv.v)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _KV {
  final String k, v;
  _KV(this.k, this.v);
}
