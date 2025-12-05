// user_myhospital_list.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 햅틱
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'user_health_main.dart';
import 'user_mainscreen.dart';
import 'user_hospital_connection.dart';
import 'user_myhospital_mainscreen.dart';

// 🎨 Design Token from HospitalDetailPage
const Color kPrimaryColor = Color(0xFFC06362);
const Color kPrimaryLight = Color(0xFFFDECEC);
const Color kBackgroundColor = Color(0xFFF9F9F9); // Detail Page 배경색 통일
const Color kSurfaceWhite = Colors.white;
const Color kTextBlack = Color(0xFF222222);
const Color kTextGrey = Color(0xFF888888);

class UserMyHospitalListPage extends StatefulWidget {
  final String? token;
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
  static String get _baseUrl => ApiConfig.baseUrl;
  final http.Client _http = http.Client();

  List<_LinkedHospital> _linked = [];
  bool _loading = true;
  String? _error;

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
    setState(() { _loading = true; _error = null; });
    try {
      final uri = Uri.parse('$_baseUrl/api/users/me/hospitals');
      final res = await _http.get(
        uri,
        headers: {
          if (widget.token != null) 'Authorization': 'Bearer ${widget.token}',
        },
      ).timeout(const Duration(seconds: 8));

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

        // 최신순 정렬
        items.sort((a, b) => (b.linkedAt ?? DateTime(0)).compareTo(a.linkedAt ?? DateTime(0)));

        if (mounted) setState(() { _linked = items; _loading = false; });
      } else {
        if (mounted) setState(() { _linked = []; _loading = false; _error = '불러오기 실패'; });
      }
    } catch (e) {
      if (mounted) setState(() { _linked = []; _loading = false; _error = '네트워크 오류'; });
    }
  }

  void _goHospitalMain(_LinkedHospital h) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => UserMyHospitalMainScreen(
        token: widget.token ?? '',
        hospitalId: h.id,
        hospitalName: h.name,
      ),
    ));
  }

  void _openConnectionPage() async {
    HapticFeedback.mediumImpact();
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => UserHospitalConnectionPage(token: widget.token),
    ));
    if (mounted) _loadLinkedHospitals();
  }

  void _noAnimReplace(Widget page) {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: kBackgroundColor,
        centerTitle: false,
        title: const Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: Text(
            '내 병원 목록',
            style: TextStyle(
                color: kTextBlack,
                fontWeight: FontWeight.w800,
                fontSize: 24 // 폰트 사이즈 살짝 키움 (헤더 강조)
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadLinkedHospitals();
            },
            icon: const Icon(Icons.refresh_rounded, color: kTextGrey),
          )
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator.adaptive(backgroundColor: kPrimaryColor))
            : _linked.isEmpty
            ? _buildEmptyState()
            : _buildList(),
      ),
      bottomNavigationBar: widget.showBottomNav ? _buildBottomNav() : null,

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openConnectionPage,
        backgroundColor: kPrimaryColor, // 브랜드 컬러 적용
        elevation: 4,
        icon: const Icon(Icons.add_link_rounded, color: Colors.white),
        label: const Text("새 병원 연동", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _linked.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16), // 간격 조금 넓힘
      itemBuilder: (context, index) {
        final hospital = _linked[index];
        return _buildHospitalCard(hospital);
      },
    );
  }

  Widget _buildHospitalCard(_LinkedHospital hospital) {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), // 그림자 더 은은하게
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _goHospitalMain(hospital),
          borderRadius: BorderRadius.circular(20),
          splashColor: kPrimaryColor.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // 병원 아이콘 (브랜드 컬러 배경)
                Container(
                  width: 56, // 사이즈 살짝 키움
                  height: 56,
                  decoration: BoxDecoration(
                    color: kPrimaryLight, // 연한 핑크 배경
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_hospital_rounded, color: kPrimaryColor, size: 26),
                ),
                const SizedBox(width: 18),

                // 텍스트 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hospital.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: kTextBlack,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF6A994E)), // GreenColor from ListPage
                          const SizedBox(width: 4),
                          Text(
                            '연동 완료',
                            style: TextStyle(
                              fontSize: 13,
                              color: kTextGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 이동 화살표
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: kPrimaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.link_off_rounded, size: 60, color: kPrimaryColor.withOpacity(0.8)),
          ),
          const SizedBox(height: 24),
          const Text(
            "아직 연동된 병원이 없어요",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextBlack),
          ),
          const SizedBox(height: 10),
          Text(
            _error ?? "다니시는 동물병원을 찾아 연동해보세요.\n진료 내역과 예약 관리가 편해집니다.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: kTextGrey, height: 1.5),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: 2,
          selectedItemColor: kPrimaryColor, // 메인 컬러 적용
          unselectedItemColor: Colors.grey[400],
          selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          backgroundColor: Colors.white,
          elevation: 0,
          onTap: (i) {
            if (i == 2) return;
            switch (i) {
              case 0: _noAnimReplace(PetHomeScreen(token: widget.token ?? '')); break;
              case 1: _noAnimReplace(HealthDashboardScreen(token: widget.token ?? '')); break;
              case 3: ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('마이페이지 준비 중'))); break;
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: '홈'),
            BottomNavigationBarItem(icon: Icon(Icons.health_and_safety_rounded), label: '건강관리'),
            BottomNavigationBarItem(icon: Icon(Icons.local_hospital_rounded), label: '내 병원'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: '마이페이지'),
          ],
        )
    );
  }
}

class _LinkedHospital {
  final String id;
  final String name;
  final DateTime? linkedAt;
  _LinkedHospital({required this.id, required this.name, this.linkedAt});
}