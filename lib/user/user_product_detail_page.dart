import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../admin/product.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_payment_page.dart';

class UserProductDetailPage extends StatefulWidget {
  final Product product;
  final bool isFavorite; // ✅ 찜 상태 전달받기
  final Function(Product) onToggleFavorite; // ✅ 찜상태 콜백 전달받기

  const UserProductDetailPage({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  State<UserProductDetailPage> createState() => _UserProductDetailPageState();
}

class _UserProductDetailPageState extends State<UserProductDetailPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  late bool _isFavorite; // ✅ 전달받은 찜상태 반영

  String _sortOption = "최신순"; // ✅ 리뷰 정렬 기준 (추가)

  late TabController _tabController;
  final GlobalKey _detailKey = GlobalKey();
  final GlobalKey _reviewKey = GlobalKey();

  List<dynamic> _cachedReviews = [];
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _isFavorite = widget.isFavorite; // ✅ 초기 찜 상태 세팅
    _fetchLatestProduct(); // ✅ 최신 상품 수량 불러오기
    _fetchReviews();
  }

  /// ✅ 서버에서 최신 상품 데이터 가져오기
  Future<void> _fetchLatestProduct() async {
    try {
      final url = Uri.parse("http://127.0.0.1:5000/products/${widget.product.id}");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final updatedData = jsonDecode(response.body);
        setState(() {
          widget.product.quantity = updatedData["quantity"]; // 최신 수량 반영
        });
        print("🔄 최신 수량 동기화 완료: ${updatedData["quantity"]}");
      } else {
        print("❌ 상품 정보 불러오기 실패: ${response.body}");
      }
    } catch (e) {
      print("❌ 네트워크 오류: $e");
    }
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

