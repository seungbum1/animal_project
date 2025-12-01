import 'package:flutter/material.dart';

class InquiryPage extends StatefulWidget {
  const InquiryPage({super.key});

  @override
  State<InquiryPage> createState() => _InquiryPageState();
}

class _InquiryPageState extends State<InquiryPage> {
  // 어떤 문의가 열렸는지 저장 (userName/펫이 key 역할)
  final Set<String> _openReplies = {};

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
        title: const Text("문의함", style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 🔍 검색창
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
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

          // 상단 필터 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _filterChip("전체보기", true),
                const SizedBox(width: 8),
                _filterChip("문의하기", false),
                const SizedBox(width: 8),
                _filterChip("문의완료", false),
              ],
            ),
          ),

          // 문의 리스트
          Expanded(
            child: ListView(
              children: [
                _inquiryCard(
                  user: "손승범/다롱이",
                  question: "방금 350 걸음 걸었는데 포인트가 안 들어왔어요!",
                  keyId: "손승범/다롱이",
                ),
                _inquiryCard(
                  user: "김건희/두부",
                  question: "방금 350 걸음 걸었는데 포인트가 안 들어왔어요!",
                  keyId: "김건희/두부",
                  isAnswered: true,
                  answer: "죄송합니다.",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 필터 Chip
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

  /// 문의 카드
  Widget _inquiryCard({
    required String user,
    required String question,
    required String keyId,
    bool isAnswered = false,
    String? answer,
  }) {
    final bool isOpen = _openReplies.contains(keyId);

    return GestureDetector(
      onTap: () {
        if (!isAnswered) {
          setState(() {
            if (isOpen) {
              _openReplies.remove(keyId);
            } else {
              _openReplies.add(keyId);
            }
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(question),
            const SizedBox(height: 8),
            Text(isAnswered ? "문의완료" : "문의하기",
                style: TextStyle(
                    color: isAnswered ? Colors.blue : Colors.grey,
                    fontSize: 12)),
            const SizedBox(height: 8),

            if (isAnswered)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(answer ?? ""),
              )
            else if (isOpen)
              Column(
                children: [
                  TextField(
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: "답변을 입력하세요...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _openReplies.remove(keyId); // 닫기
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5438F4),
                        foregroundColor: Colors.white, // 💜 색상 변경
                      ),
                      child: const Text("답변"), // ✅ 텍스트 변경
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}