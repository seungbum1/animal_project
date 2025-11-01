// main_tabs.dart
import 'package:flutter/material.dart';

// 기존 화면들
import 'user_mainscreen.dart';           // PetHomeScreen
import 'user_health_main.dart';          // HealthDashboardScreen
import 'user_myhospital_list.dart';      // UserMyHospitalListPage

class MainTabs extends StatefulWidget {
  final String token;
  const MainTabs({super.key, required this.token});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _index = 0;

  late final List<Widget> _pages = [
    // 탭 안에서는 각 화면의 하단바를 숨긴다 (상태 유지 위해 IndexedStack 사용)
    PetHomeScreen(token: widget.token, showBottomNav: false),
    HealthDashboardScreen(token: widget.token, showBottomNav: false),
    UserMyHospitalListPage(token: widget.token, showBottomNav: false),
    const _MyPageComingSoon(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.health_and_safety_outlined), label: '건강관리'),
          BottomNavigationBarItem(icon: Icon(Icons.local_hospital_outlined), label: '내 병원'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '마이페이지'),
        ],
      ),
    );
  }
}

class _MyPageComingSoon extends StatelessWidget {
  const _MyPageComingSoon();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Text('마이페이지는 준비 중입니다.', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
