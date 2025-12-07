import 'package:flutter/material.dart';
import 'admin_main_page.dart';
import 'product_page.dart';
import 'user_manage_page.dart';
import 'hospital_detail_approval_page.dart';

class HospitalApprovalPage extends StatelessWidget {
  const HospitalApprovalPage({super.key});

  /// =======================================================
  /// 🔥 애니메이션 없이 교체하는 함수
  /// =======================================================
  void _noAnimReplace(BuildContext context, Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => page,
      ),
    );
  }

  /// =======================================================
  /// 🔥 하단 네비게이션 바 (currentIndex = 1)
  /// =======================================================
  Widget _buildBottomNavBar(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.grey,
      currentIndex: 1,

      onTap: (index) {
        if (index == 1) return;

        switch (index) {
          case 0:
            _noAnimReplace(context, const AdminMainPage());
            break;
          case 2:
            _noAnimReplace(context, const ProductPage());
            break;
          case 3:
            _noAnimReplace(context, const UserManagePage());
            break;
        }
      },

      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "메인화면"),
        BottomNavigationBarItem(icon: Icon(Icons.verified), label: "병원승인"),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: "상품"),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: "사용자 관리"),
      ],
    );
  }

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
          // 검색창
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
                    borderSide: BorderSide.none),
              ),
            ),
          ),

          // 승인 리스트
          Expanded(
            child: ListView(
              children: const [
                _ApprovalItem("할리스 병원"),
                _ApprovalItem("병원이름"),
                _ApprovalItem("병원이름"),
              ],
            ),
          ),
        ],
      ),

      /// =======================================================
      /// 🔥 부드러운 하단 네비게이션 적용
      /// =======================================================
      bottomNavigationBar: _buildBottomNavBar(context),
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

          /// 병원이름 (클릭 시 상세 페이지)
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (hospitalName == "할리스 병원") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HospitalDetailApprovalPage(),
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
              // TODO: 승인 로직
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
              // TODO: 거절 로직
            },
            child: const Text("거절"),
          ),
        ],
      ),
    );
  }
}
