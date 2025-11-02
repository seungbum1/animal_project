import 'package:flutter/material.dart';
import 'login.dart';

class AdminMainScreen extends StatelessWidget {
  const AdminMainScreen({super.key});

  // 통일된 초대코드 (실제론 서버에서 받아오는 게 안전)
  final String inviteCode = "admin123";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '관리자',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFF5C3),
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.notifications, color: Colors.black),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 검색창
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: '사용자 조회 및 검색',
                    border: InputBorder.none,
                    icon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 병원 승인관리 타이틀
              _sectionHeader('병원 승인관리', onTap: () {}),
              const SizedBox(height: 12),

              // 병원 승인 리스트 (샘플)
              Expanded(
                child: ListView(
                  children: [
                    _approvalCard('김곽철 / 딸기'),
                    _approvalCard('소완성 / 미니피그'),
                    const SizedBox(height: 20),

                    _sectionHeader('요청사항', onTap: () {}),
                    const SizedBox(height: 12),

                    _requestCard('하이스 병원', 2),
                    _requestCard('팔라스 병원', 5),
                    _requestCard('기뚱찬 병원', 1),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 병원 관리자 초대코드 버튼
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('병원 관리자 초대코드'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              inviteCode,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text('이 코드를 병원 관리자에게 전달하세요.'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('닫기'),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade100,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('병원 관리자 초대코드 확인'),
                ),
              ),
              const SizedBox(height: 12),

              // 공지사항 등록 버튼
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF5C3),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('공지사항 등록'),
                ),
              ),
            ],
          ),
        ),
      ),

      // 하단 네비게이션바
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFFFFF5C3),
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '메인화면'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: '병원승인'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: '상품'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: '사용자 관리'),
        ],
      ),
    );
  }

  // 섹션 타이틀 위젯
  Widget _sectionHeader(String title, {VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        TextButton(
          onPressed: onTap,
          child: const Text('확인하기 >'),
        )
      ],
    );
  }

  // 병원 승인 카드
  Widget _approvalCard(String name) {
    return Card(
      child: ListTile(
        title: Text(name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(60, 36),
              ),
              child: const Text('승인'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(60, 36),
              ),
              child: const Text('거절'),
            ),
          ],
        ),
      ),
    );
  }

  // 요청사항 카드
  Widget _requestCard(String hospitalName, int count) {
    return Card(
      child: ListTile(
        title: Text(hospitalName),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF5C3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$count개',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
