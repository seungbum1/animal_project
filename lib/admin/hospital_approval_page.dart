import 'package:flutter/material.dart';
import 'admin_main_page.dart';   // ✅ 메인화면 import
import 'product_page.dart';     // ✅ 상품 import
import 'user_manage_page.dart'; // ✅ 사용자 관리 화면 import
import 'hospital_detail_approval_page.dart'; // ✅ 상세 페이지 import

class HospitalApprovalPage extends StatelessWidget {
  const HospitalApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7CC),
        elevation: 0,
        title: const Text("병원 승인 관리", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: const [
          Icon(Icons.notifications_none, color: Colors.black),
          SizedBox(width: 12),
        ],
      ),

      body: Column(
        children: [
          /// 검색창
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "병원이름 검색",
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

          /// 승인 대기 리스트
          Expanded(
            child: ListView(
              children: const [
                _ApprovalItem("할리스 병원"), // ✅ 상세 페이지 연결
                _ApprovalItem("병원이름"),
                _ApprovalItem("병원이름"),
              ],
            ),
          ),
        ],
      ),

      /// ✅ 하단 네비게이션 바
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminMainPage()),
            );
          }
          if (index == 1) {
            // 현재 페이지
          }
          if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProductPage()),
            );
          }
          if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const UserManagePage()),
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
}

/// 승인 항목 위젯
class _ApprovalItem extends StatelessWidget {
  final String hospitalName;
  const _ApprovalItem(this.hospitalName);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          /// 아이콘 박스
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),

          /// 병원이름 (클릭 시 상세 페이지로 이동)
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (hospitalName == "할리스 병원") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HospitalDetailApprovalPage(),
                    ),
                  );
                }
              },
              child: Text(
                hospitalName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          /// 승인 버튼
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              // 승인 로직 작성
            },
            child: const Text("승인"),
          ),
          const SizedBox(width: 8),

          /// 거절 버튼
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              // 거절 로직 작성
            },
            child: const Text("거절"),
          ),
        ],
      ),
    );
  }
}