  /// ✅ 서버 연동 찜 토글
  Future<void> _toggleFavorite() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("로그인이 필요합니다.")),
        );
        return;
      }

      final isNowFavorite = !_isFavorite;
      final url = Uri.parse("http://127.0.0.1:5000/users/$userId/favorites/${widget.product.id}");

      final response = isNowFavorite
          ? await http.post(url)
          : await http.delete(url);

      if (response.statusCode == 200) {
        setState(() {
          _isFavorite = isNowFavorite;
        });
        // ✅ SharedPreferences에 찜 변경 여부 기록 → 다른 페이지에서 자동 새로고침
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool("favoritesUpdated", true);

        // ✅ 상위 위젯에게 상태 변경 알림 (리스트 갱신용)
        widget.onToggleFavorite(widget.product);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFavorite
                  ? "찜 목록에 추가되었습니다 ❤️"
                  : "찜 목록에서 제거되었습니다.",
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      } else {
        print("❌ 서버 오류: ${response.body}");
      }
    } catch (e) {
      print("❌ 찜 요청 실패: $e");
    }
  }

  /// ✅ 구매 바텀시트 (하단 슬라이드 UI)
  void _showPurchaseSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        int count = 1; // ✅ 초기 수량
        final product = widget.product;

        return StatefulBuilder(
          builder: (context, setStateBottom) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔹 상품 미리보기
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: product.images.isNotEmpty
                            ? Image.network(
                          product.images.first,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        )
                            : Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text("갯수", style: TextStyle(color: Colors.grey[700])),
                      const SizedBox(width: 6),
                      _quantityButton("-", () {
                        if (count > 1) setStateBottom(() => count--);
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text("$count",
                            style: const TextStyle(fontSize: 16)),
                      ),
                      _quantityButton("+", () {
                        setStateBottom(() => count++);
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 💰 총 결제 금액 표시
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7CC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "총 결제 금액",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${(product.price * count).toString()}원",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🔹 장바구니 / 결제 버튼
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            try {
                              final prefs = await SharedPreferences.getInstance();
                              final userId = prefs.getString('userId');

                              if (userId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("로그인이 필요합니다.")),
                                );
                                return;
                              }

                              // ✅ 수량 정보를 포함해 장바구니로 보냄
                              final url = Uri.parse(
                                  "http://127.0.0.1:5000/users/$userId/cart/${product.id}");

                              final response = await http.post(
                                url,
                                headers: {"Content-Type": "application/json"},
                                body: jsonEncode({"count": count}),
                              );

                              if (response.statusCode == 200) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("장바구니에 $count개 담았습니다 🛒")),
                                );
                              } else {
                                print("❌ 서버 응답 오류: ${response.body}");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("장바구니 추가 실패 ❌")),
                                );
                              }
                            } catch (e) {
                              print("❌ 요청 실패: $e");
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("네트워크 오류가 발생했습니다 ⚠️")),
                              );
                            }
                          },

                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text("장바구니"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context); // 바텀시트 닫기

                            // ✅ 결제 완료 후 true 신호 받기
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserPaymentPage(
                                  products: [
                                    {
                                      "product": widget.product,
                                      "count": count, // ✅ 수량도 함께 전달
                                    }
                                  ],
                                  source: "detail", // ✅ 상세 페이지에서 결제
                                ),
                              ),
                            );
                            if (result == true) {
                              await _fetchLatestProduct();
                              setState(() {});
                              Navigator.pop(context, true); // ✅ 상품 목록으로 돌아갈 때 새로고침 신호 보내기
                            }
                          },

                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFF7CC),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text("결제하기"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _quantityButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
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
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : Colors.black,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),

      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
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
                          errorBuilder:
                              (context, error, stackTrace) =>
                          const Center(
                              child: Text("이미지 로드 실패")),
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
                  child: const Center(child: Text("이미지 없음")),
                ),
              ),

              const SizedBox(height: 20),

              /// ✅ 상품 기본정보
              Text(product.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(product.category,
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 6),
              Text("가격: ${product.price}원",
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text("수량: ${product.quantity}개",
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),

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
              const SizedBox(height: 20),

              /// ✅ 상세정보
              _buildDetailSection(product),
              const SizedBox(height: 40),
              const Divider(
                thickness: 5,
                color: Color(0xFFF1F1F1),
              ),
              const SizedBox(height: 10),

              /// ✅ 리뷰
              _buildReviewSection(),
            ],
          ),
        ),
      ),

      // ✅ 하단 버튼
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // ❤️ 찜하기 버튼
            SizedBox(
              width: 55,
              height: 55,
              child: OutlinedButton(
                onPressed: _toggleFavorite,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.black12, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : Colors.black,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // 🛒 구매하기 버튼
            Expanded(
              child: SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _showPurchaseSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF7CC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "구매하기",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ 상세정보
  Widget _buildDetailSection(Product product) {
    return Container(
      key: _detailKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            product.description.isNotEmpty
                ? product.description
                : "상품 설명이 없습니다.",
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  /// ✅ 리뷰 섹션 (서버에서 실제 리뷰 가져오기)
  /// ✅ 리뷰 섹션 (한 번만 서버에서 불러오고 캐시로 표시)
  Widget _buildReviewSection() {
    if (_isLoadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }

    final reviews = _cachedReviews;
    final sortedReviews = _sortReviews([...reviews]);
    final average = _calculateAverageRating(reviews);

    return Container(
      key: _reviewKey,
      margin: const EdgeInsets.only(top: 10, bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "리뷰",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (reviews.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ⭐ 평균 별점
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 22),
                      const SizedBox(width: 4),
                      Text(
                        "$average점",
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "(${reviews.length}개 리뷰)",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),

                  // 💛 정렬 드롭다운 (귀엽고 작게)
                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7CC),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortOption,
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Colors.black),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        dropdownColor: const Color(0xFFFFFBE5),
                        borderRadius: BorderRadius.circular(12),
                        items: ["최신순", "별점 높은순", "별점 낮은순"]
                            .map((option) => DropdownMenuItem(
                          value: option,
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Colors.amber, size: 18),
                              const SizedBox(width: 4),
                              Text(option),
                            ],
                          ),
                        ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _sortOption = value;
                            }); // ✅ 정렬만 변경, 새 요청 없음
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (reviews.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  "아직 리뷰가 없습니다.",
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),

          ...sortedReviews.map((r) => Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.person, color: Colors.grey),
              title: Text(
                "${r["userName"]} (${r["rating"]}⭐)",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(r["comment"]),
              trailing: Text(
                r["createdAt"].toString().substring(0, 10),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          )),
        ],
      ),
    );
  }


  /// ✅ 리뷰 정렬 함수 (최신순 / 별점순)
  List<dynamic> _sortReviews(List<dynamic> reviews) {
    if (_sortOption == "최신순") {
      reviews.sort((a, b) {
        final dateA = DateTime.tryParse(a["createdAt"] ?? "") ?? DateTime(0);
        final dateB = DateTime.tryParse(b["createdAt"] ?? "") ?? DateTime(0);
        return dateB.compareTo(dateA); // 최신이 위로
      });
    } else if (_sortOption == "별점 높은순") {
      reviews.sort((a, b) => (b["rating"] ?? 0).compareTo(a["rating"] ?? 0));
    } else if (_sortOption == "별점 낮은순") {
      reviews.sort((a, b) => (a["rating"] ?? 0).compareTo(b["rating"] ?? 0));
    }
    return reviews;
  }

  /// ✅ 리뷰의 평균 별점 계산 함수
  double _calculateAverageRating(List<dynamic> reviews) {
    if (reviews.isEmpty) return 0.0;
    final total = reviews.fold<double>(
        0.0, (sum, r) => sum + (r["rating"] ?? 0).toDouble());
    return double.parse((total / reviews.length).toStringAsFixed(1));
  }
  /// ✅ 리뷰 캐싱해서 불러오기 (한 번만 서버에서)
  Future<void> _fetchReviews() async {
    try {
      setState(() => _isLoadingReviews = true);
      final url = Uri.parse("http://127.0.0.1:5000/products/${widget.product.id}");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _cachedReviews = data["reviews"] ?? [];
          _isLoadingReviews = false;
        });
      } else {
        throw Exception("서버 오류: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _isLoadingReviews = false);
      print("❌ 리뷰 불러오기 실패: $e");
    }
  }
}
