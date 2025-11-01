// user_search_hospital.dart.

import 'package:flutter/material.dart';
import 'login.dart';

class UserSearchHospitalPage extends StatefulWidget {
  const UserSearchHospitalPage({super.key});

  @override
  State<UserSearchHospitalPage> createState() => _UserSearchHospitalPageState();
}

class _UserSearchHospitalPageState extends State<UserSearchHospitalPage> {
  int _bottomIndex = 2; // "내 병원" 탭이 선택된 상태로 시작
  String _selectedHospital = '하이스 병원';

  @override
  Widget build(BuildContext context) {
    final yellow = Colors.amber[100];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 헤더
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: yellow,
              child: const Center(
                child: Text(
                  '내 반려동물 병원 연동하기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ),

            // 스크롤 영역
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 현재 체험할 수 있는 병원
                    const Text(
                      '현재 체험할 수 있는 병원',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // 병원 선택(드롭다운 느낌의 박스)
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              // TODO: 병원 선택 BottomSheet/페이지 연결
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedHospital,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Icon(Icons.expand_more, color: Colors.black54),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 연동 버튼
                        SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {
                              // TODO: 연동 처리
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              foregroundColor: Colors.black,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '연동',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE5E5E5)),
                    const SizedBox(height: 20),

                    // 병원 검색 타이틀
                    const Text(
                      '병원 검색',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 지역 + 검색 아이콘
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '경기도 김포시',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            // TODO: 검색 액션
                          },
                          icon: const Icon(Icons.search, size: 28),
                          color: Colors.black,
                          splashRadius: 22,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 병원 카드 리스트(placeholder)
                    const HospitalPlaceholderCard(),
                    const SizedBox(height: 16),
                    const _HospitalNamePlaceholder(),
                    const SizedBox(height: 24),

                    const HospitalPlaceholderCard(),
                    const SizedBox(height: 16),
                    const _HospitalNamePlaceholder(),
                    const SizedBox(height: 24),

                    // 필요하면 더 추가
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // 하단 네비게이션
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: (i) {
          setState(() => _bottomIndex = i);
          // TODO: 각 탭 라우팅 연결
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: '메인화면',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store_mall_directory_outlined),
            label: '쇼핑',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital_outlined),
            label: '내 병원',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: '마이페이지',
          ),
        ],
      ),
    );
  }
}

/// 큰 회색 박스(병원 이미지 placeholder)
class HospitalPlaceholderCard extends StatelessWidget {
  const HospitalPlaceholderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: const Text(
        '병원 이미지',
        style: TextStyle(
          fontSize: 22,
          color: Colors.black,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 이미지 아래 "병원 이름" 텍스트 placeholder
class _HospitalNamePlaceholder extends StatelessWidget {
  const _HospitalNamePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '병원 이름',
      style: TextStyle(
        fontSize: 18,
        color: Colors.black87,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
