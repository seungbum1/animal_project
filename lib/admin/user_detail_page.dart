import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class UserDetailPage extends StatefulWidget {
  final String userId; // ✅ userId만 받음

  const UserDetailPage({super.key, required this.userId});

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserDetail();
  }

  Future<void> _fetchUserDetail() async {
    try {
      final url = Uri.parse("http://localhost:5000/users/${widget.userId}");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          userData = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        print("❌ 유저 불러오기 실패: ${response.body}");
      }
    } catch (e) {
      print("❌ 오류 발생: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7CC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("사용자 정보", style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _infoRow("이름", userData?["name"] ?? "-"),
            _infoRow("생년월일",
                userData?["birthDate"]?.toString().split("T")[0] ?? "-"),
            _infoRow("아이디", userData?["email"] ?? "-"),
            _infoRow("반려동물 이름", userData?["petProfile"]?["name"] ?? "-"),
            _infoRow("반려견 나이",
                userData?["petProfile"]?["age"]?.toString() ?? "-"),
            _infoRow("성별", userData?["petProfile"]?["gender"] ?? "-"),
            _infoRow("종", userData?["petProfile"]?["species"] ?? "-"),

            // 제재
            _infoRow("제재", "0/3", trailingColor: const Color(0xFFFFF7CC)),

            // 포인트
            _infoRow("포인트", "0pt", trailingColor: const Color(0xFFFFF7CC)),

            // 병원 연동 ✅ 수정된 부분
            _infoRow(
              "병원 연동",
              (userData?["linkedHospitals"] != null &&
                  (userData?["linkedHospitals"] as List).isNotEmpty)
                  ? (userData?["linkedHospitals"][0]["hospitalName"] ?? "-")
                  : "-",
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? trailingColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: trailingColor != null
                ? BoxDecoration(
              color: trailingColor,
              borderRadius: BorderRadius.circular(8),
            )
                : null,
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
