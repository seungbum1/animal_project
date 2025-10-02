// user_myhospital_mainscreen.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'user_mainscreen.dart';              // 홈 탭에서 사용
import 'user_myhospital_list.dart';         // 뒤로가기시 목록으로

class UserMyHospitalMainScreen extends StatefulWidget {
  final String token;
  final String hospitalId;
  final String hospitalName;

  const UserMyHospitalMainScreen({
    super.key,
    required this.token,
    required this.hospitalId,
    required this.hospitalName,
  });

  @override
  State<UserMyHospitalMainScreen> createState() => _UserMyHospitalMainScreenState();
}

class _UserMyHospitalMainScreenState extends State<UserMyHospitalMainScreen> {
  static String get _baseUrl {
    if (Platform.isAndroid) return 'http://10.0.2.2:4000';
    return 'http://localhost:4000';
  }

  final _http = http.Client();
  Duration _timeout = const Duration(seconds: 8);

  // 화면 상태
  bool _loading = true;
  String? _error;

  // 병원별 대시보드 데이터(샘플/서버연동)
  String _notice = '';                 // 병원 공지
  String _nextApptText = '';           // 다음 예약 텍스트

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 서버에 병원별 사용자 대시보드 API가 있으면 여기에 붙여 쓰면 됨.
      // 없으면 아래 폴백이 그대로 표시됨.
      final uri = Uri.parse('$_baseUrl/api/hospitals/${widget.hospitalId}/user-dashboard');
      final res = await _http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(_timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _notice = (data['notice'] ?? '') as String;
          _nextApptText = (data['nextAppointment'] ?? '') as String;
          _loading = false;
        });
      } else {
        _useFallback('(${res.statusCode}) 서버 응답 오류');
      }
    } catch (e) {
      _useFallback(e.toString());
    }
  }

  void _useFallback(String? err) {
    setState(() {
      _error = err;
      // 병원마다 다른 내용을 보여줄 수 있도록 hospitalName 기반으로 더미 문구 생성
      _notice = '병원 공지사항 : ${widget.hospitalName} 휴무일은 매주 일요일입니다.';
      _nextApptText = '9/08 (월) : 초음파 검사';
      _loading = false;
    });
  }

  // 하단 네비게이션 공통
  void _goNoAnim(Widget page) {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final topYellow = const Color(0xFFFFF4B8);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: topYellow,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          widget.hospitalName, // ✅ 리스트에서 넘겨준 병원명이 그대로 뜸
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
          tooltip: '메뉴',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => _toast('알림함 준비 중'),
            tooltip: '알림',
          ),
        ],
      ),

      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: const [
              _DrawerHeader(),
              _DrawerTile(icon: Icons.receipt_long_outlined, title: '진료 내역'),
              _DrawerTile(icon: Icons.event_available, title: '진료 예약'),
              _DrawerTile(icon: Icons.image_outlined, title: '공유 앨범'),
              _DrawerTile(icon: Icons.settings_outlined, title: '설정'),
            ],
          ),
        ),
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 공지 배너
                _BannerNotice(
                  loading: _loading,
                  text: _notice.isEmpty ? '공지 없음' : _notice,
                ),
                const SizedBox(height: 12),

                // 진료 예약 일정 안내 버튼
                Center(
                  child: OutlinedButton(
                    onPressed: () => _toast('예약 일정 안내 열기'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: const StadiumBorder(),
                      side: const BorderSide(color: Colors.black54),
                      foregroundColor: Colors.black87,
                    ),
                    child: const Text('진료 예약 일정 안내'),
                  ),
                ),
                const SizedBox(height: 12),

                // 다음 예약 텍스트
                if (_loading)
                  const _SkeletonLine()
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      _nextApptText.isEmpty ? '예정된 예약이 없습니다.' : _nextApptText,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),

                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey.shade400),
                const SizedBox(height: 12),

                // 병원 사진/앨범(플레이스홀더)
                Row(
                  children: [
                    Text(
                      _loading ? '— / — / —' : _formatToday(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => _toast('더보기'),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Text('더보기', style: TextStyle(decoration: TextDecoration.underline)),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 140,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('간호사가 올려준 병원에\n있는 내 반려동물 사진', textAlign: TextAlign.center),
                ),

                const SizedBox(height: 16),

                // 아이콘 두 개 (진료 내역 / 진료 예약)
                Row(
                  children: [
                    Expanded(
                      child: _IconTile(
                        label: '진료 내역',
                        onTap: () => _toast('진료 내역 열기'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _IconTile(
                        label: '진료 예약',
                        onTap: () => _toast('진료 예약 열기'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 병원 스케줄 관리
                const Center(
                  child: Text(
                    '병원 스케줄 관리',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 220,
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
                  child: CustomPaint(painter: _CalendarPainter()),
                ),

                const SizedBox(height: 24),

                // 1:1 채팅 문의
                Center(
                  child: SizedBox(
                    width: 180,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => _toast('1:1 채팅 문의'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFF4B8),
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: const Text('1:1 채팅 문의'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),

      // ✅ 하단 네비게이션: 기존과 동일
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 2, // "내 병원"
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black45,
        onTap: (i) {
          switch (i) {
            case 0:
              _goNoAnim(PetHomeScreen(token: widget.token));
              break;
            case 1:
              _toast('건강관리는 준비 중입니다.');
              break;
            case 2:
            // 현재 화면
              break;
            case 3:
              _toast('마이페이지는 준비 중입니다.');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.health_and_safety_outlined), label: '건강관리'),
          BottomNavigationBarItem(icon: Icon(Icons.local_hospital_outlined), label: '내 병원'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '마이페이지'),
        ],
      ),

      // 뒤로가기(상단 제스처/버튼) 시 목록으로
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  String _formatToday() {
    final now = DateTime.now();
    return '${now.year}/${_two(now.month)}/${_two(now.day)}';
    // 필요하면 병원 데이터의 촬영일/업로드일로 변경
  }

  String _two(int n) => n < 10 ? '0$n' : '$n';

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 900)),
    );
  }
}

// ───────────────────────── UI 위젯들 ─────────────────────────

class _BannerNotice extends StatelessWidget {
  const _BannerNotice({required this.loading, required this.text});
  final bool loading;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(6),
      ),
      child: loading
          ? const _SkeletonLine()
          : Text(text, style: const TextStyle(color: Colors.black87)),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _IconTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          Container(
            height: 90,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('아이콘\n이미지', textAlign: TextAlign.center),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();
  @override
  Widget build(BuildContext context) {
    return DrawerHeader(
      decoration: const BoxDecoration(color: Color(0xFFFFF4B8)),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          '관리자 메뉴',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  const _DrawerTile({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () => Navigator.pop(context),
    );
  }
}

class _CalendarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFECECEC)
      ..strokeWidth = 1;

    const cols = 7, rows = 6;
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    for (var c = 1; c < cols; c++) {
      final x = c * cellW;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var r = 1; r < rows; r++) {
      final y = r * cellH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
