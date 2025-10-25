// lib/admin/product_detail_page.dart
import 'dart:convert'; // ✅ 이거 추가
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'product.dart';
import 'product_register_page.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _detailKey = GlobalKey();
  final GlobalKey _reviewKey = GlobalKey();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchLatestProduct(); // ✅ 추가
  }
  void _scrollTo(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  /// ✅ 서버에서 최신 상품 데이터 가져오기 (모든 정보 자동 동기화)
  Future<void> _fetchLatestProduct() async {
    try {
      final url = Uri.parse("http://127.0.0.1:5000/products/${widget.product.id}");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final updatedData = jsonDecode(response.body);

        setState(() {
          widget.product.name = updatedData["name"];
          widget.product.category = updatedData["category"];
          widget.product.description = updatedData["description"];
          widget.product.price = updatedData["price"];
          widget.product.quantity = updatedData["quantity"];
          widget.product.images = List<String>.from(updatedData["images"] ?? []);
        });

        print("🔄 관리자 상품 상세 최신화 완료 → ${widget.product.name}");
      } else {
        print("❌ 상품 정보 불러오기 실패: ${response.body}");
      }
    } catch (e) {
      print("❌ 네트워크 오류: $e");
    }
  }

  /// ✅ 상품 삭제 함수
  Future<void> _deleteProduct() async {
    final url = Uri.parse("http://localhost:5000/products/${widget.product.id}");
    final response = await http.delete(url);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ 상품이 삭제되었습니다.")),
      );
      Navigator.pop(context, true);
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
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(product.name, style: const TextStyle(color: Colors.black)),
        centerTitle: true,
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
                      return Image.network(
                        product.images[index],
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                        const Center(child: Text("이미지 로드 실패")),
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

            const SizedBox(height: 16),

            /// ✅ 상품 기본정보
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(product.category,
                      style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),
                  Text("가격: ${product.price}원",
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("수량: ${product.quantity}개",
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            /// ✅ 탭바 (상세정보 / 리뷰)
            Material(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.black,
                tabs: const [
                  Tab(text: "상세정보"),
                  Tab(text: "상품 리뷰"),
                ],
                onTap: (index) {
                  if (index == 0) _scrollTo(_detailKey);
                  if (index == 1) _scrollTo(_reviewKey);
                },
              ),
            ),
            /// ✅ 스크롤 가능한 내용 (상세정보 + 리뷰)
            Expanded( // ✅ 이 부분 새로 추가
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      key: _detailKey,
                      child: Text(
                        product.description.isNotEmpty
                            ? product.description
                            : "상품 설명이 없습니다.",
                        style: const TextStyle(fontSize: 15, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Divider(thickness: 5, color: Color(0xFFF1F1F1)),
                    const SizedBox(height: 16),
                    Container(
                      key: _reviewKey,
                      child: _buildReviewSection(product.id),
                    ),
                  ],
                ),
              ),
            ),
          ],
      ),

      /// ✅ 관리자 기능 버튼 (수정 / 삭제)
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProductRegisterPage(product: product),
                    ),
                  );
                  if (result == true) {
                    await _fetchLatestProduct(); // ✅ 수정 후 최신 데이터 불러오기
                    setState(() {}); // UI 다시 그림
                    Navigator.pop(context, true); // ✅ 목록으로 돌아갈 때 true 전달 (핵심)
                  }
                },
                icon: const Icon(Icons.edit),
                label: const Text("수정"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF7CC),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _deleteProduct,
                icon: const Icon(Icons.delete),
                label: const Text("삭제"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  /// ✅ 리뷰 섹션 (서버에서 실제 리뷰 가져오기)
  Widget _buildReviewSection(String productId) {
    return FutureBuilder(
      future: _fetchReviews(productId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text("리뷰 불러오기 오류: ${snapshot.error}"),
          );
        }

        final reviews = snapshot.data as List<dynamic>? ?? [];

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "📝 사용자 리뷰",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),


              if (reviews.isEmpty)
                const Center(child: Text("아직 등록된 리뷰가 없습니다.")),

              ...reviews.map((r) => Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.person, color: Colors.grey),
                  title: Text(
                    "${r["userName"] ?? "익명"} (${r["rating"]}⭐)",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(r["comment"] ?? ""),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        r["createdAt"].toString().substring(0, 10),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 22),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("리뷰 삭제"),
                              content: const Text("정말 이 리뷰를 삭제하시겠습니까?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("취소"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("삭제", style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _deleteReview(productId, r["_id"]); // ✅ 삭제 실행
                          }
                        },
                      ),
                    ],
                  ),
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  /// ✅ 리뷰 삭제 함수 (관리자 전용)
  Future<void> _deleteReview(String productId, String reviewId) async {
    try {
      final url = Uri.parse("http://127.0.0.1:5000/products/$productId/reviews/$reviewId");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🗑️ 리뷰가 삭제되었습니다.")),
        );
        await _fetchReviews(productId); // ✅ 서버에서 최신 리뷰 다시 불러오기
        setState(() {}); // ✅ 화면 새로고침
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ 리뷰 삭제 실패: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ 네트워크 오류: $e")),
      );
    }
  }


  /// ✅ 서버에서 리뷰 불러오기 함수
  Future<List<dynamic>> _fetchReviews(String productId) async {
    try {
      final url = Uri.parse("http://127.0.0.1:5000/products/$productId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["reviews"] ?? [];
      } else {
        throw Exception("서버 오류: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("네트워크 오류: $e");
    }
  }
}


