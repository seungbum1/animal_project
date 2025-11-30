// user_myhospital_list.dart
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

import 'user_health_main.dart';
import 'user_mainscreen.dart'; // 홈으로 이동 시 사용 (PetHomeScreen)
import 'user_hospital_connection.dart'; // 병원 연동하기 화면
import 'user_myhospital_mainscreen.dart'; // ✅ 새로 추가한 "내 병원 메인" 화면

class UserMyHospitalListPage extends StatefulWidget {
  final String? token;

  /// ✅ MainTabs(IndexedStack) 안에서 쓸 땐 false로 내려서 하단 네비를 숨긴다.
  final bool showBottomNav;

  const UserMyHospitalListPage({
    super.key,
    this.token,
    this.showBottomNav = true,
  });

  @override
  State<UserMyHospitalListPage> createState() => _UserMyHospitalListPageState();
}

class _UserMyHospitalListPageState extends State<UserMyHospitalListPage> {
  // =========================
  // 백엔드 베이스 URL 자동 선택
  // =========================
  static String get _baseUrl => ApiConfig.baseUrl;

  final http.Client _http = http.Client();
  Duration _timeout = const Duration(seconds: 8);

  List<_LinkedHospital> _linked = [];
  bool _loading = true;
  String? _error;

  void _noAnimReplace(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadLinkedHospitals();
  }

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }

  Future<void> _loadLinkedHospitals() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('$_baseUrl/api/users/me/hospitals'); // 기본: APPROVED만
      final res = await _http
          .get(
        uri,
        headers: {
          if (widget.token != null && widget.token!.isNotEmpty)
            'Authorization': 'Bearer ${widget.token}', // ✅ 토큰 추가
        },
      )
          .timeout(_timeout);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List list = body is List ? body : (body['data'] as List? ?? []);
        final items = list.map((e) {
          return _LinkedHospital(
            id: (e['hospitalId'] ?? e['_id'] ?? '').toString(),
            name: (e['hospitalName'] ?? e['name'] ?? '이름없음').toString(),
            linkedAt: DateTime.tryParse((e['linkedAt'] ?? '').toString()),
          );
        }).toList();

        // 최신 연동이 위
        items.sort((a, b) {
          final aa = a.linkedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bb = b.linkedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bb.compareTo(aa);
        });

        setState(() {
          _linked = items;
          _loading = false;
        });
      } else if (res.statusCode == 401) {
        setState(() {
          _linked = [];
          _loading = false;
          _error = '세션이 만료되었거나 로그인 정보가 없습니다.';
        });
      } else {
        setState(() {
          _linked = [];
          _loading = false;
          _error = '서버 오류 (${res.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _linked = [];
        _loading = false;
        _error = '네트워크 오류: $e';
      });
    }
  }

  // 병원 메인으로 전환(병원 선택 후)
  void _goHospitalMain(_LinkedHospital h) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => UserMyHospitalMainScreen(
          token: widget.token ?? '',
          hospitalId: h.id,
          hospitalName: h.name,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  // 병원 연동하기 화면으로 이동
  void _openConnectionPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserHospitalConnectionPage(token: widget.token),
      ),
    );
    // 돌아왔을 때 목록 새로고침
    if (mounted) _loadLinkedHospitals();
  }

  @override
  Widget build(BuildContext context) {
    final topYellow = const Color(0xFFFFF4B8); // 연노랑(스샷톤)

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: AppBar(
          elevation: 0,
          backgroundColor: topYellow,
          centerTitle: true,
          title: const Text(
            '내 병원',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
          ),
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
      ),

      // ✅ 전체 바디에 노란 배경 적용 (리스트 + 하단 버튼 영역 모두)
      body: SafeArea(
        child: Container(
          color: topYellow,
          child: RefreshIndicator(
            onRefresh: _loadLinkedHospitals,
            child: Column(
              children: [
                // 리스트 영역
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : (_linked.isEmpty
                      ? _EmptyState(
                    error: _error,
                    onConnectTap: _openConnectionPage,
                  )
                      : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _linked.length,
                    itemBuilder: (_, i) {
                      final h = _linked[i];
                      return _LinkedHospitalRow(
                        name: h.name,
                        onMove: () => _goHospitalMain(h),
                      );
                    },
                  )),
                ),

                // 하단 "병원 연동하기" 버튼 (가운데)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: SizedBox(
                    width: 180,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _openConnectionPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: const Text('병원 연동하기'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // ✅ 하단 네비게이션바: 단독 화면일 때만 노출 (탭 내부에서는 숨김)
      bottomNavigationBar: widget.showBottomNav
          ? BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 2, // ‘내 병원’ 탭
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black45,
        onTap: (i) {
          switch (i) {
            case 0:
              _noAnimReplace(PetHomeScreen(token: widget.token ?? ''));
              break;
            case 1:
            // ✅ 건강관리로 이동 (수정됨)
              _noAnimReplace(HealthDashboardScreen(token: widget.token ?? ''));
              break;
            case 2:
            // 현재 화면
              break;
            case 3:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('마이페이지는 준비 중입니다.')),
              );
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(
              icon: Icon(Icons.health_and_safety_outlined), label: '건강관리'),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_hospital_outlined), label: '내 병원'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: '마이페이지'),
        ],
      )
          : null,
    );
  }
}

// ===== 모델/위젯 =====

class _LinkedHospital {
  final String id;
  final String name;
  final DateTime? linkedAt;

  _LinkedHospital({
    required this.id,
    required this.name,
    this.linkedAt,
  });
}

class _LinkedHospitalRow extends StatelessWidget {
  final String name;
  final VoidCallback onMove;

  const _LinkedHospitalRow({
    super.key,
    required this.name,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: onMove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('이동', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: Colors.grey.shade300),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String? error;
  final VoidCallback onConnectTap;

  const _EmptyState({super.key, this.error, required this.onConnectTap});

  @override
  Widget build(BuildContext context) {
    final subtle = Colors.black54;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 40),
        Icon(Icons.local_hospital_outlined, size: 56, color: subtle),
        const SizedBox(height: 10),
        Text(
          error == null ? '연동된 병원이 없습니다.' : error!,
          textAlign: TextAlign.center,
          style: TextStyle(color: subtle),
        ),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: onConnectTap,
              child: const Text('병원 연동하기'),
            ),
          ),
        ),
      ],
    );
  }
}
