import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'login.dart';
import 'hospital_report.dart';


/// 병원 관리자 메인 화면
/// 로그인 성공 시: HospitalMainScreen(
///   token: <로그인 응답 토큰>,
///   hospitalName: <관리자 병원이름>
/// )
class HospitalMainScreen extends StatefulWidget {
  const HospitalMainScreen({
    super.key,
    required this.token,
    required this.hospitalName,
  });

  final String token;         // ✅ API 호출에 사용
  final String hospitalName;  // 상단 타이틀 표기

  @override
  State<HospitalMainScreen> createState() => _HospitalMainScreenState();
}

class _HospitalMainScreenState extends State<HospitalMainScreen> {
  int _currentIndex = 0; // 하단 탭: 홈 기본

  // ----- 데모용 예약 헤더 문구(그대로 유지) -----
  final String _reserveHeader = '진료 예약 신청 내역';
  final String _reserveNotice = '9/17일 다롱 건강검진 진료 예약 1건이 있습니다.';

  // ----- 서버 연동 상태 -----
  bool _loading = true;
  String? _error;
  final List<_PendingReq> _pendingList = [];

  // =========================
  // 백엔드 베이스 URL 자동 선택
  // =========================
  static String get _baseUrl {
    if (Platform.isAndroid) return 'http://10.0.2.2:4000';
    return 'http://localhost:4000';
  }

  http.Client get _http => http.Client();
  Duration _timeout = const Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _fetchPending();
  }

  // 대기목록 불러오기
  Future<void> _fetchPending() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('$_baseUrl/api/hospital-admin/requests');
      final res = await _http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(_timeout);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List list = body is List ? body : (body['data'] as List? ?? []);

        _pendingList
          ..clear()
          ..addAll(list.map((e) => _PendingReq.fromJson(e)));

        setState(() => _loading = false);
      } else {
        setState(() {
          _loading = false;
          _error = '서버 오류 (${res.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '네트워크 오류: $e';
      });
    }
  }

  // 승인/거절 공통 호출
  Future<void> _decide({
    required _PendingReq req,
    required bool approve,
  }) async {
    // 낙관적 제거
    final int idx = _pendingList.indexWhere((r) => r.id == req.id);
    if (idx < 0) return;

    final removed = _pendingList.removeAt(idx);
    setState(() {});

    try {
      final path = approve ? 'approve' : 'reject';
      final uri = Uri.parse('$_baseUrl/api/hospital-admin/requests/${req.id}/$path');
      final res = await _http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      if (res.statusCode == 200) {
        _toast(approve ? '승인 완료' : '거절 완료');
      } else {
        // 롤백
        _pendingList.insert(idx, removed);
        setState(() {});
        _toast('처리 실패 (${res.statusCode})');
      }
    } catch (e) {
      // 롤백
      _pendingList.insert(idx, removed);
      setState(() {});
      _toast('네트워크 오류로 처리 실패');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF2B6), // 옅은 노랑
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.hospitalName,
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black87),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            tooltip: '메뉴',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black87),
            onPressed: () => _toast('알림함 준비 중'),
            tooltip: '알림',
          ),
        ],
      ),

      drawer: const _SimpleDrawer(),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchPending,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ① 진료 예약 신청 내역 헤더
                Text(
                  _reserveHeader,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _reserveNotice,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black87),
                  ),
                ),

                const SizedBox(height: 22),

                // ② 병원 스케줄 섹션
                Row(
                  children: [
                    Text(
                      '병원 스케줄을 간편하게 확인하고 관리하세요.',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 달력 이미지/자리(플레이스홀더)
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(child: CustomPaint(painter: _GridPainter())),
                      Center(
                        child: Text(
                          '캘린더 위젯 영역',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ③ 승인 관리 섹션
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '승인 관리로 병원 업무를 간편하게 운영하세요.',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _fetchPending,
                      child: const Text('확인하기 >'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ---- 승인 카드 (서버 데이터 바인딩) ----
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildApprovalCardBody(theme),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),

      // 하단 네비게이션 (아이콘/라벨 2번 스샷 느낌)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          switch (i) {
            case 0:
              _toast('홈');
              break;
            case 1:
              _toast('진료내역');
              break;
            case 2:
              _toast('긴급호출');
              break;
            case 3:
              _toast('마이페이지');
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: '진료내역'),
          BottomNavigationBarItem(icon: Icon(Icons.sos_outlined), label: '긴급호출'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '마이페이지'),
        ],
      ),
    );
  }

  Widget _buildApprovalCardBody(ThemeData theme) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: OutlinedButton.icon(
                onPressed: _fetchPending,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 불러오기'),
              ),
            ),
          ],
        ),
      );
    }
    if (_pendingList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Text('승인 대기 요청이 없습니다.', style: TextStyle(color: Colors.black54)),
      );
    }

    return Column(
      children: _pendingList
          .map((e) => _ApprovalRow(
        nameAndPet: '${e.userName}/${e.petName}'.trim().replaceAll(RegExp(r'^/|/$'), ''),
        onApprove: () => _decide(req: e, approve: true),
        onReject: () => _decide(req: e, approve: false),
      ))
          .toList(),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 900)),
    );
  }
}

/// 승인 대기 항목 모델
class _PendingReq {
  final String id;
  final String userName;
  final String petName;
  final DateTime? createdAt;

  _PendingReq({
    required this.id,
    required this.userName,
    required this.petName,
    this.createdAt,
  });

  factory _PendingReq.fromJson(Map<String, dynamic> j) => _PendingReq(
    id: (j['_id'] ?? '').toString(),
    userName: (j['userName'] ?? '').toString(),
    petName: (j['petName'] ?? '').toString(),
    createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()),
  );
}

/// 승인 항목 한 줄 UI
class _ApprovalRow extends StatelessWidget {
  const _ApprovalRow({
    required this.nameAndPet,
    required this.onApprove,
    required this.onReject,
  });

  final String nameAndPet;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nameAndPet.isEmpty ? '신청자' : nameAndPet,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onApprove,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF4A7BFF),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('승인'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onReject,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFFE86161),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('거절'),
          ),
        ],
      ),
    );
  }
}

/// 사이드 드로어 (간단)
class _SimpleDrawer extends StatelessWidget {
  const _SimpleDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFFFFF2B6)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('관리자 메뉴',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('병원 운영 메뉴를 선택하세요', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const _DrawerTile(icon: Icons.event_available, title: '예약 관리'),
            const _DrawerTile(icon: Icons.people_alt_outlined, title: '고객 관리'),
            const _DrawerTile(icon: Icons.medical_services_outlined, title: '의료진 스케줄'),
            const _DrawerTile(icon: Icons.settings_outlined, title: '설정'),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () => Navigator.pop(context),
    );
  }
}

/// 심플 그리드(달력 느낌) 페인터
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFECECEC)
      ..strokeWidth = 1;

    const cols = 7;
    const rows = 5;

    final cellW = size.width / cols;
    final cellH = size.height / rows;

    for (var c = 1; c < cols; c++) {
      final x = c * cellW;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var r = 1; r < rows; r++) {
      final y = r * cellH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
