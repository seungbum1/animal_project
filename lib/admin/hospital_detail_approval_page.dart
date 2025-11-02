import 'package:flutter/material.dart';

class HospitalDetailApprovalPage extends StatelessWidget {
  const HospitalDetailApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7CC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("병원 신청 정보", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: const [
          Icon(Icons.notifications_none, color: Colors.black),
          SizedBox(width: 12),
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 병원 이미지
            Container(
              height: 160,
              color: Colors.grey[300],
              margin: const EdgeInsets.all(12),
            ),

            /// 병원 정보
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("할리스 병원",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text("영업 시간 : 09:00 ~ 19:00",
                      style: TextStyle(color: Colors.black54)),
                  SizedBox(height: 8),
                  Text("경기도 부천시 심곡동 할리스1가 할리스테이지 1층"),
                  Text("전화번호 : 032-023-8492"),
                  SizedBox(height: 16),
                  Text("병원 소개",
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 8),
                  Text("여기에 병원 소개 내용을 작성합니다."),
                ],
              ),
            ),
          ],
        ),
      ),

      /// 하단 승인/거절 버튼
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5438F4), // 보라색
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("승인하기"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("거절하기"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
