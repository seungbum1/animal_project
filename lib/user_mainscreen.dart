// pet_home_screen.dart
// 사용자 메인 화면
import 'dart:convert';

import 'api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'user_myhospital_list.dart';
import 'login.dart';
import 'user_pet_report.dart';
import 'user_health_main.dart';

class PetHomeScreen extends StatefulWidget {
  final String token; // 로그인에서 받은 JWT
  final bool showBottomNav;
  const PetHomeScreen({super.key, required this.token, this.showBottomNav = true,});

  @override
  State<PetHomeScreen> createState() => _PetHomeScreenState();
}

class _PetHomeScreenState extends State<PetHomeScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  // 서버에서 받아올 값들
  String petName = '';
  int petAge = 0;
  String petGender = '';
  String petSpecies = '';
  String avatarUrl = '';

  bool loading = true;
  String? error;

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
    _fetchMyProfile();
  }

  Future<void> _fetchMyProfile() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/users/me'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final user = (data['user'] as Map<String, dynamic>);
        final pet = (user['petProfile'] as Map?) ?? {};
        setState(() {
          petName = (pet['name'] ?? '') as String;
          petAge = (pet['age'] ?? 0) as int;
          petGender = (pet['gender'] ?? '') as String;
          petSpecies = (pet['species'] ?? '') as String;
          avatarUrl = (pet['avatarUrl'] ?? '') as String;
          loading = false;
        });
      } else {
        setState(() {
          error = '불러오기 실패 (${resp.statusCode})';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = '네트워크 오류: $e';
        loading = false;
      });
    }
  }

  // ───────────────────── 상단 프로필 카드 + 빈 프로필 배너
  Widget _profileCard() {
    final hasProfile =
        petName.isNotEmpty || petAge > 0 || petGender.isNotEmpty || petSpecies.isNotEmpty;

    return Column(
      children: [
        // 상단 프로필 카드
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF2B6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 이름(타이틀 스타일)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      petName.isNotEmpty ? '$petName님 ▼' : '내 반려동물 ▼',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('나이 : ${petAge > 0 ? '$petAge살' : '-'}'),
                        const SizedBox(width: 10),
                        Text(petSpecies.isNotEmpty ? petSpecies : '종 : -'),
                        const SizedBox(width: 10),
                        Text('성별 : ${petGender.isNotEmpty ? petGender : '-'}'),
                      ],
                    ),
                  ],
                ),
              ),
              // 아바타
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  image: avatarUrl.isNotEmpty
                      ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: avatarUrl.isEmpty
                    ? const Icon(Icons.pets, size: 24, color: Colors.black54)
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 복용 시간 배너(알림 박스)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEDEDED),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            '3시간 뒤에 ~~약 복용할 시간입니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 10),

        // 프로필이 비어있으면 안내 배너 + 이동 버튼
        if (!hasProfile)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text('반려동물 프로필이 비어 있습니다. 등록해 주세요.')),
                TextButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserPetReportPage(token: widget.token),
                      ),
                    );
                    if (mounted) _fetchMyProfile();
                  },
                  child: const Text('프로필 등록'),
                )
              ],
            ),
          ),
      ],
    );
  }

  // ───────────────────── 아이콘 + 라벨 위젯
  Widget _roundMapIcon(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Color(0xFFFFEAEA),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.red, size: 24),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ───────────────────── 병원 검색 + 스케줄 영역
  Widget _hospitalSchedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "병원 검색" 라벨
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 6),
          child: Text('병원 검색', style: TextStyle(color: Colors.black54)),
        ),
        // 캘린더 상단 타이틀
        const Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              '병원 스케줄 관리',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        // 달력 자리(플레이스홀더)
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(child: Text('캘린더 자리')),
        ),
      ],
    );
  }

  // ───────────────────── 산책 리스트
  Widget _walkSection() {
    return Column(
      children: [
        // 타이틀 라인
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('다롱이와 산책', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('산책하기 >', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        // 리스트 3개
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, index) => Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('부천대책교  25.9.30', style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text('00Km   별점  5.1포인트', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 120,
          height: 36,
          child: OutlinedButton(
            onPressed: () {},
            child: const Text('더보기'),
          ),
        ),
      ],
    );
  }

  // ───────────────────── 쇼핑 그리드
  Widget _shopSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('다롱님의 필요한 물품 어때요?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 9,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) => Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 60,
                  width: 60,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image),
                ),
                const SizedBox(height: 8),
                const Text(
                  '상품 이름',
                  style: TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                const Text(
                  '20,000원',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: SizedBox(
            width: 120,
            height: 36,
            child: OutlinedButton(
              onPressed: () {},
              child: const Text('더보기'),
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────── 본문(스크롤)
  Widget _body() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _profileCard(),
          const SizedBox(height: 12),
          _hospitalSchedule(),
          const SizedBox(height: 18),

          // 지도 아이콘 4개 + 라벨
          const Text('다롱이와 함께 떠나는 즐거운 나들이!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _roundMapIcon(Icons.local_cafe, '카페'),
              _roundMapIcon(Icons.restaurant, '식당'),
              _roundMapIcon(Icons.hotel, '숙소'),
              _roundMapIcon(Icons.local_play, '유치원'),
            ],
          ),
          const SizedBox(height: 18),

          _walkSection(),
          const SizedBox(height: 16),

          _shopSection(),
        ],
      ),
    );
  }

  // ───────────────────── Build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      // 상단바
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF2B6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () {},
        ),
        title: Row(
          children: [
            // 빨간 원(프로필 점) 느낌
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              petName.isNotEmpty ? '$petName님 ▼' : '내 반려동물 ▼',
              style: const TextStyle(color: Colors.black),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black87),
            onPressed: _fetchMyProfile,
            tooltip: '새로고침',
          ),
        ],
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (error != null
          ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
          : _body()),

      // 하단 네비게이션바 (다른 화면들과 동일 패턴)
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0, // 홈 탭
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black45,
        onTap: (i) {
          switch (i) {
            case 0:
            // 이미 홈이므로 아무 것도 하지 않음
              break;
            case 1:
              _noAnimReplace(HealthDashboardScreen(token: widget.token));
              break;
            case 2:
              _noAnimReplace(UserMyHospitalListPage(token: widget.token));
              break;
            case 3:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('마이페이지는 준비 중입니다.')),
              );
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "홈"),
          BottomNavigationBarItem(
              icon: Icon(Icons.health_and_safety_outlined), label: '건강관리'),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_hospital_outlined), label: "내 병원"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: "마이페이지"),
        ],
      ),
    );
  }
}
