import 'package:flutter/material.dart';

class UserPointPage extends StatelessWidget {
  final String userName;
  final String petName;

  const UserPointPage({
    super.key,
    required this.userName,
    required this.petName,
  });

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
        title: Text(
          "$userName/$petName 만보기 기록",
          style: const TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("683pt",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text("총 643 걸음",
                style: TextStyle(fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 10),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF7CC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {},
                child: const Text("포인트 추가하기",
                    style: TextStyle(color: Colors.black)),
              ),
            ),
            const SizedBox(height: 16),

            // 필터 버튼
            Row(
              children: [
                _filterChip("전체", true),
                const SizedBox(width: 8),
                _filterChip("적립", false),
                const SizedBox(width: 8),
                _filterChip("사용", false),
              ],
            ),
            const SizedBox(height: 16),

            // 포인트 기록
            Expanded(
              child: ListView(
                children: const [
                  _pointItem("25.9.24 손승범/다롱 320걸음 총 320포인트 적립"),
                  _pointItem("25.9.18 손승범/다롱 - 320포인트 사용"),
                  _pointItem("25.9.1 손승범/다롱 3걸음 총 3포인트 적립"),
                  _pointItem("25.8.24 손승범/다롱 20걸음 총 20포인트 적립"),
                  _pointItem("25.8.21 손승범/다롱 20걸음 총 20포인트 적립"),
                  _pointItem("25.7.24 손승범/다롱 320걸음 총 320포인트 적립"),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? Colors.black : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _pointItem extends StatelessWidget {
  final String text;
  const _pointItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
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
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }
}
