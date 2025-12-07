import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'admin_user.dart';
import 'package:animal_project/api_config.dart';

class UserDetailPage extends StatefulWidget {
  final String userId;

  const UserDetailPage({super.key, required this.userId});

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  AdminUser? user;

  Future<void> _fetchUserDetail() async {
    try {
      final url =
      Uri.parse("${ApiConfig.baseUrl}/admin/users/${widget.userId}");
      final res = await http.get(url);

      if (res.statusCode == 200) {
        setState(() {
          user = AdminUser.fromJson(jsonDecode(res.body));
        });
      }
    } catch (e) {
      print("❌ 상세 정보 오류: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUserDetail();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        leading: BackButton(color: Colors.black),
        backgroundColor: const Color(0xFFFFF7CC),
        elevation: 0,
        title: const Text("사용자 정보",
            style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),

      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            infoRow("이름", user!.name),
            infoRow("생년월일", user!.birth ?? "-"),
            infoRow("아이디", user!.username),
            infoRow("반려동물 이름", user!.petName ?? "-"),
            infoRow("반려견 나이", "${user!.petAge ?? '-'}살"),
            infoRow("성별", user!.petGender ?? "-"),
            infoRow("종", user!.petSpecies ?? "-"),
            infoRow("병원 연동", user!.hospital ?? "-"),
          ],
        ),
      ),
    );
  }

  Widget infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
