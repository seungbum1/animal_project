import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'user_mainscreen.dart';
import 'user_health_main.dart';
import 'user_myhospital_list.dart';
import 'user_pet_report.dart';
import 'hospital_list_page.dart';
import 'user_medication_alarm_add_edit_screen.dart';
import 'user_medication_alarm_list_screen.dart';
import 'package:animal_project/user_health_dashboard_viewmodel.dart';

import 'user_health_diary_screen.dart';
import 'user_medication_alarm_list_screen.dart';
import 'package:animal_project/user/user_product_page.dart';
import 'package:animal_project/user/user_product_favorite_page.dart';
import 'package:animal_project/user/user_product_payment_history.dart';

import '../hospital_list_page.dart';
import 'login.dart';

class UserMyPageScreen extends StatefulWidget {
  final String token;
  const UserMyPageScreen({super.key, required this.token});

  @override
  State<UserMyPageScreen> createState() => _UserMyPageScreenState();
}

class _UserMyPageScreenState extends State<UserMyPageScreen> {
  bool _loading = true;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _pet;

  static String get _baseUrl => ApiConfig.baseUrl;

  // ⚡ userId 저장
  String? _userId;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/users/me'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (res.statusCode == 200) {
        final jsonBody = json.decode(res.body);
        final user = jsonBody['user'];
        final petProfile = user?['petProfile'];

        setState(() {
          _user = user;
          _pet = (petProfile is Map<String, dynamic>) ? petProfile : null;
          _userId = user?['_id']; // 저장
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updatePetProfile({
    required String name,
    required String age,
    required String gender,
    required String species,
  }) async {
    try {
      final body = json.encode({
        'name': name,
        'age': int.tryParse(age) ?? 0,
        'gender': gender,
        'species': species,
      });

      await http.put(
        Uri.parse('$_baseUrl/users/me/pet'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      await _fetchUserData();
    } catch (e) {}
  }

  void _editProfile() {
    if (_pet == null) return;

    final nameCtrl = TextEditingController(text: _pet?['name'] ?? '');
    final ageCtrl = TextEditingController(text: _pet?['age']?.toString() ?? '');
    final genderCtrl = TextEditingController(text: _pet?['gender'] ?? '');
    final speciesCtrl = TextEditingController(text: _pet?['species'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('반려동물 정보 수정'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '이름')),
              TextField(controller: ageCtrl, decoration: const InputDecoration(labelText: '나이'), keyboardType: TextInputType.number),
              TextField(controller: genderCtrl, decoration: const InputDecoration(labelText: '성별')),
              TextField(controller: speciesCtrl, decoration: const InputDecoration(labelText: '품종')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updatePetProfile(
                name: nameCtrl.text,
                age: ageCtrl.text,
                gender: genderCtrl.text,
                species: speciesCtrl.text,
              );
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _noAnimReplace(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  // ⭐ 로그아웃 Dialog (추가)
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("로그아웃"),
        content: const Text("정말 로그아웃 하시겠습니까?"),
        actionsAlignment: MainAxisAlignment.spaceEvenly, // 버튼 간격 정렬
        actions: [
          // 👉 "예" 버튼 먼저
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
              );
            },
            child: const Text(
              "예",
              style: TextStyle(
                color: Colors.red, // 빨간 글씨
                fontSize: 16,
              ),
            ),
          ),

          // 👉 "아니오" 버튼
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "아니오",
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }


  // 메뉴 이동
  void _goTo(String name) {
    switch (name) {
      case '병원 즐겨찾기':
        Navigator.push(context, MaterialPageRoute(builder: (_) => UserMyHospitalListPage(token: widget.token)));
        break;

      case '건강 차트':
        Navigator.push(context, MaterialPageRoute(builder: (_) => HealthDashboardScreen(token: widget.token)));
        break;

      case '건강 일기':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HealthDiaryScreen(
              viewModel: HealthDashboardViewModel(token: widget.token),
            ),
          ),
        );
        break;



      case '복약 알림설정':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MedicationAlarmListScreen(
              token: widget.token,
              initialAlarms: const [],
            ),
          ),
        );
        break;

      case '쇼핑 둘러보기':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProductPage()));
        break;

      case '장바구니':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProductFavoritePage()));
        break;

      case '주문내역':
        if (_userId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("유저 정보를 불러오는 중입니다.")),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProductPaymentHistoryPage(userId: _userId!),
          ),
        );
        break;

      case '카페':
      case '식당':
      case '숙소':
      case '유치원':
        break;

      case '문의하기':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('문의하기 준비 중입니다.')),
        );
        break;

      case '로그아웃': // ⭐ 추가
        _showLogoutDialog();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = _pet ?? {};

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF2B6),
        elevation: 0,
        title: const Text('마이페이지', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_pet == null)
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('아직 등록된 반려동물 정보가 없습니다.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => UserPetReportPage(token: widget.token)),
                );
              },
              child: const Text('프로필 등록하러 가기'),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 프로필 카드
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7C8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.grey),
                    alignment: Alignment.center,
                    child: const Icon(Icons.pets, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pet['name'] ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        Text('나이: ${pet['age'] ?? '-'}살 · ${pet['species'] ?? '-'} (${pet['gender'] ?? '-'})'),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.edit), onPressed: _editProfile),
                ],
              ),
            ),

            const SizedBox(height: 20),

            ExpansionTile(title: const Text('병원'), children: [_categoryTile('병원 즐겨찾기')]),
            ExpansionTile(title: const Text('건강'), children: [
              _categoryTile('건강 차트'),
              _categoryTile('건강 일기'),
              _categoryTile('복약 알림설정'),
            ]),
            ExpansionTile(title: const Text('상품'), children: [
              _categoryTile('쇼핑 둘러보기'),
              _categoryTile('장바구니'),
              _categoryTile('주문내역'),
            ]),
            ExpansionTile(title: const Text('즐겨찾기 장소'), children: [
              _categoryTile('카페'),
              _categoryTile('식당'),
              _categoryTile('숙소'),
              _categoryTile('유치원'),
            ]),
            ExpansionTile(title: const Text('고객센터'), children: [
              _categoryTile('문의하기'),
            ]),

            const SizedBox(height: 20),

            // ⭐ 로그아웃 버튼 (추가)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                onPressed: _showLogoutDialog,
                child: const Text('로그아웃', style: TextStyle(color: Colors.black87)),
              ),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 3,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black45,
        onTap: (i) {
          switch (i) {
            case 0:
              _noAnimReplace(PetHomeScreen(token: widget.token));
              break;
            case 1:
              _noAnimReplace(HealthDashboardScreen(token: widget.token));
              break;
            case 2:
              _noAnimReplace(UserMyHospitalListPage(token: widget.token));
              break;
            case 3:
              break; // 현재 페이지
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(
            icon: Icon(Icons.health_and_safety_outlined),
            label: '건강관리',
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

  Widget _categoryTile(String name) {
    return ListTile(
      title: Text(name),
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      onTap: () => _goTo(name),
    );
  }
}
