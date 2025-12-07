// ================================================
// 🔥 관리자 사용자 관리 페이지 (최종 본)
// ================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'hospital_approval_page.dart';
import 'product_page.dart';
import 'admin_main_page.dart';
import 'user_detail_page.dart';
import 'inquiry_page.dart';
import 'admin_user.dart';
import 'package:animal_project/api_config.dart';

class UserManagePage extends StatefulWidget {
  const UserManagePage({super.key});

  @override
  State<UserManagePage> createState() => _UserManagePageState();
}

class _UserManagePageState extends State<UserManagePage> {
  List<AdminUser> users = [];
  List<AdminUser> filteredUsers = [];

  Future<void> _fetchUsers() async {
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/admin/users");
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

  void _applyFilter(String query) {
    setState(() {
      filteredUsers = users.where((user) {
        return (user.name.toLowerCase().contains(query.toLowerCase())) ||
            (user.petName?.toLowerCase().contains(query.toLowerCase()) ?? false);
      }).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchUsers();
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
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const InquiryPage()));
            },
            child: const Text("문의함",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: Column(
        children: [
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

          Expanded(
            child: filteredUsers.isEmpty
                ? const Center(child: Text("등록된 사용자가 없습니다."))
                : ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) {
                final user = filteredUsers[index];

                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  title: Text("${user.name} / ${user.petName ?? '-'}"),
                  trailing: GestureDetector(
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  UserDetailPage(userId: user.id)));
                    },
                    child: Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12)),
                      child: const Text("정보"),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 3,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const AdminMainPage()));
              break;
            case 1:
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const HospitalApprovalPage()));
              break;
            case 2:
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const ProductPage()));
              break;
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
}
