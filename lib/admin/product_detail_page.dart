import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // ✅ 서버 요청용
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'product.dart';
import 'product_register_page.dart'; // ✅ 수정 페이지 연결

class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final PageController _pageController = PageController();

  /// ✅ 상품 삭제 함수
  Future<void> _deleteProduct() async {
    if (widget.product.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ 상품 ID가 없어 삭제할 수 없습니다.")),
      );
      return;
    }

    final url = Uri.parse("http://localhost:5000/products/${widget.product.id}");
    final response = await http.delete(url);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ 상품이 삭제되었습니다.")),
      );
      Navigator.pop(context, true); // ✅ true 반환 → ProductPage에서 새로고침 트리거
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ 삭제 실패: ${response.body}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7CC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("쇼핑", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: const [
          Icon(Icons.favorite_border, color: Colors.black),
          SizedBox(width: 12),
        ],
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ✅ 이미지 슬라이드
          SizedBox(
            height: 250,
            child: product.images.isNotEmpty
                ? Stack(
              alignment: Alignment.bottomCenter,
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: product.images.length,
                  itemBuilder: (context, index) {
                    return Image.file(
                      File(product.images[index]),
                      fit: BoxFit.cover,
                    );
                  },
                ),
                Positioned(
                  bottom: 10,
                  child: SmoothPageIndicator(
                    controller: _pageController,
                    count: product.images.length,
                    effect: const ExpandingDotsEffect(
                      activeDotColor: Colors.black,
                      dotColor: Colors.white54,
                      dotHeight: 8,
                      dotWidth: 8,
                      spacing: 4,
                    ),
                  ),
                ),
              ],
            )
                : Container(
              color: Colors.grey[300],
              child: const Center(child: Text("상품 이미지 없음")),
            ),
          ),

          /// 상품 정보
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(product.category,
                    style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 4),
                Text("수량 : ${product.quantity}개",
                    style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 8),
                Text("${product.price}원",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          /// 탭바 (상세정보 / 리뷰)
          DefaultTabController(
            length: 2,
            child: Expanded(
              child: Column(
                children: [
                  const TabBar(
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.black,
                    tabs: [
                      Tab(text: "상세정보"),
                      Tab(text: "상품 리뷰"),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text(product.description),
                          ],
                        ),
                        const Center(
                          child: Text("아직 리뷰가 없습니다."),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      /// ✅ 하단 버튼
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  /// ✅ 수정 버튼 → ProductRegisterPage 열기
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductRegisterPage(product: product),
                    ),
                  );

                  if (result == true) {
                    Navigator.pop(context, true); // ✅ 수정 후 ProductPage 새로고침
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF7CC),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text("수정"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _deleteProduct, // ✅ 삭제 실행
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text("삭제"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
