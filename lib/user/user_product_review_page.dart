import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // ✅ 추가

class UserProductReviewPage extends StatefulWidget {
  final String productId; // ✅ 리뷰 대상 상품 ID
  const UserProductReviewPage({
    super.key,
    required this.productId,
  });

  @override
  State<UserProductReviewPage> createState() => _UserProductReviewPageState();
}

class _UserProductReviewPageState extends State<UserProductReviewPage> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;

  String _userName = "익명"; // ✅ 로그인 이름 저장용 변수

  // ✅ [1] 로그인한 유저 이름 불러오기 (initState에 넣을 예정)
  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? "익명";
    });
    print("✅ 로그인한 유저 이름: $_userName");
  }

  // ✅ [2] initState에서 실행
  @override
  void initState() {
    super.initState();
    _loadUserName(); // ✅ 이름 불러오기 실행
  }

  // ✅ 리뷰 등록 API 호출
  Future<void> _submitReview() async {
    if (_rating == 0 || _commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('별점과 리뷰 내용을 모두 입력해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('http://127.0.0.1:5000/products/${widget.productId}/reviews');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userName': _userName, // ✅ SharedPreferences에서 불러온 이름 사용
          'rating': _rating,
          'comment': _commentController.text,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰가 등록되었습니다 ✅')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('리뷰 등록 실패: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('네트워크 오류: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ 별점 UI
  Widget _buildStar(int index) {
    return IconButton(
      icon: Icon(
        index <= _rating ? Icons.star : Icons.star_border,
        color: Colors.amber,
        size: 32,
      ),
      onPressed: () => setState(() => _rating = index),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('리뷰 작성'),
        backgroundColor: const Color(0xFFFFF7CC),
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('별점을 선택하세요', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(children: List.generate(5, (i) => _buildStar(i + 1))),
            const SizedBox(height: 20),

            const Text('리뷰 내용', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _commentController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: '제품에 대한 후기를 입력해주세요.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 30),

            Center(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF7CC),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(160, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('등록하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
