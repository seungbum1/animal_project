// pet_home_screen.dart
// 사용자 메인 화면
import 'dart:convert';
import 'dart:io' show Platform;

import '../admin/product.dart'; // ✅ Product 클래스 불러오기
import 'user_product_detail_page.dart'; // ✅ 상세페이지 import
import 'api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // 👈 꼭 상단에 추가
import 'user_myhospital_list.dart';
import 'login.dart';
import 'user_pet_report.dart';
import 'user_hospital_connection.dart'; // ← 내 병원 화면으로 이동
import 'user_product_page.dart'; // ✅ 추가: 상품 목록 페이지 연결
import '../hospital_list_page.dart';

class PetHomeScreen extends StatefulWidget {
  final String token; // 로그인에서 받은 JWT
  const PetHomeScreen({super.key, required this.token});

  @override
  State<PetHomeScreen> createState() => _PetHomeScreenState();
}

class _PetHomeScreenState extends State<PetHomeScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  // ✅ 여기 안으로 옮기기!
  List<dynamic> _allProducts = [];
  List<dynamic> _randomProducts = [];
  String _selectedCategory = '전체';

  Future<void> _fetchProducts() async {
    try {
      final response = await http.get(Uri.parse("http://127.0.0.1:5000/products"));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        data.shuffle(); // 랜덤 섞기
        setState(() {
          _allProducts = data;
          _randomProducts = data.take(10).toList(); // 랜덤 10개만
        });
      } else {
        print("상품 불러오기 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ 상품 불러오기 오류: $e");
    }
  }

  // ✅ Map 데이터를 Product 객체로 변환하는 헬퍼 함수
  Product _mapToProduct(Map<String, dynamic> p) {
    return Product(
      id: p['_id'] ?? '',
      name: p['name'] ?? '',
      category: p['category'] ?? '',
      description: p['description'] ?? '',
      quantity: p['quantity'] ?? 0,
      price: p['price'] ?? 0,
      images: List<String>.from(p['images'] ?? []),
      averageRating: (p['averageRating'] ?? 0).toDouble(),
    );
  }

  // 서버에서 받아올 값들
  String petName = '';
  int petAge = 0;
  String petGender = '';
  String petSpecies = '';
  String avatarUrl = '';

  bool loading = true;
  String? error;

  int _currentIndex = 0; // 하단 네비 현재 탭

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
    _fetchProducts();
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
    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HospitalListPage(category: label), // ✅ 전달
          ),
        );
      },
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEAEA),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.red.shade600, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
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

  // ───────────────────── 랜덤 추천 섹션
  Widget _randomProductSection() {
    if (_randomProducts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '오늘의 추천 상품 💡',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),

        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _randomProducts.length,
            itemBuilder: (context, index) {
              final p = _randomProducts[index];
              final img = (p['images'] != null && p['images'].isNotEmpty)
                  ? "http://127.0.0.1:5000/uploads/${p['images'][0].replaceAll('\\', '/').split('/').last}"
                  : null;
              final price = NumberFormat('#,###').format(p['price'] ?? 0);
              final rating = p['averageRating'] ?? 0.0;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    final product = _mapToProduct(p);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProductDetailPage(
                          product: product,
                          isFavorite: false,
                          onToggleFavorite: (_) {},
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 130,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          blurRadius: 4,
                          offset: const Offset(1, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                          child: img != null
                              ? Image.network(
                            img,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 100,
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image,
                                  size: 40, color: Colors.grey),
                            ),
                          )
                              : Container(
                            height: 100,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image,
                                size: 40, color: Colors.grey),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p['name'] ?? '상품 이름',
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p['category'] ?? '카테고리 없음',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.star,
                                      size: 12, color: Colors.amber),
                                  Text(rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "$price원",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ───────────────────── 카테고리 필터 버튼
  Widget _categoryFilter() {
    final categories = ['전체', '사료', '간식', '용품'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start, // ✅ 왼쪽 정렬
        children: categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = category;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFFF2B6) : Colors.white,
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.orange.shade700 : Colors.black54,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ───────────────────── 다롱님의 필요한 물품 섹션 (추천상품과 동일 디자인)
  Widget _shopSection() {
    final filtered = _selectedCategory == '전체'
        ? _allProducts
        : _allProducts
        .where((p) => (p['category'] ?? '') == _selectedCategory)
        .toList();
    final limited = filtered.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _categoryFilter(),
        const SizedBox(height: 10),

        const Text(
          '다롱님의 필요한 물품 어때요?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: limited.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.75,
          ),
          itemBuilder: (context, index) {
            final p = limited[index];
            final img = (p['images'] != null && p['images'].isNotEmpty)
                ? "http://127.0.0.1:5000/uploads/${p['images'][0].replaceAll('\\', '/').split('/').last}"
                : null;
            final price = NumberFormat('#,###').format(p['price'] ?? 0);
            final rating = p['averageRating'] ?? 0.0;

            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                final product = _mapToProduct(p);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProductDetailPage(
                      product: product,
                      isFavorite: false,
                      onToggleFavorite: (_) {},
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 3,
                      offset: const Offset(1, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(10)),
                      child: img != null
                          ? Image.network(
                        img,
                        height: 90,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 90,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image,
                              size: 40, color: Colors.grey),
                        ),
                      )
                          : Container(
                        height: 90,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image,
                            size: 40, color: Colors.grey),
                      ),
                    ),
                    Padding(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['name'] ?? '상품 이름',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Expanded(
                                child: Text(p['category'] ?? '카테고리 없음',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const Icon(Icons.star,
                                  size: 12, color: Colors.amber),
                              Text(rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text("$price원",
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 8),
        Center(
          child: SizedBox(
            width: 120,
            height: 36,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserProductPage()),
                );
              },
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

          _randomProductSection(), // ✅ 추가
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

      // 하단 네비게이션바
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0, // 홈 탭
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black45, // 나머지 회색
        onTap: (i) {
          switch (i) {
            case 0:
            // 이미 홈이니 아무 것도 안 함
              break;
            case 1:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI 추천은 준비 중입니다.')),
              );
              break;
            case 2:
            // 내 병원
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
          BottomNavigationBarItem(icon: Icon(Icons.health_and_safety_outlined), label: '건강관리'),
          BottomNavigationBarItem(icon: Icon(Icons.local_hospital_outlined), label: "내 병원"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "마이페이지"),
        ],
      ),
    );
  }
}
