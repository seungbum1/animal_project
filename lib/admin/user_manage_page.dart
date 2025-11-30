import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'hospital_approval_page.dart'; // ✅ 병원 승인 화면 import
import 'product_page.dart'; // ✅ 상품 화면 import
import 'admin_main_page.dart'; // ✅ 메인 화면 import
import 'user_detail_page.dart'; // ✅ 사용자 상세 페이지 import
import 'user_point_page.dart'; // ✅ 만보기 포인트 기록 페이지 import
import 'inquiry_page.dart'; // ✅ 문의함 페이지 import
import 'admin_user.dart'; // ✅ User 모델 import

class UserManagePage extends StatefulWidget {
  const UserManagePage({super.key});

  @override
  State<UserManagePage> createState() => _UserManagePageState();
}

class _UserManagePageState extends State<UserManagePage> {
  List<AdminUser> users = [];
  List<AdminUser> filteredUsers = [];
  String _searchQuery = "";

  /// ✅ DB에서 유저 불러오기
  Future<void> _fetchUsers() async {
    try {
      final url = Uri.parse("http://localhost:5000/users"); // 서버 API
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          users = data.map((e) => AdminUser.fromJson(e)).toList();
          filteredUsers = users;
        });
      } else {
        print("❌ 유저 불러오기 실패: ${response.body}");
      }
    } catch (e) {
      print("❌ 오류 발생: $e");
    }
  }

  /// ✅ 검색 필터 적용
  void _applyFilter(String query) {
    setState(() {
      _searchQuery = query;
      filteredUsers = users.where((user) {
        final userName = user.name.toLowerCase();
        final petName = (user.petName ?? "").toLowerCase();
        return userName.contains(query.toLowerCase()) ||
            petName.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchUsers(); // 페이지 켜질 때 DB에서 가져오기
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7CC),
        elevation: 0,
        title: const Text("사용자 관리", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InquiryPage()),
              );
            },
            child: const Text(
              "문의함",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: Column(
        children: [
          // 🔍 검색창
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: _applyFilter,
              decoration: InputDecoration(
                hintText: "사용자이름/반려동물 검색",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 📋 사용자 목록
          Expanded(
            child: filteredUsers.isEmpty
                ? const Center(child: Text("등록된 사용자가 없습니다."))
                : ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) {
                final user = filteredUsers[index];
                return _userItem(
                  context,
                  name: user.name,
                  pet: user.petName ?? "-",
                  status: "0/3", // ⚡️ 나중에 DB 필드 추가 가능
                  color: Colors.grey,
                  point: "0pt", // ⚡️ 포인트도 DB에서 가져오면 됨
                  userId: user.id, // ✅ 여기서 userId만 넘겨줌
                );
              },
            ),
          ),
        ],
      ),

      // ✅ 하단 네비게이션
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        currentIndex: 3,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminMainPage()),
            );
          }
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const HospitalApprovalPage()),
            );
          }
          if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProductPage()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "메인화면"),
          BottomNavigationBarItem(icon: Icon(Icons.verified), label: "병원승인"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: "상품"),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "사용자 관리"),
        ],
      ),
    );
  }

  /// ✅ 사용자 아이템 위젯
  Widget _userItem(
      BuildContext context, {
        required String name,
        required String pet,
        required String status,
        required Color color,
        required String point,
        required String userId, // ✅ 변경
      }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      title: Text("$name / $pet"),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🔹 정보 버튼
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserDetailPage(userId: userId), // ✅ userId 전달
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text("정보",
                  style: TextStyle(color: Colors.black, fontSize: 12)),
            ),
          ),
          const SizedBox(width: 8),

          // 🔹 포인트 박스
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7CC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(point,
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          const SizedBox(width: 8),

          // 🔹 상태 박스
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(status,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
