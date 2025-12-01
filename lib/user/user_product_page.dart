import 'dart:convert';
import 'user_product_payment_history.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../admin/product.dart';
import 'user_product_detail_page.dart';
import 'user_product_favorite_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 🔸 ApiConfig는 패키지 경로로 import 하는 게 안전함
import 'package:animal_project/api_config.dart';

class UserProductPage extends StatefulWidget {
  const UserProductPage({super.key});

  @override
  State<UserProductPage> createState() => _UserProductPageState();
}

class _UserProductPageState extends State<UserProductPage> {
  List<Product> products = [];
  List<Product> filteredProducts = [];
  List<Product> favoriteProducts = []; // ✅ 찜목록 리스트
  String _sortOption = "최근등록";
  String _searchQuery = "";
  String _selectedCategory = "전체";

  /// ✅ 상품 전체 목록 불러오기 (★ 여기서는 userId 필요 없음)
  Future<void> _fetchProducts() async {
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/products"); // 🔸 수정: /products
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          products = data.map((e) => Product.fromJson(e)).toList();
          _applySort();
          _applyFilters();
        });
        print("✅ 상품 목록 불러오기 성공 (${products.length}개)");
      } else {
        print("❌ 상품 불러오기 실패: ${response.body}");
      }
    } catch (e) {
      print("❌ 상품 요청 오류: $e");
    }
  }

  /// ✅ 유저의 찜 목록 불러오기 (DB 연동)
  Future<void> _fetchFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null) return;

    try {
      // 🔸 여기서도 127.0.0.1 대신 ApiConfig 사용
      final url =
      Uri.parse("${ApiConfig.baseUrl}/users/$userId/favorites");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final favList = data.map((e) => Product.fromJson(e)).toList();

        setState(() {
          favoriteProducts = favList;
        });
        print("✅ DB에서 찜 목록 동기화 완료 (${favoriteProducts.length}개)");
      } else {
        print("❌ 찜 목록 불러오기 실패: ${response.body}");
      }
    } catch (e) {
      print("❌ 찜 목록 요청 오류: $e");
    }
  }

  /// ✅ 정렬
  void _applySort() {
    if (_sortOption == "최근등록") {
      products = products.reversed.toList();
    } else if (_sortOption == "높은가격") {
      products.sort((a, b) => b.price.compareTo(a.price));
    } else if (_sortOption == "낮은가격") {
      products.sort((a, b) => a.price.compareTo(b.price));
    }
  }

  /// ✅ 검색 + 카테고리 필터
  void _applyFilters() {
    setState(() {
      filteredProducts = products.where((p) {
        final matchesSearch =
        p.name.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesCategory =
        (_selectedCategory == "전체" || p.category == _selectedCategory);
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  /// ✅ 찜 추가/제거 (서버 연동)
  Future<void> toggleFavorite(Product product) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("로그인이 필요합니다.")),
      );
      return;
    }

    final isFavorite = favoriteProducts.any((p) => p.id == product.id);

    // 🔸 여기도 ApiConfig로 교체
    final url = Uri.parse(
        "${ApiConfig.baseUrl}/users/$userId/favorites/${product.id}");

    try {
      final response = isFavorite
          ? await http.delete(url) // 이미 찜이면 제거
          : await http.post(url); // 찜 추가

      if (response.statusCode == 200) {
        setState(() {
          if (isFavorite) {
            favoriteProducts.removeWhere((p) => p.id == product.id);
          } else {
            favoriteProducts.add(product);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFavorite ? "찜이 해제되었습니다." : "찜 목록에 추가되었습니다.",
            ),
          ),
        );
      } else {
        print("❌ 서버 오류: ${response.body}");
      }
    } catch (e) {
      print("❌ 찜 요청 실패: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchProducts().then((_) => _fetchFavorites());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7CC),
        elevation: 0,
        title: const Text("상품 둘러보기", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: Navigator.canPop(context)
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        )
            : null,
        actions: [
          // ✅ 결제내역 아이콘
          IconButton(
            icon: const Icon(Icons.receipt_long, color: Colors.black),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final userId = prefs.getString('userId');

              if (userId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("로그인이 필요합니다.")),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      UserProductPaymentHistoryPage(userId: userId),
                ),
              );
            },
          ),
          // ✅ 찜목록 이동 아이콘
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.black),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserProductFavoritePage(),
                ),
              );

              // ✅ 돌아왔을 때 찜 변경 여부 체크
              final prefs = await SharedPreferences.getInstance();
              final updated = prefs.getBool("favoritesUpdated") ?? false;

              if (updated) {
                await _fetchFavorites();
                await prefs.remove("favoritesUpdated");
                setState(() {});
              }
            },
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchProducts();
          await _fetchFavorites();
        },
        color: Colors.black,
        backgroundColor: const Color(0xFFFFF7CC),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔍 검색창
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                onChanged: (value) {
                  _searchQuery = value;
                  _applyFilters();
                },
                decoration: InputDecoration(
                  hintText: "상품명을 입력해주세요",
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

            /// ✅ 카테고리 선택
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ["전체", "간식", "사료", "용품"].map((category) {
                    final isSelected = _selectedCategory == category;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                          _applyFilters();
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFFF7CC)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isSelected
                              ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(2, 3),
                            ),
                          ]
                              : [],
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color:
                            isSelected ? Colors.black : Colors.grey[700],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),

            /// 총 상품 수 + 정렬
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("총 ${filteredProducts.length}개 상품"),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      setState(() {
                        _sortOption = value;
                        _applySort();
                        _applyFilters();
                      });
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: "최근등록", child: Text("최근등록")),
                      PopupMenuItem(value: "높은가격", child: Text("높은가격순")),
                      PopupMenuItem(value: "낮은가격", child: Text("낮은가격순")),
                    ],
                    child: Row(
                      children: [
                        Text(_sortOption,
                            style: const TextStyle(color: Colors.grey)),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            /// ✅ 상품 카드 리스트
            Expanded(
              child: filteredProducts.isEmpty
                  ? const Center(child: Text("상품이 없습니다."))
                  : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  final isFavorite = favoriteProducts
                      .any((p) => p.id == product.id);
                  return _productCard(context, product, isFavorite);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ 상품 카드 위젯
  Widget _productCard(
      BuildContext context, Product product, bool isFavorite) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProductDetailPage(
              product: product,
              isFavorite: isFavorite,
              onToggleFavorite: toggleFavorite,
            ),
          ),
        );

        if (result == true) {
          await _fetchProducts();
          await _fetchFavorites();
          setState(() {});
        }
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 1),
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
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12)),
                      image: product.images.isNotEmpty
                          ? DecorationImage(
                        image: NetworkImage(product.images.first),
                        fit: BoxFit.cover,
                      )
                          : null,
                    ),
                    child: product.images.isEmpty
                        ? const Center(child: Icon(Icons.image, size: 40))
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name,
                          style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                      Text("${product.price}원",
                          style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Text(
                            product.category,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.star,
                              color: Colors.amber, size: 16),
                          Text(
                            (product.averageRating > 0
                                ? product.averageRating.toStringAsFixed(1)
                                : "0"),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ✅ 하트 아이콘
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => toggleFavorite(product),
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
