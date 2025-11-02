// hospital_sos_user.dart
import 'dart:convert';
import 'dart:io' show Platform;

import 'api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'login.dart';
import 'hospital_mainscreen.dart';
import 'hospital_medical_history.dart';
import 'hospital_mypage.dart';

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
  final Duration _timeout = const Duration(seconds: 10);

  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<_SosUser> _users = [];

  // 하단 배너 상태
  bool _showBanner = false;
  String _bannerText = '';

  int _currentIndex = 2; // 하단바: 긴급호출 선택

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
      // 병원 기준 사용자 목록
      final uri = Uri.parse(
        '$_baseUrl/api/hospital-admin/medical-histories/users',
      ).replace(queryParameters: {
        if (widget.hospitalId != null) 'hospitalId': widget.hospitalId!,
      });

      final res = await _http
          .get(uri, headers: {
        'Authorization': 'Bearer ${widget.token}',
      })
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
        final body = jsonDecode(res.body);
        final List list =
        body is List ? body : (body['data'] as List? ?? const []);
        _users = list.map((e) => _SosUser.fromJsonFlex(e)).toList();
      } else {
        _error = '사용자 목록 불러오기 실패 (${res.statusCode})';
      }
    } catch (e) {
      _error = '네트워크 오류: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 서버로 SOS 요청 (권장: 서버에서 문자 전송)
  Future<bool> _postSos(_SosUser u) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/hospital-admin/sos');
      final message =
          '[${widget.hospitalName}] ${u.userName}/${u.petName} 환자에게 긴급 상황이 발생했습니다. 즉시 병원으로 연락 바랍니다.';

      final res = await _http
          .post(
        uri,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': u.userId,
          if (widget.hospitalId != null) 'hospitalId': widget.hospitalId,
          'message': message,
        }),
      )
          .timeout(_timeout);

      if (res.statusCode == 200 || res.statusCode == 201) return true;

      return false;
    } catch (_) {
      return false;
    }
  }

  // 폴백: 기기 문자앱 열기 (iOS/권한 이슈 시)
  Future<void> _fallbackSms(_SosUser u) async {
    final phone = u.phone ?? '';
    final msg =
        '[${widget.hospitalName}] ${u.userName}/${u.petName} 환자에게 긴급 상황이 발생했습니다. 즉시 병원으로 연락 바랍니다.';
    final uri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _toast('문자앱을 열 수 없습니다.');
    }
  }

  Future<void> _sendSos(_SosUser u) async {
    // 1) 서버 전송 시도
    final ok = await _postSos(u);

    if (!mounted) return;

    if (ok) {
      setState(() {
        _showBanner = true;
        _bannerText = '${u.userName}/${u.petName} 환자에게 '
            'SOS 신호를 전송하였습니다.';
      });
      _toast('SOS 전송 완료');
    } else {
      // 2) 실패 시 폴백으로 문자앱 열기
      await _fallbackSms(u);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 900)),
    );
  }

  // 하단 네비게이션
  void _onTapBottom(int i) {
    if (i == _currentIndex) return;
    setState(() => _currentIndex = i);

    switch (i) {
      case 0:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HospitalMainScreen(
              token: widget.token,
              hospitalName: widget.hospitalName,
            ),
          ),
        );
        break;
      case 1:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HospitalMedicalHistoryScreen(
              token: widget.token,
              hospitalName: widget.hospitalName,
              hospitalId: widget.hospitalId,
            ),
          ),
        );
        break;
      case 2:
      // 현재 화면
        break;
      case 3:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HospitalMyPageScreen(
              token: widget.token,
              hospitalName: widget.hospitalName,
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchCtrl.text.trim().isEmpty
        ? _users
        : _users.where((u) {
      final q = _searchCtrl.text.trim();
      return ('${u.userName}/${u.petName}').contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF2B6),
        title:
        const Text('사용자 정보 / SOS', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
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
                  hintText: '동물/사용자이를 검색',
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
                          onPressed: _loadUsers, child: const Text('다시 불러오기')),
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // SOS 버튼(빨간 pill)
                          TextButton(
                            onPressed: () => _sendSos(u),
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFFE95A50),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999)),
                            ),
                            child: const Text('SOS'),
                          ),
                          const SizedBox(width: 8),
                          // 정보 버튼
                          OutlinedButton(
                            onPressed: () {
                              // 필요 시 상세 화면으로 이동하도록 자리만 둠(병원 정보/연락처 등)
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('사용자 정보'),
                                  content: Text(
                                    [
                                      '이름: ${u.userName}',
                                      '반려동물: ${u.petName}',
                                      if ((u.phone ?? '').isNotEmpty)
                                        '연락처: ${u.phone}',
                                    ].join('\n'),
                                  ),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('닫기')),
                                  ],
                                ),
                              );
                            },
                            child: const Text('정보'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            // 하단 SOS 배너
            if (_showBanner)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7CC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                color: Colors.black87, height: 1.3),
                            children: [
                              TextSpan(text: _bannerText.split(' SOS')[0]),
                              const TextSpan(
                                  text: ' SOS',
                                  style: TextStyle(color: Color(0xFFE95A50))),
                              TextSpan(
                                  text:
                                  _bannerText.split(' SOS').length > 1 ? _bannerText.substring(_bannerText.indexOf(' SOS') + 4) : ''),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setState(() => _showBanner = false),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
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
}

/// 사용자 행에 쓰는 경량 모델
class _SosUser {
  final String userId;
  final String userName;
  final String petName;
  final String? phone; // 서버에서 폰번호 제공 시 사용 (폴백 문자앱용)

  _SosUser({
    required this.userId,
    required this.userName,
    required this.petName,
    this.phone,
  });

  factory _SosUser.fromJsonFlex(Map<String, dynamic> j) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      return '';
    }

    return _SosUser(
      userId: pick(['userId', '_id', 'id']),
      userName: pick(['userName', 'name']),
      petName: pick(['petName', 'pet']),
      phone: pick(['phone', 'mobile', 'tel']).isEmpty ? null : pick(['phone', 'mobile', 'tel']),
    );
  }
}
